package com.ferri.ferri

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class FerriService : Service() {
    companion object {
        const val CHANNEL_ID = "ferri_service"
        const val NOTIFICATION_ID = 1
        private const val ACTION_UPDATE = "com.ferri.UPDATE_NOTIFICATION"

        fun start(context: Context, channelCount: Int, cronJobCount: Int = 0) {
            val intent = Intent(context, FerriService::class.java).apply {
                putExtra("channel_count", channelCount)
                putExtra("cron_job_count", cronJobCount)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, FerriService::class.java))
        }

        fun updateNotification(context: Context, channelCount: Int, cronJobCount: Int = 0) {
            val intent = Intent(context, FerriService::class.java).apply {
                action = ACTION_UPDATE
                putExtra("channel_count", channelCount)
                putExtra("cron_job_count", cronJobCount)
            }
            context.startService(intent)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val channelCount = intent?.getIntExtra("channel_count", 0) ?: 0
        val cronJobCount = intent?.getIntExtra("cron_job_count", 0) ?: 0

        val notification = buildNotification(channelCount, cronJobCount)
        startForeground(NOTIFICATION_ID, notification)

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Ferri Background Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps Ferri running for messaging channels"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(channelCount: Int, cronJobCount: Int = 0): Notification {
        val tapIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, tapIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val channelPart = if (channelCount > 0) {
            "$channelCount channel${if (channelCount > 1) "s" else ""}"
        } else null

        val cronPart = if (cronJobCount > 0) {
            "$cronJobCount job${if (cronJobCount > 1) "s" else ""}"
        } else null

        val subtitle = when {
            channelPart != null && cronPart != null -> "$channelPart, $cronPart active"
            channelPart != null -> "$channelPart active"
            cronPart != null -> "$cronPart active"
            else -> "Running in background"
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Ferri")
            .setContentText(subtitle)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
