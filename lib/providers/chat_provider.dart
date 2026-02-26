import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/token_stream.dart';
import '../screens/chat/widgets/tool_call_card.dart';
import '../services/chat_log_service.dart';

enum AgentStatus { idle, thinking, streaming }

/// Metadata for an automation result shown in the chat.
class AutomationResultInfo {
  final String content;
  final DateTime ranAt;

  const AutomationResultInfo({
    required this.content,
    required this.ranAt,
  });

  Map<String, dynamic> toJson() => {
    'content': content,
    'ran_at': ranAt.millisecondsSinceEpoch,
  };

  factory AutomationResultInfo.fromJson(Map<String, dynamic> json) =>
      AutomationResultInfo(
        content: json['content'] as String? ?? '',
        ranAt: DateTime.fromMillisecondsSinceEpoch(json['ran_at'] as int? ?? 0),
      );
}

class ChatMessage {
  final String role; // 'user', 'assistant', 'tool_call', or 'automation'
  final String content;
  final DateTime timestamp;
  final ToolCallInfo? toolCall;
  final AutomationResultInfo? automationResult;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.toolCall,
    this.automationResult,
  });

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'timestamp': timestamp.millisecondsSinceEpoch,
    if (toolCall != null) 'tool_call': toolCall!.toJson(),
    if (automationResult != null)
      'automation_result': automationResult!.toJson(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    role: json['role'] as String? ?? 'assistant',
    content: json['content'] as String? ?? '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      json['timestamp'] as int? ?? 0,
    ),
    toolCall: json['tool_call'] != null
        ? ToolCallInfo.fromJson(json['tool_call'] as Map<String, dynamic>)
        : null,
    automationResult: json['automation_result'] != null
        ? AutomationResultInfo.fromJson(
            json['automation_result'] as Map<String, dynamic>)
        : null,
  );

  ChatMessage copyWith({
    String? role,
    String? content,
    DateTime? timestamp,
    ToolCallInfo? Function()? toolCall,
    AutomationResultInfo? Function()? automationResult,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      toolCall: toolCall != null ? toolCall() : this.toolCall,
      automationResult: automationResult != null
          ? automationResult()
          : this.automationResult,
    );
  }

  bool get isToolCall => role == 'tool_call';
  bool get isAutomation => role == 'automation';
}

class ChatState {
  final List<ChatMessage> messages;
  final ChatMessage? streamingMessage;
  final AgentStatus status;
  final List<ChatMessage> _fullHistory;
  final bool hasMore;

  const ChatState({
    this.messages = const [],
    this.streamingMessage,
    this.status = AgentStatus.idle,
    List<ChatMessage> fullHistory = const [],
    this.hasMore = false,
  }) : _fullHistory = fullHistory;

  ChatState copyWith({
    List<ChatMessage>? messages,
    ChatMessage? Function()? streamingMessage,
    AgentStatus? status,
    List<ChatMessage>? fullHistory,
    bool? hasMore,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      streamingMessage:
          streamingMessage != null ? streamingMessage() : this.streamingMessage,
      status: status ?? this.status,
      fullHistory: fullHistory ?? this._fullHistory,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatLogService? _chatLog;

  ChatNotifier({ChatLogService? chatLog})
      : _chatLog = chatLog,
        super(const ChatState());

  /// Add a user message and set status to thinking.
  void addUserMessage(String content) {
    final message = ChatMessage(
      role: 'user',
      content: content,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, message],
      fullHistory: [...state._fullHistory, message],
      status: AgentStatus.thinking,
    );
    _chatLog?.append(message);
  }

  /// Add an assistant message directly (e.g. from cron/automation results).
  void addAssistantMessage(String content) {
    final message = ChatMessage(
      role: 'assistant',
      content: content,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, message],
      fullHistory: [...state._fullHistory, message],
    );
    _chatLog?.append(message);
  }

  /// Add an automation result card to the chat.
  void addAutomationResult(String content, {DateTime? ranAt}) {
    final ts = ranAt ?? DateTime.now();
    final message = ChatMessage(
      role: 'automation',
      content: content,
      timestamp: ts,
      automationResult: AutomationResultInfo(content: content, ranAt: ts),
    );
    state = state.copyWith(
      messages: [...state.messages, message],
      fullHistory: [...state._fullHistory, message],
      streamingMessage: () => null,
      status: AgentStatus.idle,
    );
    _chatLog?.append(message);
  }

  /// Handle token callbacks from the Go engine.
  void onToken(TokenMessage token) {
    debugPrint('[ChatNotifier] onToken: type=${token.type} status=${state.status} contentLen=${token.content.length}');
    if (token.isToken) {
      if (state.status == AgentStatus.thinking) {
        // First token: create a new streaming message
        final streamingMsg = ChatMessage(
          role: 'assistant',
          content: token.content,
          timestamp: DateTime.now(),
        );
        state = state.copyWith(
          streamingMessage: () => streamingMsg,
          status: AgentStatus.streaming,
        );
      } else if (state.status == AgentStatus.streaming &&
          state.streamingMessage != null) {
        // Subsequent tokens: append to existing streaming message
        final updated = state.streamingMessage!.copyWith(
          content: state.streamingMessage!.content + token.content,
        );
        state = state.copyWith(
          streamingMessage: () => updated,
        );
      }
    } else if (token.type == 'tool_event') {
      _handleToolEvent(token.content);
    } else if (token.isDone) {
      // Finalize: use accumulated streaming content (bridge sends response
      // as a "token" message, then "done" with empty content).
      final content = state.streamingMessage?.content ?? token.content;
      if (content.isNotEmpty) {
        final finalMessage = ChatMessage(
          role: 'assistant',
          content: content,
          timestamp: DateTime.now(),
        );
        state = state.copyWith(
          messages: [...state.messages, finalMessage],
          fullHistory: [...state._fullHistory, finalMessage],
          streamingMessage: () => null,
          status: AgentStatus.idle,
        );
        _chatLog?.append(finalMessage);
      } else {
        // Done with no content — just reset state
        state = state.copyWith(
          streamingMessage: () => null,
          status: AgentStatus.idle,
        );
      }
    } else if (token.isError) {
      final errorMessage = ChatMessage(
        role: 'assistant',
        content: _friendlyError(token.content),
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, errorMessage],
        streamingMessage: () => null,
        status: AgentStatus.idle,
      );
    }
  }

  /// Convert raw Go engine errors into user-friendly messages.
  static String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    // Network / DNS errors
    if (lower.contains('no such host') ||
        lower.contains('dial tcp') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable') ||
        lower.contains('no route to host')) {
      return "Can't reach your LLM provider — check your internet connection.";
    }
    // Timeout
    if (lower.contains('timeout') || lower.contains('deadline exceeded')) {
      return 'Request timed out — your LLM provider may be slow or unreachable.';
    }
    // TLS / certificate
    if (lower.contains('certificate') || lower.contains('tls')) {
      return 'Secure connection failed — check your network (VPN, proxy, or captive portal).';
    }
    // EOF / connection reset
    if (lower.contains('eof') || lower.contains('connection reset')) {
      return 'Connection dropped — try again.';
    }
    // Auth errors
    if (lower.contains('401') || lower.contains('unauthorized') || lower.contains('invalid api key')) {
      return 'Authentication failed — check your API key in Settings.';
    }
    // Rate limiting
    if (lower.contains('429') || lower.contains('rate limit')) {
      return 'Rate limited by your LLM provider — wait a moment and try again.';
    }
    // Quota / billing
    if (lower.contains('quota') || lower.contains('billing') || lower.contains('insufficient')) {
      return 'Quota or billing issue with your LLM provider — check your account.';
    }
    // Fallback: show raw error but prefix it clearly
    return 'Error: $raw';
  }

  /// Handle tool_start / tool_end events from the Go engine.
  void _handleToolEvent(String eventJson) {
    try {
      final event = jsonDecode(eventJson) as Map<String, dynamic>;
      final eventType = event['type'] as String;
      final toolName = event['tool_name'] as String;
      final params = (event['params'] as Map<String, dynamic>?) ?? {};

      if (eventType == 'tool_start') {
        // Add an in-progress tool call card
        final toolMsg = ChatMessage(
          role: 'tool_call',
          content: '',
          timestamp: DateTime.now(),
          toolCall: ToolCallInfo(
            toolName: toolName,
            params: params,
            isInProgress: true,
          ),
        );
        state = state.copyWith(
          messages: [...state.messages, toolMsg],
          status: AgentStatus.thinking,
        );
      } else if (eventType == 'tool_end') {
        // Update the last in-progress tool call with result and duration
        final result = event['result'] as String? ?? '';
        final durationMs = event['duration_ms'] as int? ?? 0;

        final completedToolCall = ToolCallInfo(
          toolName: toolName,
          params: params,
          result: result,
          duration: Duration(milliseconds: durationMs),
        );

        final messages = [...state.messages];
        for (int i = messages.length - 1; i >= 0; i--) {
          if (messages[i].isToolCall &&
              messages[i].toolCall?.toolName == toolName &&
              messages[i].toolCall?.isInProgress == true) {
            messages[i] = messages[i].copyWith(
              toolCall: () => completedToolCall,
            );
            break;
          }
        }
        state = state.copyWith(
          messages: messages,
          status: AgentStatus.thinking,
        );

        // Persist the completed tool call (not the in-progress one)
        _chatLog?.append(ChatMessage(
          role: 'tool_call',
          content: '',
          timestamp: DateTime.now(),
          toolCall: completedToolCall,
        ));
      }
    } catch (e) {
      debugPrint('[ChatNotifier] tool event parse error: $e');
    }
  }

  static const _pageSize = 30;

  /// Load persisted history from the Go engine.
  /// Reconstructs ChatMessages from Go's stored messages.
  /// Tool call messages are skipped (they're internal LLM protocol).
  void loadFromHistory(List<Map<String, dynamic>> history) {
    debugPrint('[ChatNotifier] loadFromHistory: ${history.length} raw messages');
    if (history.isEmpty) return;

    final all = <ChatMessage>[];
    for (final msg in history) {
      final role = msg['role'] as String? ?? '';
      final content = msg['content'] as String? ?? '';
      final ts = msg['ts'] as int? ?? 0;

      // Skip tool-related messages (tool calls and tool results)
      if (role == 'tool' || (msg['tool_calls'] as List?)?.isNotEmpty == true) {
        continue;
      }

      // Only show user and assistant messages
      if (role != 'user' && role != 'assistant') continue;
      if (content.isEmpty) continue;

      final timestamp = ts > 0
          ? DateTime.fromMillisecondsSinceEpoch(ts)
          : DateTime.now();

      all.add(ChatMessage(
        role: role,
        content: content,
        timestamp: timestamp,
      ));
    }

    debugPrint('[ChatNotifier] loadFromHistory: ${all.length} displayable messages (filtered from ${history.length} raw)');
    if (all.isEmpty) return;

    // Preserve any messages added during current session (e.g. user typed
    // a message that triggered engine init — their message is in state but
    // not yet in Go history).
    final currentSession = state.messages;

    // Show last _pageSize messages initially
    final visible = all.length <= _pageSize
        ? all
        : all.sublist(all.length - _pageSize);

    debugPrint('[ChatNotifier] loadFromHistory: showing ${visible.length} of ${all.length}, hasMore=${all.length > _pageSize}');
    state = state.copyWith(
      messages: [...visible, ...currentSession],
      fullHistory: [...all, ...currentSession],
      hasMore: all.length > _pageSize,
    );
  }

  /// Load persisted history from the Dart-side JSONL chat log.
  /// Includes tool call cards and automation results (unlike Go history).
  void loadFromChatLog() {
    if (_chatLog == null) return;

    final all = _chatLog.loadAll();
    debugPrint('[ChatNotifier] loadFromChatLog: ${all.length} messages');
    if (all.isEmpty) return;

    final currentSession = state.messages;
    final visible = all.length <= _pageSize
        ? all
        : all.sublist(all.length - _pageSize);

    debugPrint('[ChatNotifier] loadFromChatLog: showing ${visible.length} of ${all.length}, hasMore=${all.length > _pageSize}');
    state = state.copyWith(
      messages: [...visible, ...currentSession],
      fullHistory: [...all, ...currentSession],
      hasMore: all.length > _pageSize,
    );
  }

  /// Load more historical messages (called when user scrolls to top).
  void loadMore() {
    if (!state.hasMore) return;

    final all = state._fullHistory;
    final currentCount = state.messages.length;
    final newCount = (currentCount + _pageSize).clamp(0, all.length);

    if (newCount == currentCount) return;

    final visible = all.sublist(all.length - newCount);
    state = state.copyWith(
      messages: visible,
      hasMore: newCount < all.length,
    );
  }

  /// Clear all messages and reset state.
  void clearMessages() {
    state = const ChatState();
  }

  /// Clear all messages, reset state, and delete the JSONL log file.
  void clearAll() {
    state = const ChatState();
    _chatLog?.clear();
  }
}

final chatLogServiceProvider = Provider<ChatLogService?>((ref) => null);

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(chatLog: ref.watch(chatLogServiceProvider));
});
