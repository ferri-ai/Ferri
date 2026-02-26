import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shows notifications for automation results (cron jobs, heartbeats).
///
/// Uses a dedicated Android notification channel ('ferri_automations') so users
/// can independently control notification importance for automations vs. agent
/// notifications.  IDs start at 2000 to avoid collisions with
/// NotificationChannel (agent) IDs.
///
/// Pending results are persisted to SharedPreferences so they survive app
/// restarts and can be shown in the chat when the app opens.
class AutomationNotifications {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static int _nextId = 2000; // 2000+ range for automation notifications

  /// Callback invoked when the user taps an automation notification.
  /// The String is the full automation result content.
  static void Function(String content)? onNotificationTapped;

  static const _pendingKey = 'pending_automation_results';

  AutomationNotifications._();

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onTap,
    );
    _initialized = true;
  }

  /// Handle notification tap — extract payload and forward to callback.
  static void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty && onNotificationTapped != null) {
      onNotificationTapped!(payload);
    }
  }

  /// Show a notification for an automation result and persist it for later.
  static Future<void> showResult({
    required String title,
    required String body,
    required String fullContent,
  }) async {
    await ensureInitialized();

    // Persist so the result can be shown in chat when app opens
    await _addPending(fullContent);

    const androidDetails = AndroidNotificationDetails(
      'ferri_automations',
      'Automations',
      channelDescription: 'Results from scheduled automations and briefings',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(_nextId++, title, body, details, payload: fullContent);
  }

  /// Persist a pending automation result to SharedPreferences.
  static Future<void> _addPending(String content) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_pendingKey) ?? [];
      final entry = jsonEncode({
        'content': content,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
      existing.add(entry);
      await prefs.setStringList(_pendingKey, existing);
    } catch (e) {
      debugPrint('[AutomationNotifications] persist error: $e');
    }
  }

  /// Retrieve and clear all pending automation results.
  /// Call on app resume to flush queued results into the chat.
  static Future<List<({String content, DateTime ranAt})>>
      drainPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_pendingKey);
      if (raw == null || raw.isEmpty) return [];

      await prefs.remove(_pendingKey);

      final results = <({String content, DateTime ranAt})>[];
      for (final entry in raw) {
        try {
          final map = jsonDecode(entry) as Map<String, dynamic>;
          results.add((
            content: map['content'] as String,
            ranAt: DateTime.fromMillisecondsSinceEpoch(map['ts'] as int),
          ));
        } catch (_) {
          // Skip malformed entries
        }
      }
      return results;
    } catch (e) {
      debugPrint('[AutomationNotifications] drain error: $e');
      return [];
    }
  }
}
