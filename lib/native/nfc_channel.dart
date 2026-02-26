/// NFC capability — provides tools for reading and writing NFC tags.
///
/// Channel: `ferri/nfc`
/// Kotlin handler: `NfcChannel.kt`
///
/// Tools:
/// - `nfc_read` — Read data from an NFC tag
/// - `nfc_write` — Write data to an NFC tag
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart wrapper around MethodChannel('ferri/nfc').
class NfcChannel {
  static const _channel = MethodChannel('ferri/nfc');
  NfcChannel._();

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[NfcChannel] handleToolCall: $toolName');
    switch (toolName) {
      case 'nfc_read':
        return _invoke('readTag', {});
      case 'nfc_write':
        return _invoke('writeTag', params);
      default:
        throw PlatformException(
          code: 'UNKNOWN_TOOL',
          message: 'Unknown NFC tool: $toolName',
        );
    }
  }

  static Future<String> _invoke(String method, Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>(method, params);
    return result ?? jsonEncode({'error': 'No result'});
  }
}
