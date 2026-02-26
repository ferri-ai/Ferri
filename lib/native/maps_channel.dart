/// Maps capability — provides tools for opening map locations and
/// launching turn-by-turn navigation.
///
/// Channel: `ferri/maps`
/// Kotlin handler: `MapsChannel.kt`
///
/// Tools:
/// - `maps_open` — Open a location in the maps app by query or coordinates
/// - `maps_navigate` — Launch navigation to a destination
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart wrapper around MethodChannel('ferri/maps').
class MapsChannel {
  static const _channel = MethodChannel('ferri/maps');
  MapsChannel._();

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[MapsChannel] handleToolCall: $toolName');
    switch (toolName) {
      case 'maps_open':
        return _open(params);
      case 'maps_navigate':
        return _navigate(params);
      default:
        throw PlatformException(
          code: 'UNKNOWN_TOOL',
          message: 'Unknown maps tool: $toolName',
        );
    }
  }

  static Future<String> _open(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('open', {
      if (params['query'] != null) 'query': params['query'],
      if (params['latitude'] != null) 'latitude': params['latitude'],
      if (params['longitude'] != null) 'longitude': params['longitude'],
    });
    return result ?? jsonEncode({'error': 'No result'});
  }

  static Future<String> _navigate(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('navigate', {
      'destination': params['destination'],
      'mode': params['mode'] ?? 'driving',
    });
    return result ?? jsonEncode({'error': 'No result'});
  }
}
