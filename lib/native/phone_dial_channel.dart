/// Phone dial capability — provides tools for initiating phone calls
/// via the system dialer.
///
/// Channel: `ferri/phone`
/// Kotlin handler: `PhoneDialChannel.kt`
///
/// Tools:
/// - `phone_dial` — Dial a phone number (opens dialer or calls directly)
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart wrapper around MethodChannel('ferri/phone').
class PhoneDialChannel {
  static const _channel = MethodChannel('ferri/phone');
  PhoneDialChannel._();

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[PhoneDialChannel] handleToolCall: $toolName');
    switch (toolName) {
      case 'phone_dial':
        return _dial(params);
      default:
        throw PlatformException(
          code: 'UNKNOWN_TOOL',
          message: 'Unknown phone tool: $toolName',
        );
    }
  }

  static Future<String> _dial(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('dial', {
      'number': params['number'],
      'direct': params['direct'] ?? false,
    });
    return result ?? jsonEncode({'error': 'No result'});
  }
}
