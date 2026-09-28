package com.example.toyvision_realtime

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.sqrt

class DeviceMotionSensorBridge(context: Context) : SensorEventListener {
    private val manager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val gyroscope = manager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
    private val linearAcceleration = manager.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
    private val accelerometer = manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val rotation = manager.getDefaultSensor(Sensor.TYPE_GAME_ROTATION_VECTOR)
        ?: manager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)

    @Volatile private var running = false
    @Volatile private var timestampMs = 0L
    @Volatile private var gyroscopeMagnitude = 0.0
    @Volatile private var accelerationMagnitude = 0.0
    @Volatile private var gyroscopePeakAtMs = 0L
    @Volatile private var accelerationPeakAtMs = 0L
    @Volatile private var yawDegrees: Double? = null
    @Volatile private var pitchDegrees: Double? = null
    @Volatile private var rollDegrees: Double? = null

    fun start() {
        if (running) return
        running = true
        gyroscope?.let { manager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME) }
        (linearAcceleration ?: accelerometer)?.let {
            manager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }
        rotation?.let { manager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME) }
    }

    fun stop() {
        if (!running) return
        running = false
        manager.unregisterListener(this)
    }

    @Synchronized
    fun snapshot(): Map<String, Any?> {
        val value = mapOf(
            "timestampMs" to timestampMs,
            "motionAvailable" to (gyroscope != null || linearAcceleration != null || accelerometer != null),
            "orientationAvailable" to (rotation != null && yawDegrees != null),
            "gyroscopeRadPerSecond" to gyroscopeMagnitude,
            "linearAccelerationMetersPerSecond2" to accelerationMagnitude,
            "yawDegrees" to yawDegrees,
            "pitchDegrees" to pitchDegrees,
            "rollDegrees" to rollDegrees,
        )
        return value
    }

    @Synchronized
    override fun onSensorChanged(event: SensorEvent) {
        timestampMs = System.currentTimeMillis()
        val monotonicNowMs = SystemClock.elapsedRealtime()
        when (event.sensor.type) {
            Sensor.TYPE_GYROSCOPE -> {
                val current = magnitude(event.values)
                if (
                    current >= gyroscopeMagnitude ||
                    monotonicNowMs - gyroscopePeakAtMs > PEAK_RETENTION_MS
                ) {
                    gyroscopeMagnitude = current
                    gyroscopePeakAtMs = monotonicNowMs
                }
            }
            Sensor.TYPE_LINEAR_ACCELERATION -> {
                updateAccelerationPeak(magnitude(event.values), monotonicNowMs)
            }
            Sensor.TYPE_ACCELEROMETER -> {
                updateAccelerationPeak(
                    abs(magnitude(event.values) - SensorManager.GRAVITY_EARTH),
                    monotonicNowMs,
                )
            }
            Sensor.TYPE_GAME_ROTATION_VECTOR,
            Sensor.TYPE_ROTATION_VECTOR,
            -> {
                val matrix = FloatArray(9)
                val orientation = FloatArray(3)
                SensorManager.getRotationMatrixFromVector(matrix, event.values)
                SensorManager.getOrientation(matrix, orientation)
                yawDegrees = orientation[0] * 180.0 / PI
                pitchDegrees = orientation[1] * 180.0 / PI
                rollDegrees = orientation[2] * 180.0 / PI
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun updateAccelerationPeak(current: Double, monotonicNowMs: Long) {
        if (
            current >= accelerationMagnitude ||
            monotonicNowMs - accelerationPeakAtMs > PEAK_RETENTION_MS
        ) {
            accelerationMagnitude = current
            accelerationPeakAtMs = monotonicNowMs
        }
    }

    private fun magnitude(values: FloatArray): Double {
        if (values.size < 3) return 0.0
        return sqrt(
            values[0] * values[0] +
                values[1] * values[1] +
                values[2] * values[2],
        ).toDouble()
    }

    private companion object {
        // Keep a short physical-motion pulse visible across dropped or
        // superseded camera frames. New quiet samples replace it afterwards.
        const val PEAK_RETENTION_MS = 750L
    }
}
