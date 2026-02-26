package com.ferri.ferri.channels

import android.annotation.SuppressLint
import android.content.Context
import android.location.Address
import android.location.Geocoder
import android.location.Location
import android.location.LocationManager
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale

/**
 * Handles location operations using Android's LocationManager + Geocoder.
 * No external dependencies — uses only the Android SDK.
 */
class LocationChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "ferri/location"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getCurrentLocation" -> getCurrentLocation(result)
            "geocode" -> geocode(call, result)
            "reverseGeocode" -> reverseGeocode(call, result)
            else -> result.notImplemented()
        }
    }

    @SuppressLint("MissingPermission")
    private fun getCurrentLocation(result: MethodChannel.Result) {
        try {
            val locationManager = context.getSystemService(Context.LOCATION_SERVICE)
                as? LocationManager
                ?: return result.error("UNAVAILABLE", "LocationManager not available", null)

            // Try GPS first, then network
            var location: Location? = null
            if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                location = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
            }
            if (location == null && locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                location = locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
            }

            if (location == null) {
                return result.error("NO_LOCATION", "Could not determine current location. Ensure location services are enabled.", null)
            }

            val response = JSONObject().apply {
                put("latitude", location.latitude)
                put("longitude", location.longitude)
                put("accuracy", location.accuracy.toDouble())
                put("altitude", location.altitude)
                put("provider", location.provider ?: "unknown")
                put("timestamp", location.time)
            }
            result.success(response.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Location permission not granted", e.message)
        } catch (e: Exception) {
            result.error("LOCATION_ERROR", "Failed to get location", e.message)
        }
    }

    private fun geocode(call: MethodCall, result: MethodChannel.Result) {
        try {
            val address = call.argument<String>("address")
                ?: return result.error("INVALID_ARGS", "address is required", null)
            val maxResults = call.argument<Int>("max_results") ?: 5

            if (!Geocoder.isPresent()) {
                return result.error("UNAVAILABLE", "Geocoder is not available on this device", null)
            }

            val geocoder = Geocoder(context, Locale.getDefault())
            val results = JSONArray()

            @Suppress("DEPRECATION")
            val addresses: List<Address> = geocoder.getFromLocationName(address, maxResults) ?: emptyList()

            for (addr in addresses) {
                val item = JSONObject().apply {
                    put("latitude", addr.latitude)
                    put("longitude", addr.longitude)
                    put("address", addr.getAddressLine(0) ?: "")
                    put("city", addr.locality ?: "")
                    put("state", addr.adminArea ?: "")
                    put("country", addr.countryName ?: "")
                    put("postal_code", addr.postalCode ?: "")
                }
                results.put(item)
            }

            result.success(results.toString())
        } catch (e: Exception) {
            result.error("GEOCODE_ERROR", "Failed to geocode address", e.message)
        }
    }

    private fun reverseGeocode(call: MethodCall, result: MethodChannel.Result) {
        try {
            val latitude = (call.argument<Any>("latitude") as? Number)?.toDouble()
                ?: return result.error("INVALID_ARGS", "latitude is required", null)
            val longitude = (call.argument<Any>("longitude") as? Number)?.toDouble()
                ?: return result.error("INVALID_ARGS", "longitude is required", null)

            if (!Geocoder.isPresent()) {
                return result.error("UNAVAILABLE", "Geocoder is not available on this device", null)
            }

            val geocoder = Geocoder(context, Locale.getDefault())

            @Suppress("DEPRECATION")
            val addresses: List<Address> = geocoder.getFromLocation(latitude, longitude, 1) ?: emptyList()

            if (addresses.isEmpty()) {
                return result.error("NOT_FOUND", "No address found for coordinates", null)
            }

            val addr = addresses[0]
            val response = JSONObject().apply {
                put("address", addr.getAddressLine(0) ?: "")
                put("city", addr.locality ?: "")
                put("state", addr.adminArea ?: "")
                put("country", addr.countryName ?: "")
                put("postal_code", addr.postalCode ?: "")
                put("latitude", latitude)
                put("longitude", longitude)
            }
            result.success(response.toString())
        } catch (e: Exception) {
            result.error("REVERSE_GEOCODE_ERROR", "Failed to reverse geocode", e.message)
        }
    }
}
