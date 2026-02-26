package com.ferri.ferri.channels

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Provides device information: battery, storage, connectivity, system info.
 */
class DeviceInfoChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "ferri/device_info"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getDeviceInfo" -> getDeviceInfo(result)
            "getBattery" -> getBattery(result)
            "getStorage" -> getStorage(result)
            "getConnectivity" -> getConnectivity(result)
            "setFlashlight" -> setFlashlight(call, result)
            "setBrightness" -> setBrightness(call, result)
            else -> result.notImplemented()
        }
    }

    private fun getDeviceInfo(result: MethodChannel.Result) {
        try {
            val response = JSONObject().apply {
                put("manufacturer", Build.MANUFACTURER)
                put("model", Build.MODEL)
                put("device", Build.DEVICE)
                put("android_version", Build.VERSION.RELEASE)
                put("sdk_version", Build.VERSION.SDK_INT)
                put("brand", Build.BRAND)
                put("product", Build.PRODUCT)
            }
            result.success(response.toString())
        } catch (e: Exception) {
            result.error("INFO_ERROR", "Failed to get device info", e.message)
        }
    }

    private fun getBattery(result: MethodChannel.Result) {
        try {
            val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            val level = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)

            val intent = context.registerReceiver(null,
                IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                    status == BatteryManager.BATTERY_STATUS_FULL
            val plugged = intent?.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1) ?: -1
            val chargingSource = when (plugged) {
                BatteryManager.BATTERY_PLUGGED_AC -> "ac"
                BatteryManager.BATTERY_PLUGGED_USB -> "usb"
                BatteryManager.BATTERY_PLUGGED_WIRELESS -> "wireless"
                else -> "none"
            }
            val temperature = (intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0) / 10.0

            val response = JSONObject().apply {
                put("level", level)
                put("is_charging", isCharging)
                put("charging_source", chargingSource)
                put("temperature_celsius", temperature)
            }
            result.success(response.toString())
        } catch (e: Exception) {
            result.error("BATTERY_ERROR", "Failed to get battery info", e.message)
        }
    }

    private fun getStorage(result: MethodChannel.Result) {
        try {
            val stat = StatFs(Environment.getDataDirectory().path)
            val totalBytes = stat.totalBytes
            val freeBytes = stat.freeBytes
            val usedBytes = totalBytes - freeBytes

            val response = JSONObject().apply {
                put("total_gb", String.format("%.1f", totalBytes / 1_073_741_824.0))
                put("used_gb", String.format("%.1f", usedBytes / 1_073_741_824.0))
                put("free_gb", String.format("%.1f", freeBytes / 1_073_741_824.0))
                put("used_percent", String.format("%.1f", usedBytes * 100.0 / totalBytes))
            }
            result.success(response.toString())
        } catch (e: Exception) {
            result.error("STORAGE_ERROR", "Failed to get storage info", e.message)
        }
    }

    private fun getConnectivity(result: MethodChannel.Result) {
        try {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = cm.activeNetwork
            val caps = if (network != null) cm.getNetworkCapabilities(network) else null

            val connected = caps != null
            val type = when {
                caps == null -> "none"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
                else -> "other"
            }

            val response = JSONObject().apply {
                put("connected", connected)
                put("type", type)
            }
            result.success(response.toString())
        } catch (e: Exception) {
            result.error("CONNECTIVITY_ERROR", "Failed to get connectivity", e.message)
        }
    }

    private fun setFlashlight(call: MethodCall, result: MethodChannel.Result) {
        try {
            val enabled = call.argument<Boolean>("enabled")
                ?: return result.error("INVALID_ARGS", "enabled is required", null)

            val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as android.hardware.camera2.CameraManager
            val cameraId = cameraManager.cameraIdList.firstOrNull()
                ?: return result.error("NO_CAMERA", "No camera found for flashlight", null)

            cameraManager.setTorchMode(cameraId, enabled)

            val response = JSONObject().apply {
                put("flashlight", if (enabled) "on" else "off")
            }
            result.success(response.toString())
        } catch (e: Exception) {
            result.error("FLASHLIGHT_ERROR", "Failed to set flashlight", e.message)
        }
    }

    private fun setBrightness(call: MethodCall, result: MethodChannel.Result) {
        try {
            val level = call.argument<Int>("level")
                ?: return result.error("INVALID_ARGS", "level (0-255) is required", null)

            val clamped = level.coerceIn(0, 255)

            // Check if we can write settings
            if (!Settings.System.canWrite(context)) {
                val response = JSONObject().apply {
                    put("success", false)
                    put("error", "Write settings permission required. Please grant it in system settings.")
                }
                return result.success(response.toString())
            }

            Settings.System.putInt(
                context.contentResolver,
                Settings.System.SCREEN_BRIGHTNESS_MODE,
                Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL
            )
            Settings.System.putInt(
                context.contentResolver,
                Settings.System.SCREEN_BRIGHTNESS,
                clamped
            )

            val response = JSONObject().apply {
                put("success", true)
                put("brightness", clamped)
                put("percent", String.format("%.0f", clamped * 100.0 / 255))
            }
            result.success(response.toString())
        } catch (e: Exception) {
            result.error("BRIGHTNESS_ERROR", "Failed to set brightness", e.message)
        }
    }
}
