package com.ferri.ferri.channels

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.provider.CalendarContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

/**
 * Handles calendar read/write operations via CalendarContract.
 * Registered as a MethodChannel handler in MainActivity.
 */
class CalendarChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "ferri/calendar"
        private val iso8601Format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).apply {
            timeZone = TimeZone.getDefault()
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "readEvents" -> readEvents(call, result)
            "createEvent" -> createEvent(call, result)
            "updateEvent" -> updateEvent(call, result)
            "deleteEvent" -> deleteEvent(call, result)
            else -> result.notImplemented()
        }
    }

    private fun readEvents(call: MethodCall, result: MethodChannel.Result) {
        try {
            val startDate = call.argument<String>("start_date")
                ?: return result.error("INVALID_ARGS", "start_date is required", null)
            val endDate = call.argument<String>("end_date")
                ?: return result.error("INVALID_ARGS", "end_date is required", null)
            val calendarId = call.argument<String>("calendar_id")

            val startMillis = iso8601Format.parse(startDate)?.time
                ?: return result.error("PARSE_ERROR", "Invalid start_date format", null)
            val endMillis = iso8601Format.parse(endDate)?.time
                ?: return result.error("PARSE_ERROR", "Invalid end_date format", null)

            // Use Instances URI for date-range queries (handles recurring events)
            val builder = CalendarContract.Instances.CONTENT_URI.buildUpon()
            android.content.ContentUris.appendId(builder, startMillis)
            android.content.ContentUris.appendId(builder, endMillis)

            val projection = arrayOf(
                CalendarContract.Instances.EVENT_ID,
                CalendarContract.Instances.TITLE,
                CalendarContract.Instances.BEGIN,
                CalendarContract.Instances.END,
                CalendarContract.Instances.EVENT_LOCATION,
                CalendarContract.Instances.DESCRIPTION,
                CalendarContract.Instances.CALENDAR_ID,
                CalendarContract.Instances.ALL_DAY
            )

            var selection: String? = null
            var selectionArgs: Array<String>? = null
            if (calendarId != null) {
                selection = "${CalendarContract.Instances.CALENDAR_ID} = ?"
                selectionArgs = arrayOf(calendarId)
            }

            val cursor: Cursor? = context.contentResolver.query(
                builder.build(),
                projection,
                selection,
                selectionArgs,
                "${CalendarContract.Instances.BEGIN} ASC"
            )

            val events = JSONArray()
            cursor?.use { c ->
                while (c.moveToNext()) {
                    val event = JSONObject().apply {
                        put("event_id", c.getLong(0))
                        put("title", c.getString(1) ?: "")
                        put("start", formatMillis(c.getLong(2)))
                        put("end", formatMillis(c.getLong(3)))
                        put("location", c.getString(4) ?: "")
                        put("description", c.getString(5) ?: "")
                        put("calendar_id", c.getLong(6))
                        put("all_day", c.getInt(7) == 1)
                    }
                    events.put(event)
                }
            }

            result.success(events.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Calendar permission not granted", e.message)
        } catch (e: Exception) {
            result.error("READ_ERROR", "Failed to read events", e.message)
        }
    }

    private fun createEvent(call: MethodCall, result: MethodChannel.Result) {
        try {
            val title = call.argument<String>("title")
                ?: return result.error("INVALID_ARGS", "title is required", null)
            val startTime = call.argument<String>("start_time")
                ?: return result.error("INVALID_ARGS", "start_time is required", null)
            val endTime = call.argument<String>("end_time")
                ?: return result.error("INVALID_ARGS", "end_time is required", null)

            val startMillis = iso8601Format.parse(startTime)?.time
                ?: return result.error("PARSE_ERROR", "Invalid start_time format", null)
            val endMillis = iso8601Format.parse(endTime)?.time
                ?: return result.error("PARSE_ERROR", "Invalid end_time format", null)

            val calendarId = call.argument<String>("calendar_id")?.toLongOrNull()
                ?: getDefaultCalendarId()
                ?: return result.error("NO_CALENDAR", "No writable calendar found", null)

            val values = ContentValues().apply {
                put(CalendarContract.Events.CALENDAR_ID, calendarId)
                put(CalendarContract.Events.TITLE, title)
                put(CalendarContract.Events.DTSTART, startMillis)
                put(CalendarContract.Events.DTEND, endMillis)
                put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
                call.argument<String>("location")?.let {
                    put(CalendarContract.Events.EVENT_LOCATION, it)
                }
                call.argument<String>("description")?.let {
                    put(CalendarContract.Events.DESCRIPTION, it)
                }
            }

            val uri: Uri? = context.contentResolver.insert(
                CalendarContract.Events.CONTENT_URI, values
            )

            if (uri != null) {
                val eventId = uri.lastPathSegment?.toLongOrNull() ?: -1L
                val response = JSONObject().apply {
                    put("event_id", eventId)
                    put("title", title)
                    put("start", startTime)
                    put("end", endTime)
                }
                result.success(response.toString())
            } else {
                result.error("INSERT_ERROR", "Failed to insert event", null)
            }
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Calendar permission not granted", e.message)
        } catch (e: Exception) {
            result.error("CREATE_ERROR", "Failed to create event", e.message)
        }
    }

    private fun updateEvent(call: MethodCall, result: MethodChannel.Result) {
        try {
            val eventId = call.argument<String>("event_id")?.toLongOrNull()
                ?: return result.error("INVALID_ARGS", "event_id is required", null)

            val values = ContentValues()
            call.argument<String>("title")?.let {
                values.put(CalendarContract.Events.TITLE, it)
            }
            call.argument<String>("start_time")?.let {
                val millis = iso8601Format.parse(it)?.time
                    ?: return result.error("PARSE_ERROR", "Invalid start_time format", null)
                values.put(CalendarContract.Events.DTSTART, millis)
            }
            call.argument<String>("end_time")?.let {
                val millis = iso8601Format.parse(it)?.time
                    ?: return result.error("PARSE_ERROR", "Invalid end_time format", null)
                values.put(CalendarContract.Events.DTEND, millis)
            }
            call.argument<String>("location")?.let {
                values.put(CalendarContract.Events.EVENT_LOCATION, it)
            }
            call.argument<String>("description")?.let {
                values.put(CalendarContract.Events.DESCRIPTION, it)
            }

            if (values.size() == 0) {
                return result.error("INVALID_ARGS", "No fields to update", null)
            }

            val uri = android.content.ContentUris.withAppendedId(
                CalendarContract.Events.CONTENT_URI, eventId
            )
            val rowsUpdated = context.contentResolver.update(uri, values, null, null)

            val response = JSONObject().apply {
                put("event_id", eventId)
                put("updated", rowsUpdated > 0)
                put("rows_affected", rowsUpdated)
            }
            result.success(response.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Calendar permission not granted", e.message)
        } catch (e: Exception) {
            result.error("UPDATE_ERROR", "Failed to update event", e.message)
        }
    }

    private fun deleteEvent(call: MethodCall, result: MethodChannel.Result) {
        try {
            val eventId = call.argument<String>("event_id")?.toLongOrNull()
                ?: return result.error("INVALID_ARGS", "event_id is required", null)

            val uri = android.content.ContentUris.withAppendedId(
                CalendarContract.Events.CONTENT_URI, eventId
            )
            val rowsDeleted = context.contentResolver.delete(uri, null, null)

            val response = JSONObject().apply {
                put("event_id", eventId)
                put("deleted", rowsDeleted > 0)
                put("rows_affected", rowsDeleted)
            }
            result.success(response.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Calendar permission not granted", e.message)
        } catch (e: Exception) {
            result.error("DELETE_ERROR", "Failed to delete event", e.message)
        }
    }

    /**
     * Find the first writable calendar on the device (Google, Samsung, etc.).
     * Falls back to creating an ACCOUNT_TYPE_LOCAL calendar if none exist.
     */
    private fun getDefaultCalendarId(): Long? {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL
        )
        val selection = "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL} >= ?"
        val selectionArgs = arrayOf(
            CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR.toString()
        )

        context.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                return cursor.getLong(0)
            }
        }

        // No writable calendar found — create a device-local one
        return createLocalCalendar()
    }

    /**
     * Create a device-local calendar using ACCOUNT_TYPE_LOCAL.
     * This is the official Android mechanism for calendars that don't sync.
     * Only called when no writable calendar exists (e.g. stock Android with no account).
     */
    private fun createLocalCalendar(): Long? {
        val values = ContentValues().apply {
            put(CalendarContract.Calendars.ACCOUNT_NAME, "Ferri")
            put(CalendarContract.Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
            put(CalendarContract.Calendars.NAME, "Ferri Calendar")
            put(CalendarContract.Calendars.CALENDAR_DISPLAY_NAME, "Ferri Calendar")
            put(CalendarContract.Calendars.CALENDAR_COLOR, 0xFF6750A4.toInt())
            put(CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
                CalendarContract.Calendars.CAL_ACCESS_OWNER)
            put(CalendarContract.Calendars.OWNER_ACCOUNT, "Ferri")
            put(CalendarContract.Calendars.VISIBLE, 1)
            put(CalendarContract.Calendars.SYNC_EVENTS, 1)
        }

        // Inserting a calendar requires the caller URI with sync adapter params
        val uri = CalendarContract.Calendars.CONTENT_URI.buildUpon()
            .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
            .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_NAME, "Ferri")
            .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_TYPE,
                CalendarContract.ACCOUNT_TYPE_LOCAL)
            .build()

        val resultUri = context.contentResolver.insert(uri, values)
        return resultUri?.lastPathSegment?.toLongOrNull()
    }

    private fun formatMillis(millis: Long): String {
        return iso8601Format.format(Date(millis))
    }
}
