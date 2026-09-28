package com.example.toyvision_realtime

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
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
        // Preserve the strongest motion between camera frames, then start the
        // next frame window. A short pickup/rotation pulse must not be lost
        // because the most recent raw sample happened to be quiet.
        gyroscopeMagnitude = 0.0
        accelerationMagnitude = 0.0
        return value
    }

    @Synchronized
    override fun onSensorChanged(event: SensorEvent) {
        timestampMs = System.currentTimeMillis()
        when (event.sensor.type) {
            Sensor.TYPE_GYROSCOPE -> {
                gyroscopeMagnitude = maxOf(gyroscopeMagnitude, magnitude(event.values))
            }
            Sensor.TYPE_LINEAR_ACCELERATION -> {
                accelerationMagnitude = maxOf(accelerationMagnitude, magnitude(event.values))
            }
            Sensor.TYPE_ACCELEROMETER -> {
                accelerationMagnitude = maxOf(
                    accelerationMagnitude,
                    abs(magnitude(event.values) - SensorManager.GRAVITY_EARTH),
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

    private fun magnitude(values: FloatArray): Double {
        if (values.size < 3) return 0.0
        return sqrt(
            values[0] * values[0] +
                values[1] * values[1] +
                values[2] * values[2],
        ).toDouble()
    }
}
