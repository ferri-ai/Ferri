/// Alarm capability — provides tools for setting alarms, timers, and
/// viewing existing alarms via system AlarmClock intents.
///
/// Channel: `ferri/alarms`
/// Kotlin handler: `AlarmChannel.kt`
///
/// Tools:
/// - `alarm_set` — Set an alarm for a specific hour and minute
/// - `alarm_set_timer` — Set a countdown timer in seconds
/// - `alarm_show` — Open the system alarm/clock app
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Handles alarm operations via system AlarmClock intents.
class AlarmChannel {
  static const _channel = MethodChannel('ferri/alarms');

  AlarmChannel._();

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[AlarmChannel] handleToolCall: $toolName');

    switch (toolName) {
      case 'alarm_set':
        return _setAlarm(params);
      case 'alarm_set_timer':
        return _setTimer(params);
      case 'alarm_show':
        return _showAlarms();
      default:
        throw Exception('Unknown alarm tool: $toolName');
    }
  }

  static Future<String> _setAlarm(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod('setAlarm', {
      'hour': params['hour'],
      'minute': params['minute'],
      'message': params['message'] ?? '',
      'skip_ui': params['skip_ui'] ?? true,
    });
    return result as String;
  }

  static Future<String> _setTimer(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod('setTimer', {
      'seconds': params['seconds'],
      'message': params['message'] ?? 'Ferri Timer',
      'skip_ui': params['skip_ui'] ?? true,
    });
    return result as String;
  }

  static Future<String> _showAlarms() async {
    final result = await _channel.invokeMethod('showAlarms');
    return result as String;
  }
}
