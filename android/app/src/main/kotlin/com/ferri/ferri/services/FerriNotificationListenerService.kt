package com.ferri.ferri.services

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class FerriNotificationListenerService : NotificationListenerService() {

    companion object {
        private val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).apply {
            timeZone = TimeZone.getDefault()
        }

        private const val MAX_BUFFER_SIZE = 100
        val notificationBuffer = mutableListOf<NotificationEntry>()
        private val lock = Any()

        fun getRecentNotifications(
            packageFilter: String? = null,
            afterMs: Long? = null,
            limit: Int = 20
        ): List<NotificationEntry> {
            synchronized(lock) {
                var filtered = notificationBuffer.asSequence()
                if (packageFilter != null) {
                    filtered = filtered.filter { it.packageName.contains(packageFilter, ignoreCase = true) }
                }
                if (afterMs != null) {
                    filtered = filtered.filter { it.timestampMs >= afterMs }
                }
                return filtered.sortedByDescending { it.timestampMs }.take(limit).toList()
            }
        }

        fun getActiveNotifications(): List<NotificationEntry> {
            synchronized(lock) {
                return notificationBuffer.filter { !it.dismissed }.sortedByDescending { it.timestampMs }
            }
        }
    }

    data class NotificationEntry(
        val key: String,
        val packageName: String,
        val appLabel: String,
        val title: String,
        val text: String,
        val timestampMs: Long,
        val category: String?,
        var dismissed: Boolean = false
    ) {
        fun toJson(): JSONObject = JSONObject().apply {
            put("key", key)
            put("package", packageName)
            put("app", appLabel)
            put("title", title)
            put("text", text)
            put("date", dateFormat.format(Date(timestampMs)))
            put("category", category ?: "")
            put("dismissed", dismissed)
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return
        if (sbn.packageName == applicationContext.packageName) return

        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        if (title.isEmpty() && text.isEmpty()) return

        val appLabel = try {
            val pm = applicationContext.packageManager
            val appInfo = pm.getApplicationInfo(sbn.packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (_: Exception) {
            sbn.packageName
        }

        val entry = NotificationEntry(
            key = sbn.key,
            packageName = sbn.packageName,
            appLabel = appLabel,
            title = title,
            text = text,
            timestampMs = sbn.postTime,
            category = notification.category
        )

        synchronized(lock) {
            notificationBuffer.add(entry)
            while (notificationBuffer.size > MAX_BUFFER_SIZE) {
                notificationBuffer.removeAt(0)
            }
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        sbn ?: return
        synchronized(lock) {
            notificationBuffer.find { it.key == sbn.key }?.dismissed = true
        }
    }
}
