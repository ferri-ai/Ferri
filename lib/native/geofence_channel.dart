/// Geofence capability — provides tools for creating, listing, and removing
/// geographic fences that trigger when the device enters/exits an area.
///
/// Channel: `ferri/geofence`
/// Kotlin handler: `GeofenceChannel.kt`
///
/// Tools:
/// - `geofence_create` — Create a geofence by coordinates or location name
/// - `geofence_list` — List all active geofences
/// - `geofence_remove` — Remove a geofence by ID
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../providers/engine_provider.dart';
import 'location_channel.dart';

/// Geofence capability using Google Play Services GeofencingClient.
///
/// Supports creating geofences by lat/lng OR by location name.
/// When a location_name is provided instead of coordinates, the channel
/// automatically geocodes it via LocationChannel before creating the fence.
class GeofenceChannel {
  static const _channel = MethodChannel('ferri/geofence');
  GeofenceChannel._();

  /// Set up a MethodCallHandler to receive incoming "trigger" calls from
  /// native Kotlin (fired by GeofenceBroadcastReceiver when GMS detects
  /// a geofence transition).
  static void init(EngineNotifier engine) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'trigger') {
        final id = call.arguments['id'] as String?;
        final transition = call.arguments['transition'] as String?;
        debugPrint('[GeofenceChannel] trigger received: id=$id transition=$transition');
        if (id != null && id.isNotEmpty) {
          engine.triggerGeofence(id);
        }
      }
    });
    debugPrint('[GeofenceChannel] init: listening for trigger calls');
  }

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[GeofenceChannel] handleToolCall: $toolName');
    switch (toolName) {
      case 'geofence_create':
        return _create(params);
      case 'geofence_list':
        return _invoke('list', {});
      case 'geofence_remove':
        return _invoke('remove', params);
      default:
        throw PlatformException(
          code: 'UNKNOWN_TOOL',
          message: 'Unknown geofence tool: $toolName',
        );
    }
  }

  /// Geocode a location name to coordinates (if needed) then create the
  /// native GMS fence. Exposed for use by automation_provider.
  static Future<String> createNativeFence(Map<String, dynamic> params) async {
    return _create(params);
  }

  static Future<String> _create(Map<String, dynamic> params) async {
    // If location_name provided but no coordinates, geocode first
    if (params['latitude'] == null && params['location_name'] != null) {
      final geocodeResult = await LocationChannel.handleToolCall(
        'location_geocode',
        {'address': params['location_name']},
      );
      final decoded = jsonDecode(geocodeResult);
      if (decoded is Map && decoded.containsKey('results')) {
        final results = decoded['results'] as List?;
        if (results != null && results.isNotEmpty) {
          params = Map<String, dynamic>.from(params);
          params['latitude'] = results[0]['latitude'];
          params['longitude'] = results[0]['longitude'];
        } else {
          return jsonEncode({
            'error': 'geocode_failed',
            'message': 'Could not find coordinates for: ${params['location_name']}',
          });
        }
      } else if (decoded is List && decoded.isNotEmpty) {
        params = Map<String, dynamic>.from(params);
        params['latitude'] = decoded[0]['latitude'];
        params['longitude'] = decoded[0]['longitude'];
      } else {
        return jsonEncode({
          'error': 'geocode_failed',
          'message': 'Could not find coordinates for: ${params['location_name']}',
        });
      }
    }

    return _invoke('create', params);
  }

  static Future<String> _invoke(String method, Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>(method, params);
    return result ?? jsonEncode({'error': 'No result'});
  }
}
