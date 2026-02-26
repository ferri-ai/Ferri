package com.ferri.ferri.channels

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.atan2

/**
 * Reads device hardware sensors on demand using one-shot listeners.
 * Supports accelerometer, gyroscope, magnetometer, proximity, light, pressure, step counter, and gravity.
 */
class SensorChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL_NAME = "ferri/sensors"
    }

    private val sensorManager: SensorManager
        get() = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "listSensors" -> listSensors(result)
            "readSensor" -> readSensor(call, result)
            else -> result.notImplemented()
        }
    }

    private fun listSensors(result: MethodChannel.Result) {
        try {
            val sensors = sensorManager.getSensorList(Sensor.TYPE_ALL)
            val arr = JSONArray()
            for (s in sensors) {
                arr.put(JSONObject().apply {
                    put("name", s.name)
                    put("type", s.stringType)
                    put("vendor", s.vendor)
                    put("resolution", s.resolution.toDouble())
                    put("max_range", s.maximumRange.toDouble())
                    put("power_ma", s.power.toDouble())
                })
            }
            result.success(JSONObject().apply {
                put("sensors", arr)
                put("count", arr.length())
            }.toString())
        } catch (e: Exception) {
            result.error("SENSOR_ERROR", "Failed to list sensors", e.message)
        }
    }

    private fun readSensor(call: MethodCall, result: MethodChannel.Result) {
        val sensorType = call.argument<String>("sensor")
            ?: return result.error("INVALID_ARGS", "sensor type is required", null)

        val type = when (sensorType) {
            "accelerometer" -> Sensor.TYPE_ACCELEROMETER
            "gyroscope" -> Sensor.TYPE_GYROSCOPE
            "magnetometer", "compass" -> Sensor.TYPE_MAGNETIC_FIELD
            "proximity" -> Sensor.TYPE_PROXIMITY
            "ambient_light", "light" -> Sensor.TYPE_LIGHT
            "pressure", "barometer" -> Sensor.TYPE_PRESSURE
            "step_counter" -> Sensor.TYPE_STEP_COUNTER
            "gravity" -> Sensor.TYPE_GRAVITY
            else -> return result.error("UNKNOWN_SENSOR", "Unknown sensor: $sensorType", null)
        }

        val sensor = sensorManager.getDefaultSensor(type)
            ?: return result.error("UNAVAILABLE", "Sensor not available: $sensorType", null)

        var responded = false

        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                if (responded) return
                responded = true
                sensorManager.unregisterListener(this)

                val response = JSONObject().apply {
                    put("sensor", sensorType)
                    val values = JSONArray()
                    for (v in event.values) values.put(v.toDouble())
                    put("values", values)
                    put("accuracy", event.accuracy)

                    when (sensorType) {
                        "accelerometer" -> put("unit", "m/s\u00B2")
                        "gyroscope" -> put("unit", "rad/s")
                        "magnetometer", "compass" -> {
                            put("unit", "\u00B5T")
                            if (event.values.size >= 2) {
                                val heading = Math.toDegrees(
                                    atan2(event.values[1].toDouble(), event.values[0].toDouble())
                                )
                                put("heading_degrees", if (heading < 0) heading + 360 else heading)
                            }
                        }
                        "proximity" -> {
                            put("unit", "cm")
                            put("near", event.values[0] < sensor.maximumRange)
                        }
                        "ambient_light", "light" -> put("unit", "lux")
                        "pressure", "barometer" -> put("unit", "hPa")
                        "step_counter" -> put("unit", "steps")
                        "gravity" -> put("unit", "m/s\u00B2")
                    }
                }
                result.success(response.toString())
            }

            override fun onAccuracyChanged(s: Sensor, accuracy: Int) {}
        }

        sensorManager.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_NORMAL)

        // Timeout after 5 seconds
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            if (!responded) {
                responded = true
                sensorManager.unregisterListener(listener)
                result.success(JSONObject().apply {
                    put("error", "timeout")
                    put("message", "Sensor did not produce data within 5 seconds")
                    put("sensor", sensorType)
                }.toString())
            }
        }, 5000)
    }
}
