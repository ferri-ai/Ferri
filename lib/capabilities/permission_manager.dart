import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Wraps permission_handler for runtime permission requests.
/// Maps Android permission name strings to permission_handler's Permission enum.
class PermissionManager {
  PermissionManager._();

  /// Request all permissions for a capability. Returns true if ALL granted.
  static Future<bool> requestPermissions(List<String> permissions) async {
    final permObjects = permissions
        .map(_mapPermission)
        .whereType<Permission>()
        .toList();

    if (permObjects.isEmpty) return true;

    final statuses = await permObjects.request();
    final allGranted = statuses.values.every((s) => s.isGranted);

    if (!allGranted) {
      debugPrint('[PermissionManager] Not all permissions granted: $statuses');
    }

    return allGranted;
  }

  /// Check if all permissions are currently granted.
  static Future<bool> checkPermissions(List<String> permissions) async {
    final permObjects = permissions
        .map(_mapPermission)
        .whereType<Permission>()
        .toList();

    if (permObjects.isEmpty) return true;

    for (final perm in permObjects) {
      if (!await perm.isGranted) return false;
    }
    return true;
  }

  /// Maps Android permission strings to permission_handler's Permission enum.
  static Permission? _mapPermission(String androidPermission) {
    switch (androidPermission) {
      case 'android.permission.READ_CALENDAR':
        return Permission.calendarFullAccess;
      case 'android.permission.WRITE_CALENDAR':
        return Permission.calendarWriteOnly;
      case 'android.permission.READ_CONTACTS':
      case 'android.permission.WRITE_CONTACTS':
        return Permission.contacts;
      case 'android.permission.ACCESS_FINE_LOCATION':
        return Permission.locationWhenInUse;
      case 'android.permission.ACCESS_COARSE_LOCATION':
        return Permission.locationWhenInUse;
      case 'android.permission.CAMERA':
        return Permission.camera;
      case 'android.permission.RECORD_AUDIO':
        return Permission.microphone;
      case 'android.permission.POST_NOTIFICATIONS':
        return Permission.notification;
      case 'android.permission.ACTIVITY_RECOGNITION':
        return Permission.activityRecognition;
      case 'android.permission.READ_SMS':
      case 'android.permission.SEND_SMS':
        return Permission.sms;
      case 'android.permission.READ_CALL_LOG':
        return Permission.phone;
      case 'android.permission.BLUETOOTH_SCAN':
        return Permission.bluetoothScan;
      case 'android.permission.BLUETOOTH_CONNECT':
        return Permission.bluetoothConnect;
      default:
        debugPrint(
            '[PermissionManager] Unknown permission: $androidPermission');
        return null;
    }
  }
}
