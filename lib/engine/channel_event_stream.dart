import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

/// Represents a channel event from the Go engine.
class ChannelEvent {
  final String type; // "channel_message", "channel_response", "channel_status"
  final String channel;
  final Map<String, dynamic> data;

  ChannelEvent({
    required this.type,
    required this.channel,
    required this.data,
  });

  factory ChannelEvent.fromJson(Map<String, dynamic> json) {
    return ChannelEvent(
      type: json['type'] as String,
      channel: (json['channel'] as String?) ?? '',
      data: json,
    );
  }

  String? get sender => data['sender'] as String?;
  String? get chatId => data['chat_id'] as String?;
  String? get content => data['content'] as String?;
  String? get status => data['status'] as String?;
  String? get error => data['error'] as String?;
}

/// Listens on a NativePort for channel events from the Go engine.
class ChannelEventStream {
  final ReceivePort _receivePort = ReceivePort();
  void Function(ChannelEvent)? onEvent;

  int get port => _receivePort.sendPort.nativePort;

  void listen({required void Function(ChannelEvent) onEvent}) {
    this.onEvent = onEvent;
    _receivePort.listen((dynamic message) {
      if (message is String) {
        try {
          final json = jsonDecode(message) as Map<String, dynamic>;
          final event = ChannelEvent.fromJson(json);
          debugPrint(
              '[ChannelEventStream] ${event.type}: ${event.channel}');
          this.onEvent?.call(event);
        } catch (e) {
          debugPrint('[ChannelEventStream] parse error: $e');
        }
      }
    });
  }

  void dispose() {
    _receivePort.close();
  }
}
