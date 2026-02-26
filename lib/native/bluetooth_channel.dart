/// Bluetooth capability — provides tools for querying Bluetooth state,
/// listing paired devices, and scanning for nearby devices.
///
/// Channel: `ferri/bluetooth`
/// Kotlin handler: `BluetoothChannel.kt`
///
/// Tools:
/// - `bluetooth_get_state` — Get current Bluetooth adapter state
/// - `bluetooth_list_paired` — List paired/bonded Bluetooth devices
/// - `bluetooth_scan` — Scan for nearby Bluetooth devices
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart wrapper around MethodChannel('ferri/bluetooth').
class BluetoothChannel {
  static const _channel = MethodChannel('ferri/bluetooth');

  BluetoothChannel._();

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[BluetoothChannel] handleToolCall: $toolName');

    switch (toolName) {
      case 'bluetooth_get_state':
        return _getState();
      case 'bluetooth_list_paired':
        return _listPaired();
      case 'bluetooth_scan':
        return _scan(params);
      default:
        throw PlatformException(
          code: 'UNKNOWN_TOOL',
          message: 'Unknown Bluetooth tool: $toolName',
        );
    }
  }

  static Future<String> _getState() async {
    final result = await _channel.invokeMethod<String>('getState');
    return result ?? jsonEncode({'error': 'No result'});
  }

  static Future<String> _listPaired() async {
    final result = await _channel.invokeMethod<String>('listPaired');
    return result ?? '[]';
  }

  static Future<String> _scan(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('scan', {
      if (params['duration_ms'] != null)
        'duration_ms': params['duration_ms'] as int,
    });
    return result ?? jsonEncode({'error': 'No result'});
  }
}
