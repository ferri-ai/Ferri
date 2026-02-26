/// Sensor capability — provides tools for listing available hardware sensors
/// and reading their current values.
///
/// Channel: `ferri/sensors`
/// Kotlin handler: `SensorChannel.kt`
///
/// Tools:
/// - `sensor_list` — List all available hardware sensors on the device
/// - `sensor_read` — Read the current value of a specific sensor
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart wrapper around MethodChannel('ferri/sensors').
class SensorChannel {
  static const _channel = MethodChannel('ferri/sensors');
  SensorChannel._();

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[SensorChannel] handleToolCall: $toolName');
    switch (toolName) {
      case 'sensor_list':
        return _invoke('listSensors', {});
      case 'sensor_read':
        return _invoke('readSensor', params);
      default:
        throw PlatformException(
          code: 'UNKNOWN_TOOL',
          message: 'Unknown sensor tool: $toolName',
        );
    }
  }

  static Future<String> _invoke(String method, Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>(method, params);
    return result ?? jsonEncode({'error': 'No result'});
  }
}
