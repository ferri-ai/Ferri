import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

class TokenMessage {
  final String type; // "token", "done", "error"
  final String content;
  final String sessionId;

  TokenMessage({
    required this.type,
    required this.content,
    required this.sessionId,
  });

  factory TokenMessage.fromJson(Map<String, dynamic> json) {
    return TokenMessage(
      type: json['type'] as String,
      content: json['content'] as String,
      sessionId: json['session_id'] as String,
    );
  }

  bool get isDone => type == 'done';
  bool get isError => type == 'error';
  bool get isToken => type == 'token';
}

class TokenStream {
  final ReceivePort _receivePort = ReceivePort();
  void Function(TokenMessage)? onToken;

  int get port => _receivePort.sendPort.nativePort;

  void listen({required void Function(TokenMessage) onToken}) {
    this.onToken = onToken;
    _receivePort.listen((dynamic message) {
      if (message is String) {
        try {
          final json = jsonDecode(message) as Map<String, dynamic>;
          final tokenMsg = TokenMessage.fromJson(json);
          debugPrint('[TokenStream] received: type=${tokenMsg.type} len=${tokenMsg.content.length}');
          // Use the field (not the captured parameter) so the callback
          // can be swapped at runtime without re-subscribing.
          this.onToken?.call(tokenMsg);
        } catch (e) {
          debugPrint('[TokenStream] parse error: $e');
        }
      } else {
        debugPrint('[TokenStream] non-string message: ${message.runtimeType}');
      }
    });
  }

  void dispose() {
    _receivePort.close();
  }
}
