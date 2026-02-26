import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../providers/chat_provider.dart';

/// Append-only JSONL file for persistent chat history.
///
/// Independent of the Go engine's session files — never touched by
/// Go's TruncateHistory. Only deleted by explicit "Clear Chat."
class ChatLogService {
  final String _dirPath;
  File? _file;

  ChatLogService(this._dirPath);

  File get _logFile => _file ??= File('$_dirPath/chat_log.jsonl');

  /// Append a single message as one JSON line.
  void append(ChatMessage message) {
    try {
      final line = jsonEncode(message.toJson());
      _logFile.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('[ChatLogService] append error: $e');
    }
  }

  /// Load all messages from the JSONL file.
  /// Skips malformed lines gracefully.
  List<ChatMessage> loadAll() {
    try {
      if (!_logFile.existsSync()) return [];
      final lines = _logFile.readAsLinesSync();
      final messages = <ChatMessage>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          messages.add(ChatMessage.fromJson(json));
        } catch (e) {
          debugPrint('[ChatLogService] skipping malformed line: $e');
        }
      }
      return messages;
    } catch (e) {
      debugPrint('[ChatLogService] loadAll error: $e');
      return [];
    }
  }

  /// Check if a log file exists and has content.
  bool hasLog() {
    try {
      return _logFile.existsSync() && _logFile.lengthSync() > 0;
    } catch (e) {
      return false;
    }
  }

  /// Delete the log file entirely.
  void clear() {
    try {
      if (_logFile.existsSync()) {
        _logFile.deleteSync();
      }
    } catch (e) {
      debugPrint('[ChatLogService] clear error: $e');
    }
  }
}
