package com.ferri.ferri.channels

import android.app.AppOpsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class PermissionsChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "ferri/permissions"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkNotificationListener" -> checkNotificationListener(result)
            "checkUsageStats" -> checkUsageStats(result)
            "checkAccessibilityService" -> checkAccessibilityService(result)
            "openSettings" -> openSettings(call, result)
            else -> result.notImplemented()
        }
    }

    private fun checkNotificationListener(result: MethodChannel.Result) {
        try {
            val flat = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners"
            ) ?: ""
            val myComponent = ComponentName(context, context.packageName + ".services.FerriNotificationListenerService")
            val enabled = flat.contains(myComponent.flattenToString())
            result.success(enabled)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun checkUsageStats(result: MethodChannel.Result) {
        try {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName
            )
            result.success(mode == AppOpsManager.MODE_ALLOWED)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun checkAccessibilityService(result: MethodChannel.Result) {
        try {
            val flat = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: ""
            val myComponent = ComponentName(
                context,
                context.packageName + ".services.FerriAccessibilityService"
            )
            val enabled = flat.contains(myComponent.flattenToString())
            result.success(enabled)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun openSettings(call: MethodCall, result: MethodChannel.Result) {
        try {
            val action = call.argument<String>("action")
                ?: return result.error("INVALID_ARGS", "action is required", null)
            val intent = Intent(action).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("SETTINGS_ERROR", "Failed to open settings", e.message)
        }
    }
}
