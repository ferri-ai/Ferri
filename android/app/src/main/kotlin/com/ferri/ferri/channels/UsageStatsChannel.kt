package com.ferri.ferri.channels

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class UsageStatsChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "ferri/usage_stats"
        private val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).apply {
            timeZone = TimeZone.getDefault()
        }
    }

    private val usageStatsManager: UsageStatsManager by lazy {
        context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "queryStats" -> queryStats(call, result)
            "currentApp" -> currentApp(result)
            else -> result.notImplemented()
        }
    }

    private fun queryStats(call: MethodCall, result: MethodChannel.Result) {
        try {
            val days = call.argument<Int>("days") ?: 1
            val limit = call.argument<Int>("limit") ?: 20
            val endTime = System.currentTimeMillis()
            val startTime = endTime - (days.toLong() * 24 * 60 * 60 * 1000)

            val intervalType = when {
                days <= 1 -> UsageStatsManager.INTERVAL_DAILY
                days <= 7 -> UsageStatsManager.INTERVAL_WEEKLY
                else -> UsageStatsManager.INTERVAL_MONTHLY
            }

            val stats = usageStatsManager.queryUsageStats(intervalType, startTime, endTime)
                ?: return result.success(JSONArray().toString())

            val pm = context.packageManager
            val filtered = stats
                .filter { it.totalTimeInForeground > 0 }
                .sortedByDescending { it.totalTimeInForeground }
                .take(limit)

            val arr = JSONArray()
            for (stat in filtered) {
                val appLabel = try {
                    val appInfo = pm.getApplicationInfo(stat.packageName, 0)
                    pm.getApplicationLabel(appInfo).toString()
                } catch (_: PackageManager.NameNotFoundException) {
                    stat.packageName
                }

                arr.put(JSONObject().apply {
                    put("package", stat.packageName)
                    put("app", appLabel)
                    put("foreground_time_ms", stat.totalTimeInForeground)
                    put("foreground_time_display", formatDuration(stat.totalTimeInForeground))
                    put("last_used", dateFormat.format(Date(stat.lastTimeUsed)))
                })
            }

            result.success(arr.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Usage stats permission not granted", e.message)
        } catch (e: Exception) {
            result.error("QUERY_ERROR", "Failed to query usage stats", e.message)
        }
    }

    private fun currentApp(result: MethodChannel.Result) {
        try {
            val endTime = System.currentTimeMillis()
            val startTime = endTime - 60_000

            val events = usageStatsManager.queryEvents(startTime, endTime)
            var lastForegroundPackage: String? = null
            var lastForegroundTime: Long = 0

            val event = UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                    lastForegroundPackage = event.packageName
                    lastForegroundTime = event.timeStamp
                }
            }

            val todayStart = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis

            val todayStats = usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY, todayStart, endTime
            )
            val totalScreenTimeMs = todayStats?.sumOf { it.totalTimeInForeground } ?: 0

            val pm = context.packageManager
            val appLabel = if (lastForegroundPackage != null) {
                try {
                    val appInfo = pm.getApplicationInfo(lastForegroundPackage, 0)
                    pm.getApplicationLabel(appInfo).toString()
                } catch (_: Exception) {
                    lastForegroundPackage
                }
            } else null

            result.success(JSONObject().apply {
                put("current_app", appLabel ?: "Unknown")
                put("current_package", lastForegroundPackage ?: "")
                put("current_since", if (lastForegroundTime > 0) dateFormat.format(Date(lastForegroundTime)) else "")
                put("today_screen_time_ms", totalScreenTimeMs)
                put("today_screen_time_display", formatDuration(totalScreenTimeMs))
            }.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Usage stats permission not granted", e.message)
        } catch (e: Exception) {
            result.error("QUERY_ERROR", "Failed to get current app", e.message)
        }
    }

    private fun formatDuration(ms: Long): String {
        val hours = ms / 3_600_000
        val minutes = (ms % 3_600_000) / 60_000
        return if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"
    }
}
