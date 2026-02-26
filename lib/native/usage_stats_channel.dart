/// Usage stats capability — provides tools for querying app usage data
/// and identifying the currently active app.
///
/// Channel: `ferri/usage_stats`
/// Kotlin handler: `UsageStatsChannel.kt`
///
/// Tools:
/// - `usage_stats_query` — Query app usage statistics over a period
/// - `usage_stats_current` — Get the currently foreground app
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class UsageStatsChannel {
  static const _channel = MethodChannel('ferri/usage_stats');

  UsageStatsChannel._();

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[UsageStatsChannel] handleToolCall: $toolName');

    switch (toolName) {
      case 'usage_stats_query':
        return _queryStats(params);
      case 'usage_stats_current':
        return _currentApp();
      default:
        throw PlatformException(
          code: 'UNKNOWN_TOOL',
          message: 'Unknown usage stats tool: $toolName',
        );
    }
  }

  static Future<String> _queryStats(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('queryStats', {
      if (params['days'] != null) 'days': params['days'] as int,
      if (params['limit'] != null) 'limit': params['limit'] as int,
    });
    return result ?? '[]';
  }

  static Future<String> _currentApp() async {
    final result = await _channel.invokeMethod<String>('currentApp');
    return result ?? '{}';
  }
}
