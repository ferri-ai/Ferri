/// Location capability — provides tools for getting current location,
/// geocoding addresses, and reverse-geocoding coordinates.
///
/// Channel: `ferri/location`
/// Kotlin handler: `LocationChannel.kt`
///
/// Tools:
/// - `location_get_current` — Get the device's current GPS location
/// - `location_geocode` — Convert an address string to coordinates
/// - `location_reverse_geocode` — Convert coordinates to an address
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart wrapper around MethodChannel('ferri/location').
class LocationChannel {
  static const _channel = MethodChannel('ferri/location');

  LocationChannel._();

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[LocationChannel] handleToolCall: $toolName');

    switch (toolName) {
      case 'location_get_current':
        return _getCurrentLocation();
      case 'location_geocode':
        return _geocode(params);
      case 'location_reverse_geocode':
        return _reverseGeocode(params);
      default:
        throw PlatformException(
          code: 'UNKNOWN_TOOL',
          message: 'Unknown location tool: $toolName',
        );
    }
  }

  static Future<String> _getCurrentLocation() async {
    final result = await _channel.invokeMethod<String>('getCurrentLocation');
    return result ?? jsonEncode({'error': 'No result'});
  }

  static Future<String> _geocode(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('geocode', {
      'address': params['address'] as String,
      if (params['max_results'] != null)
        'max_results': params['max_results'] as int,
    });
    return result ?? '[]';
  }

  static Future<String> _reverseGeocode(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('reverseGeocode', {
      'latitude': params['latitude'] as double,
      'longitude': params['longitude'] as double,
    });
    return result ?? jsonEncode({'error': 'No result'});
  }
}
