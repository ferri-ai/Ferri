/// Audio capability — provides tools for controlling volume, audio mode,
/// and media playback.
///
/// Channel: `ferri/audio`
/// Kotlin handler: `AudioChannel.kt`
///
/// Tools:
/// - `audio_get_volume` — Get current volume levels
/// - `audio_set_volume` — Set volume for a specific stream
/// - `audio_get_mode` — Get current audio mode (normal/silent/vibrate)
/// - `audio_set_mode` — Set audio mode
/// - `audio_media_control` — Control media playback (play/pause/next/prev)
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart wrapper around MethodChannel('ferri/audio').
class AudioChannel {
  static const _channel = MethodChannel('ferri/audio');
  AudioChannel._();

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[AudioChannel] handleToolCall: $toolName');
    switch (toolName) {
      case 'audio_get_volume':
        return _invoke('getVolume', {});
      case 'audio_set_volume':
        return _invoke('setVolume', params);
      case 'audio_get_mode':
        return _invoke('getMode', {});
      case 'audio_set_mode':
        return _invoke('setMode', params);
      case 'audio_media_control':
        return _invoke('mediaControl', params);
      default:
        throw PlatformException(
          code: 'UNKNOWN_TOOL',
          message: 'Unknown audio tool: $toolName',
        );
    }
  }

  static Future<String> _invoke(String method, Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>(method, params);
    return result ?? jsonEncode({'error': 'No result'});
  }
}
