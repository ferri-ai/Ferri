package com.ferri.ferri.channels

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * Handles Wi-Fi state queries, connection info, and network scanning.
 * Read-only — Android 10+ does not support programmatic connect/disconnect.
 */
class WifiChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL_NAME = "ferri/wifi"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInfo" -> getInfo(result)
            "scan" -> scan(result)
            "getState" -> getState(result)
            else -> result.notImplemented()
        }
    }

    @Suppress("DEPRECATION")
    private fun getInfo(result: MethodChannel.Result) {
        try {
            val wm = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val info = wm.connectionInfo

            result.success(JSONObject().apply {
                put("ssid", info.ssid?.removeSurrounding("\"") ?: "<unknown>")
                put("bssid", info.bssid ?: "")
                put("rssi", info.rssi)
                put("link_speed_mbps", info.linkSpeed)
                put("frequency_mhz", info.frequency)
                put("ip_address", formatIp(info.ipAddress))
            }.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Location permission required for Wi-Fi info on Android 10+", e.message)
        } catch (e: Exception) {
            result.error("WIFI_ERROR", "Failed to get Wi-Fi info", e.message)
        }
    }

    @Suppress("DEPRECATION")
    private fun scan(result: MethodChannel.Result) {
        try {
            val wm = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val results = wm.scanResults

            val networks = JSONArray()
            for (sr in results) {
                networks.put(JSONObject().apply {
                    put("ssid", sr.SSID)
                    put("bssid", sr.BSSID)
                    put("rssi", sr.level)
                    put("frequency_mhz", sr.frequency)
                    put("capabilities", sr.capabilities)
                })
            }

            result.success(JSONObject().apply {
                put("networks", networks)
                put("count", networks.length())
            }.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Location permission required for Wi-Fi scan on Android 10+", e.message)
        } catch (e: Exception) {
            result.error("WIFI_ERROR", "Failed to scan Wi-Fi", e.message)
        }
    }

    private fun getState(result: MethodChannel.Result) {
        try {
            val wm = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

            result.success(JSONObject().apply {
                put("enabled", wm.isWifiEnabled)
                @Suppress("DEPRECATION")
                put("connected", wm.connectionInfo.networkId != -1)
            }.toString())
        } catch (e: Exception) {
            result.error("WIFI_ERROR", "Failed to get Wi-Fi state", e.message)
        }
    }

    private fun formatIp(ip: Int): String {
        return "${ip and 0xff}.${ip shr 8 and 0xff}.${ip shr 16 and 0xff}.${ip shr 24 and 0xff}"
    }
}
