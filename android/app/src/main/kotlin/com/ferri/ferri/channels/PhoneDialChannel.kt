package com.ferri.ferri.channels

import android.content.Context
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Handles phone dialing via Android Intent.ACTION_DIAL and Intent.ACTION_CALL.
 */
class PhoneDialChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL_NAME = "ferri/phone"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "dial" -> dial(call, result)
            else -> result.notImplemented()
        }
    }

    private fun dial(call: MethodCall, result: MethodChannel.Result) {
        try {
            val number = call.argument<String>("number")
                ?: return result.error("INVALID_ARGS", "number is required", null)
            val direct = call.argument<Boolean>("direct") ?: false

            val action = if (direct) Intent.ACTION_CALL else Intent.ACTION_DIAL
            val intent = Intent(action, Uri.parse("tel:$number")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)

            val response = JSONObject().apply {
                put("success", true)
                put("number", number)
                put("direct", direct)
            }
            result.success(response.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "CALL_PHONE permission not granted. Use direct=false to open the dialer instead.", e.message)
        } catch (e: android.content.ActivityNotFoundException) {
            result.error("NO_DIALER", "No phone dialer app available on this device", e.message)
        } catch (e: Exception) {
            result.error("DIAL_ERROR", "Failed to dial", e.message)
        }
    }
}
