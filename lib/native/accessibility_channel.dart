/// Accessibility capability — provides tools for reading screen content
/// and performing UI interactions via the accessibility service.
///
/// Channel: `ferri/accessibility`
/// Kotlin handler: `AccessibilityChannel.kt`
///
/// Tools:
/// - `accessibility_read_screen` — Read the current screen's UI tree
/// - `accessibility_tap` — Tap an element by text label or coordinates
/// - `accessibility_scroll` — Scroll the screen in a given direction
/// - `accessibility_type` — Type text into an input field
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AccessibilityChannel {
  static const _channel = MethodChannel('ferri/accessibility');

  AccessibilityChannel._();

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[AccessibilityChannel] handleToolCall: $toolName');

    switch (toolName) {
      case 'accessibility_read_screen':
        return _readScreen();
      case 'accessibility_tap':
        return _tap(params);
      case 'accessibility_scroll':
        return _scroll(params);
      case 'accessibility_type':
        return _typeText(params);
      default:
        throw PlatformException(
          code: 'UNKNOWN_TOOL',
          message: 'Unknown accessibility tool: $toolName',
        );
    }
  }

  static Future<bool> isServiceEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isServiceEnabled');
      return result ?? false;
    } catch (e) {
      debugPrint('[AccessibilityChannel] isServiceEnabled error: $e');
      return false;
    }
  }

  static Future<String> _readScreen() async {
    final result = await _channel.invokeMethod<String>('readScreen');
    return result ?? '{"error": "No result"}';
  }

  static Future<String> _tap(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('tap', {
      if (params['text'] != null) 'text': params['text'] as String,
      if (params['x'] != null) 'x': (params['x'] as num).toDouble(),
      if (params['y'] != null) 'y': (params['y'] as num).toDouble(),
    });
    return result ?? '{"error": "No result"}';
  }

  static Future<String> _scroll(Map<String, dynamic> params) async {
    final direction = params['direction'] as String? ?? 'down';
    final result = await _channel.invokeMethod<String>('scroll', {
      'direction': direction,
    });
    return result ?? '{"error": "No result"}';
  }

  static Future<String> _typeText(Map<String, dynamic> params) async {
    final text = params['text'] as String? ?? '';
    final result = await _channel.invokeMethod<String>('typeText', {
      'text': text,
      if (params['field_label'] != null)
        'field_label': params['field_label'] as String,
    });
    return result ?? '{"error": "No result"}';
  }
}
