/// Clipboard capability — provides tools for reading from and writing to
/// the system clipboard.
///
/// Channel: none (pure-Dart via Flutter's `Clipboard` API)
/// Kotlin handler: none
///
/// Tools:
/// - `clipboard_read` — Read the current clipboard text
/// - `clipboard_write` — Write text to the clipboard
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Handles clipboard operations. Pure Dart — no MethodChannel needed.
class ClipboardChannel {
  ClipboardChannel._();

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[ClipboardChannel] handleToolCall: $toolName');

    switch (toolName) {
      case 'clipboard_read':
        return _readClipboard();
      case 'clipboard_write':
        return _writeClipboard(params);
      default:
        throw Exception('Unknown clipboard tool: $toolName');
    }
  }

  static Future<String> _readClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;

    if (text == null || text.isEmpty) {
      return jsonEncode({
        'has_text': false,
        'text': '',
        'message': 'Clipboard is empty',
      });
    }

    return jsonEncode({
      'has_text': true,
      'text': text,
      'length': text.length,
    });
  }

  static Future<String> _writeClipboard(Map<String, dynamic> params) async {
    final text = params['text'] as String?;
    if (text == null || text.isEmpty) {
      return jsonEncode({
        'success': false,
        'error': 'text is required',
      });
    }

    await Clipboard.setData(ClipboardData(text: text));

    return jsonEncode({
      'success': true,
      'length': text.length,
      'message': 'Text copied to clipboard',
    });
  }
}
