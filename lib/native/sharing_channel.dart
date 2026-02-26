/// Sharing capability — provides tools for sharing text and files via
/// the Android share sheet.
///
/// Channel: `ferri/sharing`
/// Kotlin handler: `SharingChannel.kt`
///
/// Tools:
/// - `share_text` — Share text content via the system share sheet
/// - `share_file` — Share a file via the system share sheet
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart wrapper around MethodChannel('ferri/sharing').
class SharingChannel {
  static const _channel = MethodChannel('ferri/sharing');
  SharingChannel._();

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[SharingChannel] handleToolCall: $toolName');
    switch (toolName) {
      case 'share_text':
        return _shareText(params);
      case 'share_file':
        return _shareFile(params);
      default:
        throw PlatformException(
          code: 'UNKNOWN_TOOL',
          message: 'Unknown sharing tool: $toolName',
        );
    }
  }

  static Future<String> _shareText(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('shareText', {
      'text': params['text'],
      if (params['subject'] != null) 'subject': params['subject'],
    });
    return result ?? jsonEncode({'error': 'No result'});
  }

  static Future<String> _shareFile(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('shareFile', {
      'path': params['path'],
      'mime_type': params['mime_type'] ?? '*/*',
    });
    return result ?? jsonEncode({'error': 'No result'});
  }
}
