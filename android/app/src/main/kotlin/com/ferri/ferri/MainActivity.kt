package com.ferri.ferri

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ferri.ferri.channels.AlarmChannel
import com.ferri.ferri.channels.AppLauncherChannel
import com.ferri.ferri.channels.CalendarChannel
import com.ferri.ferri.channels.ContactsChannel
import com.ferri.ferri.channels.DeviceInfoChannel
import com.ferri.ferri.channels.LocationChannel
import com.ferri.ferri.channels.CallLogChannel
import com.ferri.ferri.channels.BluetoothChannel
import com.ferri.ferri.channels.NotificationListenerChannel
import com.ferri.ferri.channels.PhoneDialChannel
import com.ferri.ferri.channels.PermissionsChannel
import com.ferri.ferri.channels.SmsChannel
import com.ferri.ferri.channels.AccessibilityChannel
import com.ferri.ferri.channels.EmailChannel
import com.ferri.ferri.channels.MapsChannel
import com.ferri.ferri.channels.SharingChannel
import com.ferri.ferri.channels.AudioChannel
import com.ferri.ferri.channels.WifiChannel
import com.ferri.ferri.channels.SensorChannel
import com.ferri.ferri.channels.FilesChannel
import com.ferri.ferri.channels.NfcChannel
import com.ferri.ferri.channels.GeofenceChannel
import com.ferri.ferri.channels.UsageStatsChannel
import android.content.Intent

class MainActivity : FlutterActivity() {
    private var filesChannel: FilesChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, CalendarChannel.CHANNEL_NAME)
            .setMethodCallHandler(CalendarChannel(this))
        MethodChannel(messenger, ContactsChannel.CHANNEL_NAME)
            .setMethodCallHandler(ContactsChannel(this))
        MethodChannel(messenger, LocationChannel.CHANNEL_NAME)
            .setMethodCallHandler(LocationChannel(this))
        MethodChannel(messenger, SmsChannel.CHANNEL_NAME)
            .setMethodCallHandler(SmsChannel(this))
        MethodChannel(messenger, CallLogChannel.CHANNEL_NAME)
            .setMethodCallHandler(CallLogChannel(this))
        MethodChannel(messenger, BluetoothChannel.CHANNEL_NAME)
            .setMethodCallHandler(BluetoothChannel(this))
        MethodChannel(messenger, AlarmChannel.CHANNEL_NAME)
            .setMethodCallHandler(AlarmChannel(this))
        MethodChannel(messenger, AppLauncherChannel.CHANNEL_NAME)
            .setMethodCallHandler(AppLauncherChannel(this))
        MethodChannel(messenger, DeviceInfoChannel.CHANNEL_NAME)
            .setMethodCallHandler(DeviceInfoChannel(this))
        MethodChannel(messenger, NotificationListenerChannel.CHANNEL_NAME)
            .setMethodCallHandler(NotificationListenerChannel(this))
        MethodChannel(messenger, UsageStatsChannel.CHANNEL_NAME)
            .setMethodCallHandler(UsageStatsChannel(this))
        MethodChannel(messenger, AccessibilityChannel.CHANNEL_NAME)
            .setMethodCallHandler(AccessibilityChannel(this))
        MethodChannel(messenger, PhoneDialChannel.CHANNEL_NAME)
            .setMethodCallHandler(PhoneDialChannel(this))
        MethodChannel(messenger, EmailChannel.CHANNEL_NAME)
            .setMethodCallHandler(EmailChannel(this))
        MethodChannel(messenger, MapsChannel.CHANNEL_NAME)
            .setMethodCallHandler(MapsChannel(this))
        MethodChannel(messenger, SharingChannel.CHANNEL_NAME)
            .setMethodCallHandler(SharingChannel(this))
        MethodChannel(messenger, AudioChannel.CHANNEL_NAME)
            .setMethodCallHandler(AudioChannel(this))
        MethodChannel(messenger, WifiChannel.CHANNEL_NAME)
            .setMethodCallHandler(WifiChannel(this))
        MethodChannel(messenger, SensorChannel.CHANNEL_NAME)
            .setMethodCallHandler(SensorChannel(this))
        filesChannel = FilesChannel(this)
        MethodChannel(messenger, FilesChannel.CHANNEL_NAME)
            .setMethodCallHandler(filesChannel)
        MethodChannel(messenger, NfcChannel.CHANNEL_NAME)
            .setMethodCallHandler(NfcChannel(this))
        val geofenceCh = MethodChannel(messenger, GeofenceChannel.CHANNEL_NAME)
        geofenceCh.setMethodCallHandler(GeofenceChannel(this))
        GeofenceChannel.setChannel(geofenceCh)
        MethodChannel(messenger, PermissionsChannel.CHANNEL_NAME)
            .setMethodCallHandler(PermissionsChannel(this))

        MethodChannel(messenger, "ferri/service").setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val count = call.argument<Int>("channel_count") ?: 0
                    val cronCount = call.argument<Int>("cron_job_count") ?: 0
                    FerriService.start(this, count, cronCount)
                    result.success(null)
                }
                "stopService" -> {
                    FerriService.stop(this)
                    result.success(null)
                }
                "updateNotification" -> {
                    val count = call.argument<Int>("channel_count") ?: 0
                    val cronCount = call.argument<Int>("cron_job_count") ?: 0
                    FerriService.updateNotification(this, count, cronCount)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        filesChannel?.onActivityResult(requestCode, resultCode, data)
    }
}
