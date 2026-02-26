import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../engine/token_stream.dart';
import '../../engine/tool_dispatcher.dart';
import '../../providers/chat_provider.dart';
import '../../providers/capabilities_provider.dart';
import '../../providers/engine_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/colors.dart';
import '../../widgets/tool_approval_dialog.dart';
import 'widgets/message_bubble.dart';
import 'widgets/thinking_indicator.dart';
import 'widgets/automation_result_card.dart';
import 'widgets/tool_call_card.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  bool _scrollScheduled = false;
  int _lastMessageCount = 0;
  bool _loadingMore = false;

  // Speech-to-text state
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _textBeforeListening = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize();
  }

  void _onScroll() {
    if (_scrollController.position.pixels <=
        _scrollController.position.minScrollExtent + 50) {
      final chatState = ref.read(chatProvider);
      if (chatState.hasMore && !_loadingMore) {
        _loadingMore = true;
        // Remember current max scroll extent to preserve position
        final oldMax = _scrollController.position.maxScrollExtent;
        ref.read(chatProvider.notifier).loadMore();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final newMax = _scrollController.position.maxScrollExtent;
            final offset = newMax - oldMax;
            _scrollController.jumpTo(_scrollController.offset + offset);
          }
          _loadingMore = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  void _startListening() {
    if (!_speechAvailable || _isListening) return;
    _textBeforeListening = _textController.text;
    setState(() => _isListening = true);
    _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        final prefix = _textBeforeListening.isEmpty
            ? ''
            : '$_textBeforeListening ';
        setState(() {
          _textController.text = '$prefix${result.recognizedWords}';
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
        });
      },
      listenFor: const Duration(seconds: 30),
      localeId: 'en-US',
    );
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;
    await _speech.stop();
    if (mounted) setState(() => _isListening = false);
  }

  Future<void> _sendMessage() async {
    if (_sending) return;
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _sending = true;
    try {
      _textController.clear();

      // Add user message to chat state
      ref.read(chatProvider.notifier).addUserMessage(text);
      _scrollToBottom();

      // Initialize the engine (or re-initialize if API key changed in Settings).
      // The engine provider deduplicates — skips if already running with same key.
      final settings = ref.read(settingsProvider);
      final apiKey =
          await ref.read(settingsProvider.notifier).getApiKey();
      final braveApiKey =
          await ref.read(settingsProvider.notifier).getBraveApiKey();
      if (!mounted) return;

      if (apiKey == null || apiKey.isEmpty) {
        ref.read(chatProvider.notifier).onToken(TokenMessage(
          type: 'error',
          content: 'API key not configured. Check Settings.',
          sessionId: '',
        ));
        return;
      }

      final engineNotifier = ref.read(engineProvider.notifier);
      engineNotifier.onTokenCallback =
          ref.read(chatProvider.notifier).onToken;
      engineNotifier.onApprovalRequired = _handleApprovalRequest;
      await engineNotifier.initialize(settings, apiKey,
          braveApiKey: braveApiKey);
      if (!mounted) return;

      // Register capability tools after (re-)init
      ref.read(capabilitiesProvider.notifier).registerAllEnabled();

      // Keep callback references fresh
      ref.read(engineProvider.notifier).onTokenCallback =
          ref.read(chatProvider.notifier).onToken;
      ref.read(engineProvider.notifier).onApprovalRequired =
          _handleApprovalRequest;

      // Send message to the Go engine
      ref.read(engineProvider.notifier).sendMessage(text);
      _scrollToBottom();
    } finally {
      _sending = false;
    }
  }

  /// Called by ToolDispatcher when a destructive tool needs user approval.
  /// Shows a dialog and returns true (approve) or false (deny).
  Future<bool> _handleApprovalRequest(ToolRequest request) async {
    if (!mounted) return false;
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ToolApprovalDialog(request: request),
    );
    return approved ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final isActive = chatState.status != AgentStatus.idle;

    // Auto-scroll only for new messages at the bottom (not history loads at top)
    if (chatState.messages.length != _lastMessageCount) {
      final grew = chatState.messages.length > _lastMessageCount;
      _lastMessageCount = chatState.messages.length;
      if (grew && !_loadingMore) {
        _scrollToBottom();
      }
    }
    // Auto-scroll when streaming updates arrive
    if (chatState.streamingMessage != null) {
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: FerriColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Message list
            Expanded(
              child: _buildMessageList(chatState),
            ),
            // Input bar
            _buildInputBar(isActive, chatState),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ChatState chatState) {
    final messages = chatState.messages;
    final streamingMessage = chatState.streamingMessage;
    final isThinking = chatState.status == AgentStatus.thinking;
    // "load more" indicator + messages + optional streaming bubble + optional thinking indicator
    final hasMoreIndicator = chatState.hasMore ? 1 : 0;
    final extraItems =
        (streamingMessage != null ? 1 : 0) + (isThinking ? 1 : 0);
    final totalItems = hasMoreIndicator + messages.length + extraItems;

    if (totalItems == 0) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        // "Load more" indicator at the top
        if (chatState.hasMore && index == 0) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                'Scroll up to load earlier messages',
                style: TextStyle(
                  color: FerriColors.textFaint,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }
        // Adjust index for the "load more" indicator
        final adjustedIndex = index - hasMoreIndicator;
        if (adjustedIndex < messages.length) {
          final msg = messages[adjustedIndex];
          if (msg.isToolCall && msg.toolCall != null) {
            return ToolCallCard(info: msg.toolCall!);
          }
          if (msg.isAutomation && msg.automationResult != null) {
            return AutomationResultCard(info: msg.automationResult!);
          }
          return MessageBubble(message: msg);
        }
        // Thinking indicator (shown while waiting for first token)
        if (isThinking && adjustedIndex == messages.length) {
          return const ThinkingIndicator();
        }
        // Streaming message
        if (streamingMessage != null) {
          return MessageBubble(
            message: streamingMessage,
            isStreaming: true,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 48,
            color: FerriColors.primary.withAlpha(128),
          ),
          const SizedBox(height: 16),
          const Text(
            'Start a conversation',
            style: TextStyle(
              color: FerriColors.textSoft,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ask Ferri anything to get started',
            style: TextStyle(
              color: FerriColors.textFaint,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isActive, ChatState chatState) {
    return Container(
      decoration: const BoxDecoration(
        color: FerriColors.bgCard,
        border: Border(
          top: BorderSide(color: FerriColors.border),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Suggestion chips
          _buildSuggestionChips(chatState),
          // Input row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    enabled: !isActive,
                    minLines: 1,
                    maxLines: 5,
                    style: const TextStyle(
                      color: FerriColors.text,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ask Ferri anything...',
                      hintStyle: const TextStyle(
                        color: FerriColors.textFaint,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            const BorderSide(color: FerriColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            const BorderSide(color: FerriColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                            color: FerriColors.borderFocus),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            const BorderSide(color: FerriColors.border),
                      ),
                      filled: true,
                      fillColor: FerriColors.bgInput,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8),
                // Mic button (hold-to-talk)
                if (_speechAvailable)
                  GestureDetector(
                    onLongPressStart: isActive ? null : (_) => _startListening(),
                    onLongPressEnd: isActive ? null : (_) => _stopListening(),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _isListening
                            ? FerriColors.danger
                            : isActive
                                ? FerriColors.bgElevated
                                : FerriColors.bgElevated,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isListening
                              ? FerriColors.danger
                              : FerriColors.border,
                        ),
                      ),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening
                            ? Colors.white
                            : FerriColors.textSoft,
                        size: 20,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                // Send button
                GestureDetector(
                  onTap: isActive ? null : _sendMessage,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isActive
                          ? FerriColors.primary.withAlpha(100)
                          : FerriColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_upward,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChips(ChatState chatState) {
    // Only show chips when the chat is empty
    if (chatState.messages.isNotEmpty) {
      return const SizedBox.shrink();
    }

    const suggestions = [
      'What can you do?',
      'Search the web',
      'Help me write',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: suggestions.map((label) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                _textController.text = label;
                _sendMessage();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: FerriColors.primaryDim,
                  border: Border.all(color: FerriColors.borderFocus),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: FerriColors.primary,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
