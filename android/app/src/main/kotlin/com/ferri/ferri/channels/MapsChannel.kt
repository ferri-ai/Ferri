package com.ferri.ferri.channels

import android.content.Context
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Handles maps and navigation via geo: and google.navigation: URI intents.
 */
class MapsChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL_NAME = "ferri/maps"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> open(call, result)
            "navigate" -> navigate(call, result)
            else -> result.notImplemented()
        }
    }

    private fun open(call: MethodCall, result: MethodChannel.Result) {
        try {
            val query = call.argument<String>("query")
            val lat = (call.argument<Any>("latitude") as? Number)?.toDouble()
            val lng = (call.argument<Any>("longitude") as? Number)?.toDouble()

            val uri = when {
                query != null -> Uri.parse("geo:0,0?q=${Uri.encode(query)}")
                lat != null && lng != null -> Uri.parse("geo:$lat,$lng")
                else -> return result.error("INVALID_ARGS", "query or latitude/longitude required", null)
            }

            val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)

            result.success(JSONObject().apply {
                put("success", true)
                put("uri", uri.toString())
            }.toString())
        } catch (e: android.content.ActivityNotFoundException) {
            result.error("NO_MAPS_APP", "No maps app available on this device", e.message)
        } catch (e: Exception) {
            result.error("MAPS_ERROR", "Failed to open maps", e.message)
        }
    }

    private fun navigate(call: MethodCall, result: MethodChannel.Result) {
        try {
            val destination = call.argument<String>("destination")
                ?: return result.error("INVALID_ARGS", "destination is required", null)
            val mode = call.argument<String>("mode") ?: "d"

            val modeChar = when (mode) {
                "walking", "w" -> "w"
                "bicycling", "b" -> "b"
                "transit", "t" -> "r"
                else -> "d"
            }

            val uri = Uri.parse("google.navigation:q=${Uri.encode(destination)}&mode=$modeChar")
            val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                setPackage("com.google.android.apps.maps")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            // Fallback if Google Maps not installed
            if (intent.resolveActivity(context.packageManager) == null) {
                val fallback = Intent(Intent.ACTION_VIEW,
                    Uri.parse("geo:0,0?q=${Uri.encode(destination)}")).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(fallback)
            } else {
                context.startActivity(intent)
            }

            result.success(JSONObject().apply {
                put("success", true)
                put("destination", destination)
                put("mode", modeChar)
            }.toString())
        } catch (e: android.content.ActivityNotFoundException) {
            result.error("NO_MAPS_APP", "No maps app available on this device", e.message)
        } catch (e: Exception) {
            result.error("NAV_ERROR", "Failed to start navigation", e.message)
        }
    }
}
