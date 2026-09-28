package com.example.toyvision_realtime

import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val deviceHealthChannel = "toyvision/device_health"
    private val deviceMotionChannel = "toyvision/device_motion"
    private lateinit var deviceMotion: DeviceMotionSensorBridge

    // Kid Mode must always restart at its Welcome screen after Android kills
    // the activity. Restoring the previous Flutter engine bundle can reopen
    // the internal camera surface and bypass Welcome → Introduction.
    override fun shouldRestoreAndSaveState(): Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        deviceMotion = DeviceMotionSensorBridge(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deviceMotionChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    deviceMotion.start()
                    result.success(null)
                }
                "stop" -> {
                    deviceMotion.stop()
                    result.success(null)
                }
                "read" -> result.success(deviceMotion.snapshot())
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deviceHealthChannel,
        ).setMethodCallHandler { call, result ->
            if (call.method != "read") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val power = getSystemService(POWER_SERVICE) as PowerManager
            val battery = getSystemService(BATTERY_SERVICE) as BatteryManager
            val batteryIntent = registerReceiver(
                null,
                IntentFilter(Intent.ACTION_BATTERY_CHANGED),
            )
            val status = batteryIntent?.getIntExtra(
                BatteryManager.EXTRA_STATUS,
                BatteryManager.BATTERY_STATUS_UNKNOWN,
            ) ?: BatteryManager.BATTERY_STATUS_UNKNOWN
            val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                status == BatteryManager.BATTERY_STATUS_FULL
            val thermal = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                power.currentThermalStatus
            } else {
                0
            }
            val percent = battery.getIntProperty(
                BatteryManager.BATTERY_PROPERTY_CAPACITY,
            ).coerceIn(0, 100)
            result.success(
                mapOf(
                    "thermalStatus" to thermal,
                    "batteryPercent" to percent,
                    "isCharging" to charging,
                ),
            )
        }
    }

    override fun onDestroy() {
        if (::deviceMotion.isInitialized) deviceMotion.stop()
        super.onDestroy()
    }
}
