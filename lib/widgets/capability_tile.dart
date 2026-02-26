import 'package:flutter/material.dart';
import '../capabilities/models/capability.dart';
import '../theme/colors.dart';

/// Color-coded tile with icon, name, description, and toggle switch.
class CapabilityTile extends StatelessWidget {
  final Capability capability;
  final CapabilityStatus status;
  final bool isToggling;
  final ValueChanged<bool> onToggle;

  const CapabilityTile({
    super.key,
    required this.capability,
    required this.status,
    required this.isToggling,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = status == CapabilityStatus.enabled;
    final needsPermission = status == CapabilityStatus.permissionRequired;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: FerriColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEnabled
              ? capability.color.withAlpha(80)
              : FerriColors.border,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: capability.color.withAlpha(isEnabled ? 40 : 20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                capability.icon,
                size: 20,
                color: isEnabled
                    ? capability.color
                    : capability.color.withAlpha(120),
              ),
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        capability.displayName,
                        style: TextStyle(
                          color: isEnabled
                              ? FerriColors.text
                              : FerriColors.textSoft,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (capability.privileged) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: FerriColors.warning.withAlpha(180),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    needsPermission
                        ? (capability.privileged
                            ? 'Setup required \u2014 tap to configure'
                            : 'Permission required \u2014 tap to retry')
                        : capability.description,
                    style: TextStyle(
                      color: needsPermission
                          ? FerriColors.warning
                          : FerriColors.textFaint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Toggle
            if (isToggling)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: FerriColors.primary,
                ),
              )
            else
              Switch.adaptive(
                value: isEnabled,
                onChanged: onToggle,
                activeThumbColor: capability.color,
                activeTrackColor: capability.color.withAlpha(80),
                inactiveTrackColor: FerriColors.bgElevated,
                inactiveThumbColor: FerriColors.textFaint,
              ),
          ],
        ),
      ),
    );
  }
}
