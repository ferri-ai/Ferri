package com.ferri.ferri.channels

import android.content.Context
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Handles email composition via Intent.ACTION_SENDTO with mailto: URI.
 */
class EmailChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL_NAME = "ferri/email"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "compose" -> compose(call, result)
            else -> result.notImplemented()
        }
    }

    private fun compose(call: MethodCall, result: MethodChannel.Result) {
        try {
            val to = call.argument<String>("to") ?: ""
            val cc = call.argument<String>("cc") ?: ""
            val subject = call.argument<String>("subject") ?: ""
            val body = call.argument<String>("body") ?: ""

            val intent = Intent(Intent.ACTION_SENDTO).apply {
                data = Uri.parse("mailto:")
                if (to.isNotEmpty()) putExtra(Intent.EXTRA_EMAIL, arrayOf(to))
                if (cc.isNotEmpty()) putExtra(Intent.EXTRA_CC, arrayOf(cc))
                if (subject.isNotEmpty()) putExtra(Intent.EXTRA_SUBJECT, subject)
                if (body.isNotEmpty()) putExtra(Intent.EXTRA_TEXT, body)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)

            val response = JSONObject().apply {
                put("success", true)
                put("to", to)
                put("subject", subject)
            }
            result.success(response.toString())
        } catch (e: android.content.ActivityNotFoundException) {
            result.error("NO_EMAIL_APP", "No email app available on this device", e.message)
        } catch (e: Exception) {
            result.error("EMAIL_ERROR", "Failed to compose email", e.message)
        }
    }
}
