import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Handles privileged permission checks via platform channel.
class PermissionsChannel {
  static const _channel = MethodChannel('ferri/permissions');

  PermissionsChannel._();

  static Future<bool> checkNotificationListener() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkNotificationListener');
      return result ?? false;
    } catch (e) {
      debugPrint('[PermissionsChannel] checkNotificationListener error: $e');
      return false;
    }
  }

  static Future<bool> checkUsageStats() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkUsageStats');
      return result ?? false;
    } catch (e) {
      debugPrint('[PermissionsChannel] checkUsageStats error: $e');
      return false;
    }
  }

  static Future<bool> checkAccessibilityService() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkAccessibilityService');
      return result ?? false;
    } catch (e) {
      debugPrint('[PermissionsChannel] checkAccessibilityService error: $e');
      return false;
    }
  }

  static Future<bool> openSettings(String action) async {
    try {
      final result = await _channel.invokeMethod<bool>('openSettings', {
        'action': action,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('[PermissionsChannel] openSettings error: $e');
      return false;
    }
  }
}
