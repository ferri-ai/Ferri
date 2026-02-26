/// SMS capability — provides tools for reading and sending text messages.
///
/// Channel: `ferri/sms`
/// Kotlin handler: `SmsChannel.kt`
///
/// Tools:
/// - `sms_read` — Read SMS messages, optionally filtered by address/type
/// - `sms_send` — Send an SMS message to a phone number
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart wrapper around MethodChannel('ferri/sms').
class SmsChannel {
  static const _channel = MethodChannel('ferri/sms');

  SmsChannel._();

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[SmsChannel] handleToolCall: $toolName');

    switch (toolName) {
      case 'sms_read':
        return _readMessages(params);
      case 'sms_send':
        return _sendMessage(params);
      default:
        throw PlatformException(
          code: 'UNKNOWN_TOOL',
          message: 'Unknown SMS tool: $toolName',
        );
    }
  }

  static Future<String> _readMessages(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('readMessages', {
      if (params['address'] != null) 'address': params['address'] as String,
      if (params['limit'] != null) 'limit': params['limit'] as int,
      if (params['type'] != null) 'type': params['type'] as String,
    });
    return result ?? '[]';
  }

  static Future<String> _sendMessage(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('sendMessage', {
      'to': params['to'] as String,
      'body': params['body'] as String,
    });
    return result ?? jsonEncode({'error': 'No result'});
  }
}
