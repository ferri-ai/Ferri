import 'package:flutter/services.dart';

/// Controls the Android Foreground Service for background channel processing.
class ServiceChannel {
  static const _channel = MethodChannel('ferri/service');

  static Future<void> startService({
    int channelCount = 0,
    int cronJobCount = 0,
  }) async {
    await _channel.invokeMethod('startService', {
      'channel_count': channelCount,
      'cron_job_count': cronJobCount,
    });
  }

  static Future<void> stopService() async {
    await _channel.invokeMethod('stopService');
  }

  static Future<void> updateNotification({
    int channelCount = 0,
    int cronJobCount = 0,
  }) async {
    await _channel.invokeMethod('updateNotification', {
      'channel_count': channelCount,
      'cron_job_count': cronJobCount,
    });
  }
}
