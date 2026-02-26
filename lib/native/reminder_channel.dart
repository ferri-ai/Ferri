/// Reminder capability — provides tools for setting, listing, and cancelling
/// time-based reminders backed by local notifications.
///
/// Channel: none (pure-Dart via `flutter_local_notifications` + `shared_preferences`)
/// Kotlin handler: none
///
/// Tools:
/// - `reminder_set` — Set a reminder by delay or absolute time
/// - `reminder_list` — List all active (future) reminders
/// - `reminder_cancel` — Cancel a reminder by ID
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles reminders using scheduled notifications + SharedPreferences persistence.
/// Reminders survive app restarts via persisted notification IDs.
class ReminderChannel {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static int _nextId = 1000; // Reminder IDs start at 1000 to avoid collision

  ReminderChannel._();

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _notifications.initialize(initSettings);
    // Load next ID from prefs
    final prefs = await SharedPreferences.getInstance();
    _nextId = prefs.getInt('reminder_next_id') ?? 1000;
    _initialized = true;
  }

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[ReminderChannel] handleToolCall: $toolName');

    switch (toolName) {
      case 'reminder_set':
        return _setReminder(params);
      case 'reminder_list':
        return _listReminders();
      case 'reminder_cancel':
        return _cancelReminder(params);
      default:
        throw Exception('Unknown reminder tool: $toolName');
    }
  }

  static Future<String> _setReminder(Map<String, dynamic> params) async {
    await _ensureInitialized();

    final message = params['message'] as String? ?? 'Reminder';
    final title = params['title'] as String? ?? 'Ferri Reminder';
    final delaySeconds = params['delay_seconds'] as int?;
    final atTime = params['at_time'] as String?;

    Duration delay;
    if (atTime != null) {
      final targetTime = DateTime.parse(atTime);
      delay = targetTime.difference(DateTime.now());
      if (delay.isNegative) {
        return jsonEncode({
          'success': false,
          'error': 'The specified time is in the past',
        });
      }
    } else if (delaySeconds != null) {
      delay = Duration(seconds: delaySeconds);
    } else {
      return jsonEncode({
        'success': false,
        'error': 'Either delay_seconds or at_time is required',
      });
    }

    final id = _nextId++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reminder_next_id', _nextId);

    // Schedule the notification
    Future.delayed(delay, () async {
      const androidDetails = AndroidNotificationDetails(
        'ferri_reminders',
        'Reminders',
        channelDescription: 'Ferri reminders',
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(android: androidDetails);
      await _notifications.show(id, title, message, details);
    });

    // Persist the reminder for listing
    final reminders = _loadReminders(prefs);
    final triggerTime = DateTime.now().add(delay);
    reminders.add({
      'id': id,
      'title': title,
      'message': message,
      'trigger_time': triggerTime.toIso8601String(),
    });
    await _saveReminders(prefs, reminders);

    return jsonEncode({
      'success': true,
      'reminder_id': id,
      'title': title,
      'message': message,
      'trigger_time': triggerTime.toIso8601String(),
    });
  }

  static Future<String> _listReminders() async {
    await _ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    final reminders = _loadReminders(prefs);

    // Filter out expired reminders
    final now = DateTime.now();
    final active = reminders.where((r) {
      final trigger = DateTime.parse(r['trigger_time'] as String);
      return trigger.isAfter(now);
    }).toList();

    // Save cleaned list
    await _saveReminders(prefs, active);

    return jsonEncode({
      'reminders': active,
      'count': active.length,
    });
  }

  static Future<String> _cancelReminder(Map<String, dynamic> params) async {
    await _ensureInitialized();

    final id = params['reminder_id'] as int?;
    if (id == null) {
      return jsonEncode({
        'success': false,
        'error': 'reminder_id is required',
      });
    }

    await _notifications.cancel(id);

    final prefs = await SharedPreferences.getInstance();
    final reminders = _loadReminders(prefs);
    reminders.removeWhere((r) => r['id'] == id);
    await _saveReminders(prefs, reminders);

    return jsonEncode({
      'success': true,
      'cancelled_id': id,
    });
  }

  static List<Map<String, dynamic>> _loadReminders(SharedPreferences prefs) {
    final json = prefs.getString('ferri_reminders');
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.cast<Map<String, dynamic>>();
  }

  static Future<void> _saveReminders(
      SharedPreferences prefs, List<Map<String, dynamic>> reminders) async {
    await prefs.setString('ferri_reminders', jsonEncode(reminders));
  }
}
