package com.ferri.ferri.channels

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * Handles Bluetooth state queries, paired device listing, and BLE scanning
 * via the Android Bluetooth APIs.
 */
@SuppressLint("MissingPermission")
class BluetoothChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "ferri/bluetooth"
        const val SCAN_DURATION_MS = 10_000L
    }

    private val bluetoothManager: BluetoothManager? =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    private val adapter: BluetoothAdapter? = bluetoothManager?.adapter

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getState" -> getState(result)
            "listPaired" -> listPaired(result)
            "scan" -> scan(call, result)
            else -> result.notImplemented()
        }
    }

    private fun getState(result: MethodChannel.Result) {
        try {
            if (adapter == null) {
                val response = JSONObject().apply {
                    put("available", false)
                    put("enabled", false)
                    put("name", "")
                    put("state", "off")
                }
                result.success(response.toString())
                return
            }

            val stateStr = when (adapter.state) {
                BluetoothAdapter.STATE_ON -> "on"
                BluetoothAdapter.STATE_OFF -> "off"
                BluetoothAdapter.STATE_TURNING_ON -> "turning_on"
                BluetoothAdapter.STATE_TURNING_OFF -> "turning_off"
                else -> "off"
            }

            val response = JSONObject().apply {
                put("available", true)
                put("enabled", adapter.isEnabled)
                put("name", adapter.name ?: "")
                put("state", stateStr)
            }
            result.success(response.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Bluetooth permission not granted", e.message)
        } catch (e: Exception) {
            result.error("STATE_ERROR", "Failed to get Bluetooth state", e.message)
        }
    }

    private fun listPaired(result: MethodChannel.Result) {
        try {
            if (adapter == null || !adapter.isEnabled) {
                result.success(JSONArray().toString())
                return
            }

            val devices = JSONArray()
            adapter.bondedDevices?.forEach { device ->
                val entry = JSONObject().apply {
                    put("name", device.name ?: "Unknown")
                    put("address", device.address ?: "")
                    put("type", when (device.type) {
                        BluetoothDevice.DEVICE_TYPE_CLASSIC -> "classic"
                        BluetoothDevice.DEVICE_TYPE_LE -> "le"
                        BluetoothDevice.DEVICE_TYPE_DUAL -> "dual"
                        else -> "unknown"
                    })
                    put("bond_state", when (device.bondState) {
                        BluetoothDevice.BOND_BONDED -> "bonded"
                        BluetoothDevice.BOND_BONDING -> "bonding"
                        BluetoothDevice.BOND_NONE -> "none"
                        else -> "none"
                    })
                }
                devices.put(entry)
            }

            result.success(devices.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Bluetooth permission not granted", e.message)
        } catch (e: Exception) {
            result.error("LIST_ERROR", "Failed to list paired devices", e.message)
        }
    }

    private fun scan(call: MethodCall, result: MethodChannel.Result) {
        try {
            val durationMs = call.argument<Int>("duration_ms")?.toLong()
                ?: SCAN_DURATION_MS
            val cappedDuration = durationMs.coerceIn(1_000L, 30_000L)

            if (adapter == null || !adapter.isEnabled) {
                val response = JSONObject().apply {
                    put("devices", JSONArray())
                    put("count", 0)
                    put("scan_duration_ms", 0)
                    put("error", "Bluetooth is not enabled")
                }
                result.success(response.toString())
                return
            }

            val scanner: BluetoothLeScanner? = adapter.bluetoothLeScanner
            if (scanner == null) {
                val response = JSONObject().apply {
                    put("devices", JSONArray())
                    put("count", 0)
                    put("scan_duration_ms", 0)
                    put("error", "BLE scanner not available")
                }
                result.success(response.toString())
                return
            }

            val discoveredDevices = mutableMapOf<String, ScanResult>()

            val scanCallback = object : ScanCallback() {
                override fun onScanResult(callbackType: Int, scanResult: ScanResult) {
                    val address = scanResult.device.address
                    // Keep the result with the strongest RSSI, or the latest one
                    val existing = discoveredDevices[address]
                    if (existing == null || scanResult.rssi > existing.rssi) {
                        discoveredDevices[address] = scanResult
                    }
                }

                override fun onScanFailed(errorCode: Int) {
                    val response = JSONObject().apply {
                        put("devices", JSONArray())
                        put("count", 0)
                        put("scan_duration_ms", 0)
                        put("error", "Scan failed with error code: $errorCode")
                    }
                    result.success(response.toString())
                }
            }

            scanner.startScan(scanCallback)

            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    scanner.stopScan(scanCallback)
                } catch (_: Exception) {
                    // Scanner may already be stopped
                }

                val devices = JSONArray()
                discoveredDevices.values.forEach { scanResult ->
                    val device = scanResult.device
                    val entry = JSONObject().apply {
                        put("name", device.name ?: "Unknown")
                        put("address", device.address ?: "")
                        put("rssi", scanResult.rssi)
                        put("type", when (device.type) {
                            BluetoothDevice.DEVICE_TYPE_CLASSIC -> "classic"
                            BluetoothDevice.DEVICE_TYPE_LE -> "le"
                            BluetoothDevice.DEVICE_TYPE_DUAL -> "dual"
                            else -> "unknown"
                        })
                    }
                    devices.put(entry)
                }

                val response = JSONObject().apply {
                    put("devices", devices)
                    put("count", devices.length())
                    put("scan_duration_ms", cappedDuration)
                }
                result.success(response.toString())
            }, cappedDuration)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Bluetooth scan permission not granted", e.message)
        } catch (e: Exception) {
            result.error("SCAN_ERROR", "Failed to scan for devices", e.message)
        }
    }
}
