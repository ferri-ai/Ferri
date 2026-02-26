/// Notification capability — provides tools for sending and scheduling
/// local notifications.
///
/// Channel: none (pure-Dart via `flutter_local_notifications`)
/// Kotlin handler: none
///
/// Tools:
/// - `notification_send` — Show an immediate local notification
/// - `notification_schedule` — Schedule a notification after a delay
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles notifications using flutter_local_notifications.
/// No Kotlin MethodChannel needed — this is a pure-Dart capability.
class NotificationChannel {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  NotificationChannel._();

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[NotificationChannel] handleToolCall: $toolName');
    await _ensureInitialized();

    switch (toolName) {
      case 'notification_send':
        return _sendNotification(params);
      case 'notification_schedule':
        return _scheduleNotification(params);
      default:
        throw Exception('Unknown notification tool: $toolName');
    }
  }

  static Future<String> _sendNotification(Map<String, dynamic> params) async {
    final title = params['title'] as String? ?? 'Ferri';
    final body = params['body'] as String? ?? '';
    final id = params['id'] as int? ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

    const androidDetails = AndroidNotificationDetails(
      'ferri_agent',
      'Ferri Agent',
      channelDescription: 'Notifications from Ferri AI agent',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(id, title, body, details);

    return jsonEncode({
      'notification_id': id,
      'title': title,
      'body': body,
      'sent': true,
    });
  }

  static Future<String> _scheduleNotification(
      Map<String, dynamic> params) async {
    // For now, schedule is a simple delayed send — can be extended with
    // flutter_local_notifications' zonedSchedule later.
    final title = params['title'] as String? ?? 'Ferri';
    final body = params['body'] as String? ?? '';
    final delaySeconds = params['delay_seconds'] as int? ?? 60;
    final id = params['id'] as int? ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Use a simple Future.delayed for basic scheduling
    Future.delayed(Duration(seconds: delaySeconds), () async {
      const androidDetails = AndroidNotificationDetails(
        'ferri_agent',
        'Ferri Agent',
        channelDescription: 'Notifications from Ferri AI agent',
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(android: androidDetails);
      await _plugin.show(id, title, body, details);
    });

    return jsonEncode({
      'notification_id': id,
      'title': title,
      'body': body,
      'scheduled': true,
      'delay_seconds': delaySeconds,
    });
  }
}
