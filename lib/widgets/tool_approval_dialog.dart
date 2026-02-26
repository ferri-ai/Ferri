import 'package:flutter/material.dart';
import '../engine/tool_dispatcher.dart';
import '../capabilities/capability_registry.dart';
import '../theme/colors.dart';

/// Modal dialog shown when a destructive tool call needs user approval.
/// Returns true (approve) or false (deny) via Navigator.pop.
class ToolApprovalDialog extends StatelessWidget {
  final ToolRequest request;

  const ToolApprovalDialog({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    // Resolve capability color from tool name prefix (e.g. "calendar_" → calendar)
    final capId = request.toolName.split('_').first;
    final capability = CapabilityRegistry.byId(capId);
    final color = capability?.color ?? FerriColors.warning;
    final capName = capability?.displayName ?? capId;

    // Human-readable action from tool name
    final action = _humanReadableAction(request.toolName);

    return Dialog(
      backgroundColor: FerriColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withAlpha(100)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Approve $capName Action',
                    style: const TextStyle(
                      color: FerriColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action description
            Text(
              'Ferri wants to $action',
              style: const TextStyle(
                color: FerriColors.textSoft,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // Parameters (constrained to prevent overflow)
            if (request.params.isNotEmpty) ...[
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.35,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FerriColors.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: FerriColors.border),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: request.params.entries.map((entry) {
                        final display = _truncateValue('${entry.value}', 200);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${entry.key}: ',
                                style: const TextStyle(
                                  color: FerriColors.textFaint,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  display,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: FerriColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: FerriColors.border),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Deny',
                        style: TextStyle(
                          color: FerriColors.textSoft,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Approve',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Truncate long values for display in the approval dialog.
  static String _truncateValue(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength)}...';
  }

  /// Convert tool name like "calendar_delete_event" to "delete a calendar event".
  static String _humanReadableAction(String toolName) {
    final parts = toolName.split('_');
    if (parts.length < 2) return toolName;

    // e.g. ["calendar", "delete", "event"] → "delete a calendar event"
    final capability = parts[0]; // calendar
    final verb = parts[1]; // delete / update
    final noun = parts.length > 2 ? parts.sublist(2).join(' ') : '';

    return '$verb a $capability $noun'.trim();
  }
}
