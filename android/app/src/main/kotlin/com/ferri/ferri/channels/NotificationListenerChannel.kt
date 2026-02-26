package com.ferri.ferri.channels

import android.content.Context
import com.ferri.ferri.services.FerriNotificationListenerService
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class NotificationListenerChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "ferri/notification_listener"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "readNotifications" -> readNotifications(call, result)
            "activeNotifications" -> activeNotifications(result)
            else -> result.notImplemented()
        }
    }

    private fun readNotifications(call: MethodCall, result: MethodChannel.Result) {
        try {
            val packageFilter = call.argument<String>("package")
            val limit = call.argument<Int>("limit") ?: 20
            val afterDate = call.argument<String>("after_date")
            val afterMs = if (afterDate != null) {
                try {
                    java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.US)
                        .parse(afterDate)?.time
                } catch (_: Exception) { null }
            } else null

            val entries = FerriNotificationListenerService.getRecentNotifications(
                packageFilter = packageFilter,
                afterMs = afterMs,
                limit = limit
            )

            val arr = JSONArray()
            for (entry in entries) {
                arr.put(entry.toJson())
            }
            result.success(arr.toString())
        } catch (e: Exception) {
            result.error("READ_ERROR", "Failed to read notifications", e.message)
        }
    }

    private fun activeNotifications(result: MethodChannel.Result) {
        try {
            val entries = FerriNotificationListenerService.getActiveNotifications()
            val arr = JSONArray()
            for (entry in entries) {
                arr.put(entry.toJson())
            }
            result.success(arr.toString())
        } catch (e: Exception) {
            result.error("READ_ERROR", "Failed to read active notifications", e.message)
        }
    }
}
