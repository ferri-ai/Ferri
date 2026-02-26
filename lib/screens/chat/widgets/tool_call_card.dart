import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../theme/colors.dart';

/// Info about a tool call to display in the chat.
class ToolCallInfo {
  final String toolName;
  final Map<String, dynamic> params;
  final String? result;
  final Duration? duration;
  final bool isInProgress;

  const ToolCallInfo({
    required this.toolName,
    this.params = const {},
    this.result,
    this.duration,
    this.isInProgress = false,
  });

  Map<String, dynamic> toJson() => {
    'tool_name': toolName,
    'params': params,
    if (result != null) 'result': result,
    if (duration != null) 'duration_ms': duration!.inMilliseconds,
    'is_in_progress': false,
  };

  factory ToolCallInfo.fromJson(Map<String, dynamic> json) => ToolCallInfo(
    toolName: json['tool_name'] as String? ?? '',
    params: (json['params'] as Map<String, dynamic>?) ?? const {},
    result: json['result'] as String?,
    duration: json['duration_ms'] != null
        ? Duration(milliseconds: json['duration_ms'] as int)
        : null,
    isInProgress: false,
  );

  /// Human-readable display name from the tool name.
  String get displayName {
    // calendar_read_events → Calendar: Read Events
    final parts = toolName.split('_');
    if (parts.length < 2) return toolName;
    final category = parts[0][0].toUpperCase() + parts[0].substring(1);
    final action = parts.sublist(1).map((p) =>
      p[0].toUpperCase() + p.substring(1)
    ).join(' ');
    return '$category: $action';
  }

  /// Color for the tool category.
  Color get color {
    if (toolName.startsWith('calendar')) return FerriColors.capCalendar;
    if (toolName.startsWith('contacts')) return FerriColors.capContacts;
    if (toolName.startsWith('location')) return FerriColors.capLocation;
    return FerriColors.primary;
  }

  /// Icon for the tool category.
  IconData get icon {
    if (toolName.startsWith('calendar')) return Icons.calendar_month;
    if (toolName.startsWith('contacts')) return Icons.contacts;
    if (toolName.startsWith('location')) return Icons.location_on;
    return Icons.build;
  }
}

/// Expandable card showing a tool call in the chat.
class ToolCallCard extends StatefulWidget {
  final ToolCallInfo info;

  const ToolCallCard({super.key, required this.info});

  @override
  State<ToolCallCard> createState() => _ToolCallCardState();
}

class _ToolCallCardState extends State<ToolCallCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final info = widget.info;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: FerriColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: info.color.withAlpha(60),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: tap to expand
            InkWell(
              onTap: info.isInProgress ? null : () {
                setState(() => _expanded = !_expanded);
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(info.icon, size: 16, color: info.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        info.displayName,
                        style: TextStyle(
                          color: info.color,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (info.isInProgress)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: info.color,
                        ),
                      )
                    else ...[
                      if (info.duration != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            '${info.duration!.inMilliseconds}ms',
                            style: const TextStyle(
                              color: FerriColors.textFaint,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      Icon(
                        _expanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 16,
                        color: FerriColors.textFaint,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Expanded details
            if (_expanded) ...[
              const Divider(
                  height: 1,
                  color: FerriColors.border,
                  indent: 12,
                  endIndent: 12),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (info.params.isNotEmpty) ...[
                      const Text(
                        'Parameters',
                        style: TextStyle(
                          color: FerriColors.textFaint,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: FerriColors.bgInput,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formatJson(info.params),
                          style: const TextStyle(
                            color: FerriColors.textSoft,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                    if (info.result != null) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Result',
                        style: TextStyle(
                          color: FerriColors.textFaint,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: FerriColors.bgInput,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: SingleChildScrollView(
                          child: Text(
                            _formatResult(info.result!),
                            style: const TextStyle(
                              color: FerriColors.textSoft,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatJson(Map<String, dynamic> json) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }

  String _formatResult(String result) {
    try {
      final parsed = jsonDecode(result);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(parsed);
    } catch (_) {
      return result;
    }
  }
}
