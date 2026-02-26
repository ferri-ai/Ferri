/// Notification listener capability — provides tools for reading notifications
/// posted by other apps via the NotificationListenerService.
///
/// Channel: `ferri/notification_listener`
/// Kotlin handler: `NotificationListenerChannel.kt`
///
/// Tools:
/// - `notification_listener_read` — Read captured notifications with optional filters
/// - `notification_listener_active` — List currently active (uncleared) notifications
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NotificationListenerChannel {
  static const _channel = MethodChannel('ferri/notification_listener');

  NotificationListenerChannel._();

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[NotificationListenerChannel] handleToolCall: $toolName');

    switch (toolName) {
      case 'notification_listener_read':
        return _readNotifications(params);
      case 'notification_listener_active':
        return _activeNotifications();
      default:
        throw PlatformException(
          code: 'UNKNOWN_TOOL',
          message: 'Unknown notification listener tool: $toolName',
        );
    }
  }

  static Future<String> _readNotifications(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('readNotifications', {
      if (params['package'] != null) 'package': params['package'] as String,
      if (params['limit'] != null) 'limit': params['limit'] as int,
      if (params['after_date'] != null)
        'after_date': params['after_date'] as String,
    });
    return result ?? '[]';
  }

  static Future<String> _activeNotifications() async {
    final result = await _channel.invokeMethod<String>('activeNotifications');
    return result ?? '[]';
  }
}
