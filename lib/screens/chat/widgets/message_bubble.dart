import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../providers/chat_provider.dart';
import '../../../theme/colors.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isStreaming;

  const MessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
  });

  bool get _isUser => message.role == 'user';

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth * 0.84;

    return Align(
      alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          gradient: _isUser
              ? const LinearGradient(
                  colors: [FerriColors.primary, FerriColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: _isUser ? null : FerriColors.bgCard,
          border: _isUser
              ? null
              : Border.all(color: FerriColors.border),
          borderRadius: _isUser
              ? const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                  bottomLeft: Radius.circular(18),
                )
              : const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    // User messages: plain text (no markdown)
    if (_isUser) {
      return Text(
        message.content,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.55,
        ),
      );
    }

    // Streaming: plain text with cursor (markdown parsing mid-stream is janky)
    if (isStreaming) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: message.content,
              style: const TextStyle(
                color: FerriColors.text,
                fontSize: 14,
                height: 1.55,
              ),
            ),
            const TextSpan(
              text: '\u258C', // block cursor character
              style: TextStyle(
                color: FerriColors.primaryLight,
                fontSize: 14,
                height: 1.55,
              ),
            ),
          ],
        ),
      );
    }

    // Finalized assistant messages: render markdown
    return MarkdownBody(
      data: message.content,
      selectable: true,
      styleSheet: _markdownStyle,
    );
  }

  static final _markdownStyle = MarkdownStyleSheet(
    // Body / paragraph text
    p: const TextStyle(
      color: FerriColors.text,
      fontSize: 14,
      height: 1.55,
    ),

    // Headings
    h1: const TextStyle(
      color: FerriColors.text,
      fontSize: 20,
      fontWeight: FontWeight.bold,
      height: 1.4,
    ),
    h2: const TextStyle(
      color: FerriColors.text,
      fontSize: 17,
      fontWeight: FontWeight.bold,
      height: 1.4,
    ),
    h3: const TextStyle(
      color: FerriColors.text,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),

    // Bold and italic
    strong: const TextStyle(
      color: FerriColors.text,
      fontWeight: FontWeight.bold,
    ),
    em: const TextStyle(
      color: FerriColors.text,
      fontStyle: FontStyle.italic,
    ),

    // Inline code
    code: const TextStyle(
      color: FerriColors.primaryLight,
      backgroundColor: FerriColors.bgInput,
      fontSize: 13,
      fontFamily: 'monospace',
    ),

    // Code blocks
    codeblockDecoration: BoxDecoration(
      color: FerriColors.bgInput,
      borderRadius: BorderRadius.circular(8),
    ),
    codeblockPadding: const EdgeInsets.all(12),

    // Lists
    listBullet: const TextStyle(
      color: FerriColors.textSoft,
      fontSize: 14,
    ),

    // Links
    a: const TextStyle(
      color: FerriColors.primaryLight,
      decoration: TextDecoration.underline,
    ),

    // Blockquote
    blockquote: const TextStyle(
      color: FerriColors.textSoft,
      fontSize: 14,
      fontStyle: FontStyle.italic,
      height: 1.55,
    ),
    blockquoteDecoration: const BoxDecoration(
      border: Border(
        left: BorderSide(
          color: Color(0x64E8553A), // FerriColors.primary at alpha 100
          width: 3,
        ),
      ),
    ),
    blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),

    // Horizontal rule
    horizontalRuleDecoration: const BoxDecoration(
      border: Border(
        top: BorderSide(
          color: FerriColors.border,
          width: 1,
        ),
      ),
    ),
  );
}
