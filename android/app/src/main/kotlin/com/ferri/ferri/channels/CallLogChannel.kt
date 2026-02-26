package com.ferri.ferri.channels

import android.content.Context
import android.provider.CallLog
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

/**
 * Handles call log read operations via the Android CallLog content provider.
 */
class CallLogChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "ferri/calllog"
        private val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).apply {
            timeZone = TimeZone.getDefault()
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "readCalls" -> readCalls(call, result)
            "summarizeCalls" -> summarizeCalls(call, result)
            else -> result.notImplemented()
        }
    }

    private fun readCalls(call: MethodCall, result: MethodChannel.Result) {
        try {
            val number = call.argument<String>("number")
            val type = call.argument<String>("type") ?: "all"
            val limit = call.argument<Int>("limit") ?: 20
            val afterDate = call.argument<String>("after_date")

            val selectionParts = mutableListOf<String>()
            val selectionArgsList = mutableListOf<String>()

            if (number != null) {
                selectionParts.add("${CallLog.Calls.NUMBER} LIKE ?")
                selectionArgsList.add("%$number%")
            }

            if (type != "all") {
                val callType = when (type) {
                    "incoming" -> CallLog.Calls.INCOMING_TYPE
                    "outgoing" -> CallLog.Calls.OUTGOING_TYPE
                    "missed" -> CallLog.Calls.MISSED_TYPE
                    "rejected" -> CallLog.Calls.REJECTED_TYPE
                    else -> null
                }
                if (callType != null) {
                    selectionParts.add("${CallLog.Calls.TYPE} = ?")
                    selectionArgsList.add(callType.toString())
                }
            }

            if (afterDate != null) {
                try {
                    val date = dateFormat.parse(afterDate)
                    if (date != null) {
                        selectionParts.add("${CallLog.Calls.DATE} > ?")
                        selectionArgsList.add(date.time.toString())
                    }
                } catch (e: Exception) {
                    // Ignore invalid date format
                }
            }

            val selection = if (selectionParts.isNotEmpty()) selectionParts.joinToString(" AND ") else null
            val selectionArgs = if (selectionArgsList.isNotEmpty()) selectionArgsList.toTypedArray() else null

            val cursor = context.contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(
                    CallLog.Calls._ID,
                    CallLog.Calls.NUMBER,
                    CallLog.Calls.CACHED_NAME,
                    CallLog.Calls.TYPE,
                    CallLog.Calls.DATE,
                    CallLog.Calls.DURATION
                ),
                selection,
                selectionArgs,
                "${CallLog.Calls.DATE} DESC"
            )

            val calls = JSONArray()
            cursor?.use { c ->
                val idIdx = c.getColumnIndex(CallLog.Calls._ID)
                val numberIdx = c.getColumnIndex(CallLog.Calls.NUMBER)
                val nameIdx = c.getColumnIndex(CallLog.Calls.CACHED_NAME)
                val typeIdx = c.getColumnIndex(CallLog.Calls.TYPE)
                val dateIdx = c.getColumnIndex(CallLog.Calls.DATE)
                val durationIdx = c.getColumnIndex(CallLog.Calls.DURATION)

                var count = 0
                while (c.moveToNext() && count < limit) {
                    count++
                    val callType = if (typeIdx >= 0) c.getInt(typeIdx) else 0
                    val entry = JSONObject().apply {
                        if (idIdx >= 0) put("call_id", c.getLong(idIdx))
                        if (numberIdx >= 0) put("number", c.getString(numberIdx) ?: "")
                        if (nameIdx >= 0) put("contact_name", c.getString(nameIdx) ?: "")
                        put("type", when (callType) {
                            CallLog.Calls.INCOMING_TYPE -> "incoming"
                            CallLog.Calls.OUTGOING_TYPE -> "outgoing"
                            CallLog.Calls.MISSED_TYPE -> "missed"
                            CallLog.Calls.REJECTED_TYPE -> "rejected"
                            else -> "unknown"
                        })
                        if (dateIdx >= 0) put("date", dateFormat.format(Date(c.getLong(dateIdx))))
                        if (durationIdx >= 0) put("duration_seconds", c.getLong(durationIdx))
                    }
                    calls.put(entry)
                }
            }

            result.success(calls.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Call log permission not granted", e.message)
        } catch (e: Exception) {
            result.error("READ_ERROR", "Failed to read call log", e.message)
        }
    }

    private fun summarizeCalls(call: MethodCall, result: MethodChannel.Result) {
        try {
            val days = call.argument<Int>("days") ?: 7

            val cutoff = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, -days)
            }.timeInMillis

            val selection = "${CallLog.Calls.DATE} > ?"
            val selectionArgs = arrayOf(cutoff.toString())

            val cursor = context.contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(
                    CallLog.Calls.NUMBER,
                    CallLog.Calls.CACHED_NAME,
                    CallLog.Calls.TYPE,
                    CallLog.Calls.DURATION
                ),
                selection,
                selectionArgs,
                "${CallLog.Calls.DATE} DESC"
            )

            var totalCalls = 0
            var incomingCount = 0
            var outgoingCount = 0
            var missedCount = 0
            var totalDuration = 0L
            val contactCounts = mutableMapOf<String, Int>()

            cursor?.use { c ->
                val numberIdx = c.getColumnIndex(CallLog.Calls.NUMBER)
                val nameIdx = c.getColumnIndex(CallLog.Calls.CACHED_NAME)
                val typeIdx = c.getColumnIndex(CallLog.Calls.TYPE)
                val durationIdx = c.getColumnIndex(CallLog.Calls.DURATION)

                while (c.moveToNext()) {
                    totalCalls++

                    val callType = if (typeIdx >= 0) c.getInt(typeIdx) else 0
                    when (callType) {
                        CallLog.Calls.INCOMING_TYPE -> incomingCount++
                        CallLog.Calls.OUTGOING_TYPE -> outgoingCount++
                        CallLog.Calls.MISSED_TYPE -> missedCount++
                    }

                    if (durationIdx >= 0) {
                        totalDuration += c.getLong(durationIdx)
                    }

                    val contactLabel = if (nameIdx >= 0) {
                        val name = c.getString(nameIdx)
                        if (!name.isNullOrBlank()) name
                        else if (numberIdx >= 0) c.getString(numberIdx) ?: "Unknown"
                        else "Unknown"
                    } else if (numberIdx >= 0) {
                        c.getString(numberIdx) ?: "Unknown"
                    } else {
                        "Unknown"
                    }
                    contactCounts[contactLabel] = (contactCounts[contactLabel] ?: 0) + 1
                }
            }

            val avgDuration = if (totalCalls > 0) totalDuration / totalCalls else 0L

            val topContacts = JSONArray()
            contactCounts.entries
                .sortedByDescending { it.value }
                .take(5)
                .forEach { (name, count) ->
                    topContacts.put(JSONObject().apply {
                        put("name", name)
                        put("call_count", count)
                    })
                }

            val summary = JSONObject().apply {
                put("period_days", days)
                put("total_calls", totalCalls)
                put("incoming", incomingCount)
                put("outgoing", outgoingCount)
                put("missed", missedCount)
                put("total_duration_seconds", totalDuration)
                put("avg_duration_seconds", avgDuration)
                put("unique_contacts", contactCounts.size)
                put("top_contacts", topContacts)
            }

            result.success(summary.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Call log permission not granted", e.message)
        } catch (e: Exception) {
            result.error("READ_ERROR", "Failed to summarize call log", e.message)
        }
    }
}
