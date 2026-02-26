package com.ferri.ferri

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.GeofencingEvent
import com.google.android.gms.location.Geofence
import com.ferri.ferri.channels.GeofenceChannel

/**
 * Receives geofence transition events from GeofencingClient.
 * Fires the linked automation job via the Go engine.
 *
 * GMS NOTE: This receiver requires Google Play Services. It will never fire
 * on devices without GMS (e.g., LineageOS without microG, Huawei AppGallery devices).
 */
class GeofenceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) {
            Log.e("GeofenceReceiver", "Geofence error: ${event.errorCode}")
            return
        }

        val transition = when (event.geofenceTransition) {
            Geofence.GEOFENCE_TRANSITION_ENTER -> "enter"
            Geofence.GEOFENCE_TRANSITION_EXIT -> "exit"
            Geofence.GEOFENCE_TRANSITION_DWELL -> "dwell"
            else -> return
        }

        for (geofence in event.triggeringGeofences ?: emptyList()) {
            val fenceId = geofence.requestId
            if (fenceId.isNullOrEmpty()) {
                Log.w("GeofenceReceiver", "Skipping transition '$transition' — empty fence ID")
                continue
            }
            Log.i("GeofenceReceiver", "Transition '$transition' for fence '$fenceId'")
            GeofenceChannel.triggerGeofence(fenceId, transition)
        }
    }
}
