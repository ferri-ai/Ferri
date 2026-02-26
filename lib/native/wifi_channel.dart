/// Wi-Fi capability — provides tools for querying Wi-Fi connection info,
/// scanning for nearby networks, and checking Wi-Fi state.
///
/// Channel: `ferri/wifi`
/// Kotlin handler: `WifiChannel.kt`
///
/// Tools:
/// - `wifi_get_info` — Get current Wi-Fi connection details (SSID, IP, etc.)
/// - `wifi_scan` — Scan for nearby Wi-Fi networks
/// - `wifi_get_state` — Get Wi-Fi adapter enabled/disabled state
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart wrapper around MethodChannel('ferri/wifi').
class WifiChannel {
  static const _channel = MethodChannel('ferri/wifi');
  WifiChannel._();

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[WifiChannel] handleToolCall: $toolName');
    switch (toolName) {
      case 'wifi_get_info':
        return _invoke('getInfo');
      case 'wifi_scan':
        return _invoke('scan');
      case 'wifi_get_state':
        return _invoke('getState');
      default:
        throw PlatformException(
          code: 'UNKNOWN_TOOL',
          message: 'Unknown wifi tool: $toolName',
        );
    }
  }

  static Future<String> _invoke(String method) async {
    final result = await _channel.invokeMethod<String>(method);
    return result ?? jsonEncode({'error': 'No result'});
  }
}
