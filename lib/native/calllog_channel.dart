/// Call log capability — provides tools for reading call history and
/// generating call summaries.
///
/// Channel: `ferri/calllog`
/// Kotlin handler: `CalllogChannel.kt`
///
/// Tools:
/// - `calllog_read` — Read call log entries with optional filters
/// - `calllog_summary` — Get a summary of recent call activity
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart wrapper around MethodChannel('ferri/calllog').
class CallLogChannel {
  static const _channel = MethodChannel('ferri/calllog');

  CallLogChannel._();

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[CallLogChannel] handleToolCall: $toolName');

    switch (toolName) {
      case 'calllog_read':
        return _readCalls(params);
      case 'calllog_summary':
        return _summarizeCalls(params);
      default:
        throw PlatformException(
          code: 'UNKNOWN_TOOL',
          message: 'Unknown call log tool: $toolName',
        );
    }
  }

  static Future<String> _readCalls(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('readCalls', {
      if (params['number'] != null) 'number': params['number'] as String,
      if (params['limit'] != null) 'limit': params['limit'] as int,
      if (params['type'] != null) 'type': params['type'] as String,
      if (params['after_date'] != null)
        'after_date': params['after_date'] as String,
    });
    return result ?? '[]';
  }

  static Future<String> _summarizeCalls(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('summarizeCalls', {
      if (params['days'] != null) 'days': params['days'] as int,
    });
    return result ?? jsonEncode({'error': 'No result'});
  }
}
