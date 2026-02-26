/// Device info capability — provides tools for querying device hardware,
/// battery, storage, connectivity, and controlling flashlight/brightness.
///
/// Channel: `ferri/device_info`
/// Kotlin handler: `DeviceInfoChannel.kt`
///
/// Tools:
/// - `device_info` — Get device model, OS version, and hardware details
/// - `device_battery` — Get battery level and charging status
/// - `device_storage` — Get internal storage usage
/// - `device_connectivity` — Get network connectivity status
/// - `device_flashlight` — Toggle the device flashlight on/off
/// - `device_brightness` — Set the screen brightness level
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Handles device information queries via Kotlin MethodChannel.
class DeviceInfoChannel {
  static const _channel = MethodChannel('ferri/device_info');

  DeviceInfoChannel._();

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[DeviceInfoChannel] handleToolCall: $toolName');

    switch (toolName) {
      case 'device_info':
        return _getDeviceInfo();
      case 'device_battery':
        return _getBattery();
      case 'device_storage':
        return _getStorage();
      case 'device_connectivity':
        return _getConnectivity();
      case 'device_flashlight':
        return _setFlashlight(params);
      case 'device_brightness':
        return _setBrightness(params);
      default:
        throw Exception('Unknown device info tool: $toolName');
    }
  }

  static Future<String> _getDeviceInfo() async {
    final result = await _channel.invokeMethod('getDeviceInfo');
    return result as String;
  }

  static Future<String> _getBattery() async {
    final result = await _channel.invokeMethod('getBattery');
    return result as String;
  }

  static Future<String> _getStorage() async {
    final result = await _channel.invokeMethod('getStorage');
    return result as String;
  }

  static Future<String> _getConnectivity() async {
    final result = await _channel.invokeMethod('getConnectivity');
    return result as String;
  }

  static Future<String> _setFlashlight(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod('setFlashlight', {
      'enabled': params['enabled'] ?? true,
    });
    return result as String;
  }

  static Future<String> _setBrightness(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod('setBrightness', {
      'level': params['level'],
    });
    return result as String;
  }
}
