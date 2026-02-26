package com.ferri.ferri.channels

import android.content.Context
import android.net.Uri
import android.telephony.SmsManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

/**
 * Handles SMS read/send operations via the Android SMS content provider and SmsManager.
 */
class SmsChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "ferri/sms"
        private val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).apply {
            timeZone = TimeZone.getDefault()
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "readMessages" -> readMessages(call, result)
            "sendMessage" -> sendMessage(call, result)
            else -> result.notImplemented()
        }
    }

    private fun readMessages(call: MethodCall, result: MethodChannel.Result) {
        try {
            val address = call.argument<String>("address") // phone number filter
            val limit = call.argument<Int>("limit") ?: 20
            val type = call.argument<String>("type") ?: "all" // inbox, sent, all

            val uri = when (type) {
                "inbox" -> Uri.parse("content://sms/inbox")
                "sent" -> Uri.parse("content://sms/sent")
                else -> Uri.parse("content://sms")
            }

            var selection: String? = null
            var selectionArgs: Array<String>? = null
            if (address != null) {
                selection = "address LIKE ?"
                selectionArgs = arrayOf("%$address%")
            }

            val cursor = context.contentResolver.query(
                uri,
                arrayOf("_id", "address", "body", "date", "type", "read"),
                selection,
                selectionArgs,
                "date DESC LIMIT $limit"
            )

            val messages = JSONArray()
            cursor?.use { c ->
                val idIdx = c.getColumnIndex("_id")
                val addrIdx = c.getColumnIndex("address")
                val bodyIdx = c.getColumnIndex("body")
                val dateIdx = c.getColumnIndex("date")
                val typeIdx = c.getColumnIndex("type")
                val readIdx = c.getColumnIndex("read")

                while (c.moveToNext()) {
                    val msgType = if (typeIdx >= 0) c.getInt(typeIdx) else 0
                    val msg = JSONObject().apply {
                        if (idIdx >= 0) put("message_id", c.getLong(idIdx))
                        if (addrIdx >= 0) put("address", c.getString(addrIdx) ?: "")
                        if (bodyIdx >= 0) put("body", c.getString(bodyIdx) ?: "")
                        if (dateIdx >= 0) put("date", dateFormat.format(Date(c.getLong(dateIdx))))
                        put("type", when (msgType) {
                            1 -> "inbox"
                            2 -> "sent"
                            3 -> "draft"
                            else -> "unknown"
                        })
                        if (readIdx >= 0) put("read", c.getInt(readIdx) == 1)
                    }
                    messages.put(msg)
                }
            }

            result.success(messages.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "SMS permission not granted", e.message)
        } catch (e: Exception) {
            result.error("READ_ERROR", "Failed to read messages", e.message)
        }
    }

    private fun sendMessage(call: MethodCall, result: MethodChannel.Result) {
        try {
            val to = call.argument<String>("to")
                ?: return result.error("INVALID_ARGS", "to (phone number) is required", null)
            val body = call.argument<String>("body")
                ?: return result.error("INVALID_ARGS", "body is required", null)

            val smsManager = context.getSystemService(SmsManager::class.java)
                ?: return result.error("UNAVAILABLE", "SMS service not available", null)

            // Split long messages and send
            val parts = smsManager.divideMessage(body)
            if (parts.size == 1) {
                smsManager.sendTextMessage(to, null, body, null, null)
            } else {
                smsManager.sendMultipartTextMessage(to, null, parts, null, null)
            }

            val response = JSONObject().apply {
                put("to", to)
                put("sent", true)
                put("parts", parts.size)
            }
            result.success(response.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "SMS permission not granted", e.message)
        } catch (e: Exception) {
            result.error("SEND_ERROR", "Failed to send message", e.message)
        }
    }
}
