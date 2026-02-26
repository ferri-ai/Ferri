package com.ferri.ferri.channels

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import com.ferri.ferri.GeofenceBroadcastReceiver
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * Geofencing capability using Google Play Services GeofencingClient.
 *
 * GMS NOTE: This is Ferri's only Google Play Services dependency.
 * GeofencingClient was chosen over a custom solution because Android's
 * geofencing service batches location updates across all apps, making it
 * significantly more battery-efficient than polling location ourselves.
 *
 * WILL NOT WORK on devices without Google Play Services:
 * - LineageOS without microG
 * - Huawei devices with AppGallery only
 * - Amazon Fire devices
 */
class GeofenceChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL_NAME = "ferri/geofence"

        private var channel: MethodChannel? = null

        fun setChannel(ch: MethodChannel) {
            channel = ch
        }

        /**
         * Called by GeofenceBroadcastReceiver to notify Dart of a GMS transition.
         * Dart side calls engine.triggerGeofence(fenceId) to execute the automation.
         */
        fun triggerGeofence(fenceId: String, transition: String) {
            channel?.invokeMethod("trigger", mapOf("id" to fenceId, "transition" to transition))
        }
    }

    private val geofencingClient: GeofencingClient
        get() = LocationServices.getGeofencingClient(context)

    // In-memory registry of active geofences (persisted by Dart side)
    private val activeGeofences = mutableMapOf<String, JSONObject>()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "create" -> create(call, result)
            "list" -> list(result)
            "remove" -> remove(call, result)
            else -> result.notImplemented()
        }
    }

    @Suppress("MissingPermission") // Permission checked at Dart capability layer
    private fun create(call: MethodCall, result: MethodChannel.Result) {
        try {
            val id = call.argument<String>("id")
                ?: "fence_${System.currentTimeMillis()}"
            val lat = (call.argument<Any>("latitude") as? Number)?.toDouble()
                ?: return result.error("INVALID_ARGS", "latitude is required", null)
            val lng = (call.argument<Any>("longitude") as? Number)?.toDouble()
                ?: return result.error("INVALID_ARGS", "longitude is required", null)
            val radius = (call.argument<Any>("radius") as? Number)?.toDouble() ?: 100.0
            val trigger = call.argument<String>("trigger") ?: "enter"

            val transitionType = when (trigger) {
                "exit" -> Geofence.GEOFENCE_TRANSITION_EXIT
                "dwell" -> Geofence.GEOFENCE_TRANSITION_DWELL
                else -> Geofence.GEOFENCE_TRANSITION_ENTER
            }

            val geofence = Geofence.Builder()
                .setRequestId(id)
                .setCircularRegion(lat, lng, radius.toFloat())
                .setExpirationDuration(Geofence.NEVER_EXPIRE)
                .setTransitionTypes(transitionType)
                .apply {
                    if (trigger == "dwell") setLoiteringDelay(30000)
                }
                .build()

            val request = GeofencingRequest.Builder()
                .setInitialTrigger(0) // No initial trigger — wait for real GPS transitions
                .addGeofence(geofence)
                .build()

            Log.i("GeofenceChannel", "Adding GMS fence: id=$id lat=$lat lng=$lng radius=$radius trigger=$trigger")
            geofencingClient.addGeofences(request, getGeofencePendingIntent())
                .addOnSuccessListener {
                    Log.i("GeofenceChannel", "GMS fence created successfully: id=$id")
                    activeGeofences[id] = JSONObject().apply {
                        put("id", id)
                        put("latitude", lat)
                        put("longitude", lng)
                        put("radius", radius)
                        put("trigger", trigger)
                    }
                    result.success(JSONObject().apply {
                        put("success", true)
                        put("id", id)
                        put("latitude", lat)
                        put("longitude", lng)
                        put("radius", radius)
                        put("trigger", trigger)
                    }.toString())
                }
                .addOnFailureListener { e ->
                    Log.e("GeofenceChannel", "GMS fence creation failed: id=$id error=${e.message}")
                    result.error("GEOFENCE_ERROR", "Failed to create geofence", e.message)
                }
        } catch (e: Exception) {
            result.error("GEOFENCE_ERROR", "Failed to create geofence", e.message)
        }
    }

    private fun list(result: MethodChannel.Result) {
        val arr = JSONArray()
        for ((_, fence) in activeGeofences) {
            arr.put(fence)
        }
        result.success(JSONObject().apply {
            put("geofences", arr)
            put("count", arr.length())
        }.toString())
    }

    private fun remove(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
            ?: return result.error("INVALID_ARGS", "id is required", null)

        Log.i("GeofenceChannel", "Removing GMS fence: id=$id")
        geofencingClient.removeGeofences(listOf(id))
            .addOnSuccessListener {
                Log.i("GeofenceChannel", "GMS fence removed successfully: id=$id")
                activeGeofences.remove(id)
                result.success(JSONObject().apply {
                    put("success", true)
                    put("removed_id", id)
                }.toString())
            }
            .addOnFailureListener { e ->
                Log.e("GeofenceChannel", "GMS fence removal failed: id=$id error=${e.message}")
                result.error("GEOFENCE_ERROR", "Failed to remove geofence", e.message)
            }
    }

    private fun getGeofencePendingIntent(): PendingIntent {
        val intent = Intent(context, GeofenceBroadcastReceiver::class.java)
        return PendingIntent.getBroadcast(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
    }
}
