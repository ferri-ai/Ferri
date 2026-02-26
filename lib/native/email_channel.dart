/// Email capability — provides tools for composing emails via an intent
/// to the user's default email client.
///
/// Channel: `ferri/email`
/// Kotlin handler: `EmailChannel.kt`
///
/// Tools:
/// - `email_compose` — Compose a new email with to, cc, subject, and body
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart wrapper around MethodChannel('ferri/email').
class EmailChannel {
  static const _channel = MethodChannel('ferri/email');
  EmailChannel._();

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[EmailChannel] handleToolCall: $toolName');
    switch (toolName) {
      case 'email_compose':
        return _compose(params);
      default:
        throw PlatformException(
          code: 'UNKNOWN_TOOL',
          message: 'Unknown email tool: $toolName',
        );
    }
  }

  static Future<String> _compose(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('compose', {
      'to': params['to'] ?? '',
      'cc': params['cc'] ?? '',
      'subject': params['subject'] ?? '',
      'body': params['body'] ?? '',
    });
    return result ?? jsonEncode({'error': 'No result'});
  }
}
