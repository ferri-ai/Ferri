package com.ferri.ferri.channels

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * Handles app launching and listing installed apps.
 */
class AppLauncherChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "ferri/app_launcher"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "launchApp" -> launchApp(call, result)
            "listApps" -> listApps(call, result)
            else -> result.notImplemented()
        }
    }

    private fun launchApp(call: MethodCall, result: MethodChannel.Result) {
        try {
            val packageName = call.argument<String>("package_name")
            val appName = call.argument<String>("app_name")

            if (packageName == null && appName == null) {
                return result.error("INVALID_ARGS", "package_name or app_name is required", null)
            }

            // If package name given, launch directly
            if (packageName != null) {
                val intent = context.packageManager.getLaunchIntentForPackage(packageName)
                if (intent != null) {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    val response = JSONObject().apply {
                        put("launched", true)
                        put("package_name", packageName)
                    }
                    return result.success(response.toString())
                } else {
                    return result.error("NOT_FOUND", "App not found: $packageName", null)
                }
            }

            // Search by app name
            val pm = context.packageManager
            val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
            }
            val apps = pm.queryIntentActivities(mainIntent, 0)
            val searchName = appName!!.lowercase()

            // Find best match
            val match = apps.firstOrNull {
                it.loadLabel(pm).toString().lowercase() == searchName
            } ?: apps.firstOrNull {
                it.loadLabel(pm).toString().lowercase().contains(searchName)
            }

            if (match != null) {
                val pkg = match.activityInfo.packageName
                val intent = pm.getLaunchIntentForPackage(pkg)
                if (intent != null) {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    val response = JSONObject().apply {
                        put("launched", true)
                        put("app_name", match.loadLabel(pm).toString())
                        put("package_name", pkg)
                    }
                    result.success(response.toString())
                } else {
                    result.error("LAUNCH_FAILED", "Cannot launch ${match.loadLabel(pm)}", null)
                }
            } else {
                result.error("NOT_FOUND", "No app found matching: $appName", null)
            }
        } catch (e: Exception) {
            result.error("LAUNCH_ERROR", "Failed to launch app", e.message)
        }
    }

    private fun listApps(call: MethodCall, result: MethodChannel.Result) {
        try {
            val query = call.argument<String>("query")?.lowercase()
            val limit = call.argument<Int>("limit") ?: 30

            val pm = context.packageManager
            val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
            }
            val apps = pm.queryIntentActivities(mainIntent, 0)

            val filtered = if (query != null) {
                apps.filter { it.loadLabel(pm).toString().lowercase().contains(query) }
            } else {
                apps
            }

            val sorted = filtered
                .sortedBy { it.loadLabel(pm).toString().lowercase() }
                .take(limit)

            val jsonApps = JSONArray()
            for (app in sorted) {
                val obj = JSONObject().apply {
                    put("name", app.loadLabel(pm).toString())
                    put("package_name", app.activityInfo.packageName)
                }
                jsonApps.put(obj)
            }

            val response = JSONObject().apply {
                put("apps", jsonApps)
                put("count", jsonApps.length())
                put("total_installed", apps.size)
            }
            result.success(response.toString())
        } catch (e: Exception) {
            result.error("LIST_ERROR", "Failed to list apps", e.message)
        }
    }
}
