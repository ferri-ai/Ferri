/// Calendar capability — provides tools for reading and writing calendar events.
///
/// Channel: `ferri/calendar`
/// Kotlin handler: `CalendarChannel.kt`
///
/// Tools:
/// - `calendar_read_events` — Query events by date range
/// - `calendar_create_event` — Create a new calendar event
/// - `calendar_update_event` — Update an existing event
/// - `calendar_delete_event` — Delete an event by ID
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart wrapper around the MethodChannel('ferri/calendar').
/// Translates Go tool call params into MethodChannel invocations
/// and returns JSON string results.
class CalendarChannel {
  static const _channel = MethodChannel('ferri/calendar');

  CalendarChannel._();

  /// Route a tool call to the appropriate MethodChannel method.
  /// Returns a JSON string result suitable for sending back to Go.
  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[CalendarChannel] handleToolCall: $toolName');

    switch (toolName) {
      case 'calendar_read_events':
        return _readEvents(params);
      case 'calendar_create_event':
        return _createEvent(params);
      case 'calendar_update_event':
        return _updateEvent(params);
      case 'calendar_delete_event':
        return _deleteEvent(params);
      default:
        throw PlatformException(
          code: 'UNKNOWN_TOOL',
          message: 'Unknown calendar tool: $toolName',
        );
    }
  }

  static Future<String> _readEvents(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('readEvents', {
      'start_date': params['start_date'] as String,
      'end_date': params['end_date'] as String,
      if (params['calendar_id'] != null)
        'calendar_id': params['calendar_id'] as String,
    });
    return result ?? '[]';
  }

  static Future<String> _createEvent(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('createEvent', {
      'title': params['title'] as String,
      'start_time': params['start_time'] as String,
      'end_time': params['end_time'] as String,
      if (params['location'] != null)
        'location': params['location'] as String,
      if (params['description'] != null)
        'description': params['description'] as String,
      if (params['calendar_id'] != null)
        'calendar_id': params['calendar_id'] as String,
    });
    return result ?? jsonEncode({'event_id': -1, 'error': 'No result'});
  }

  static Future<String> _updateEvent(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('updateEvent', {
      'event_id': params['event_id'] as String,
      if (params['title'] != null) 'title': params['title'] as String,
      if (params['start_time'] != null)
        'start_time': params['start_time'] as String,
      if (params['end_time'] != null)
        'end_time': params['end_time'] as String,
      if (params['location'] != null)
        'location': params['location'] as String,
      if (params['description'] != null)
        'description': params['description'] as String,
    });
    return result ?? jsonEncode({'error': 'No result'});
  }

  static Future<String> _deleteEvent(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('deleteEvent', {
      'event_id': params['event_id'] as String,
    });
    return result ?? jsonEncode({'error': 'No result'});
  }
}
