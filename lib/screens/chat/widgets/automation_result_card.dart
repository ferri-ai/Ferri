import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../providers/chat_provider.dart';
import '../../../theme/colors.dart';

/// Card displaying an automation result (cron job, geofence, heartbeat) in chat.
class AutomationResultCard extends StatefulWidget {
  final AutomationResultInfo info;

  const AutomationResultCard({super.key, required this.info});

  @override
  State<AutomationResultCard> createState() => _AutomationResultCardState();
}

class _AutomationResultCardState extends State<AutomationResultCard> {
  bool _expanded = true;

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    const color = FerriColors.warning;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: FerriColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, size: 16, color: color),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Automation Result',
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(info.ranAt),
                      style: const TextStyle(
                        color: FerriColors.textFaint,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: FerriColors.textFaint,
                    ),
                  ],
                ),
              ),
            ),
            // Content
            if (_expanded) ...[
              const Divider(
                height: 1,
                color: FerriColors.border,
                indent: 12,
                endIndent: 12,
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: MarkdownBody(
                  data: info.content,
                  selectable: true,
                  styleSheet: _markdownStyle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static final _markdownStyle = MarkdownStyleSheet(
    p: const TextStyle(
      color: FerriColors.text,
      fontSize: 13,
      height: 1.5,
    ),
    strong: const TextStyle(
      color: FerriColors.text,
      fontWeight: FontWeight.bold,
    ),
    em: const TextStyle(
      color: FerriColors.text,
      fontStyle: FontStyle.italic,
    ),
    code: const TextStyle(
      color: FerriColors.primaryLight,
      backgroundColor: FerriColors.bgInput,
      fontSize: 12,
      fontFamily: 'monospace',
    ),
    listBullet: const TextStyle(
      color: FerriColors.textSoft,
      fontSize: 13,
    ),
  );
}
