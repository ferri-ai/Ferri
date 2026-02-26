package com.ferri.ferri.channels

import android.content.Context
import android.content.Intent
import android.provider.AlarmClock
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Handles alarm operations using AlarmClock intents.
 * Delegates to the system alarm/clock app.
 */
class AlarmChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "ferri/alarms"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setAlarm" -> setAlarm(call, result)
            "setTimer" -> setTimer(call, result)
            "showAlarms" -> showAlarms(result)
            else -> result.notImplemented()
        }
    }

    private fun setAlarm(call: MethodCall, result: MethodChannel.Result) {
        try {
            val hour = call.argument<Int>("hour")
                ?: return result.error("INVALID_ARGS", "hour is required", null)
            val minute = call.argument<Int>("minute")
                ?: return result.error("INVALID_ARGS", "minute is required", null)
            val message = call.argument<String>("message") ?: ""
            val skipUi = call.argument<Boolean>("skip_ui") ?: true

            val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                putExtra(AlarmClock.EXTRA_HOUR, hour)
                putExtra(AlarmClock.EXTRA_MINUTES, minute)
                if (message.isNotEmpty()) {
                    putExtra(AlarmClock.EXTRA_MESSAGE, message)
                }
                putExtra(AlarmClock.EXTRA_SKIP_UI, skipUi)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            context.startActivity(intent)

            val response = JSONObject().apply {
                put("success", true)
                put("hour", hour)
                put("minute", minute)
                put("message", message)
            }
            result.success(response.toString())
        } catch (e: Exception) {
            result.error("ALARM_ERROR", "Failed to set alarm", e.message)
        }
    }

    private fun setTimer(call: MethodCall, result: MethodChannel.Result) {
        try {
            val seconds = call.argument<Int>("seconds")
                ?: return result.error("INVALID_ARGS", "seconds is required", null)
            val message = call.argument<String>("message") ?: "Ferri Timer"
            val skipUi = call.argument<Boolean>("skip_ui") ?: true

            val intent = Intent(AlarmClock.ACTION_SET_TIMER).apply {
                putExtra(AlarmClock.EXTRA_LENGTH, seconds)
                putExtra(AlarmClock.EXTRA_MESSAGE, message)
                putExtra(AlarmClock.EXTRA_SKIP_UI, skipUi)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            context.startActivity(intent)

            val response = JSONObject().apply {
                put("success", true)
                put("seconds", seconds)
                put("message", message)
            }
            result.success(response.toString())
        } catch (e: Exception) {
            result.error("TIMER_ERROR", "Failed to set timer", e.message)
        }
    }

    private fun showAlarms(result: MethodChannel.Result) {
        try {
            val intent = Intent(AlarmClock.ACTION_SHOW_ALARMS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)

            val response = JSONObject().apply {
                put("success", true)
                put("message", "Opened system alarms app")
            }
            result.success(response.toString())
        } catch (e: Exception) {
            result.error("SHOW_ERROR", "Failed to show alarms", e.message)
        }
    }
}
