/// App launcher capability — provides tools for launching installed apps
/// and listing available applications.
///
/// Channel: `ferri/app_launcher`
/// Kotlin handler: `AppLauncherChannel.kt`
///
/// Tools:
/// - `app_launch` — Launch an app by package name or app name
/// - `app_list` — List installed apps, optionally filtered by query
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Handles app launching via Kotlin MethodChannel.
class AppLauncherChannel {
  static const _channel = MethodChannel('ferri/app_launcher');

  AppLauncherChannel._();

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[AppLauncherChannel] handleToolCall: $toolName');

    switch (toolName) {
      case 'app_launch':
        return _launchApp(params);
      case 'app_list':
        return _listApps(params);
      default:
        throw Exception('Unknown app launcher tool: $toolName');
    }
  }

  static Future<String> _launchApp(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod('launchApp', {
      if (params.containsKey('package_name'))
        'package_name': params['package_name'],
      if (params.containsKey('app_name'))
        'app_name': params['app_name'],
    });
    return result as String;
  }

  static Future<String> _listApps(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod('listApps', {
      if (params.containsKey('query')) 'query': params['query'],
      'limit': params['limit'] ?? 30,
    });
    return result as String;
  }
}
