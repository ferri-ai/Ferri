import 'package:flutter/material.dart';
import '../theme/colors.dart';

class _TabDef {
  const _TabDef({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const _tabs = [
  _TabDef(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
  _TabDef(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'Chat'),
  _TabDef(icon: Icons.schedule, activeIcon: Icons.schedule, label: 'Automate'),
  _TabDef(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Settings'),
];

class FerriNavBar extends StatelessWidget {
  const FerriNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: FerriColors.bgCard,
        border: Border(
          top: BorderSide(color: FerriColors.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            children: List.generate(_tabs.length, (index) {
              final tab = _tabs[index];
              final isActive = index == currentIndex;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(index),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive ? tab.activeIcon : tab.icon,
                        size: 22,
                        color: isActive
                            ? FerriColors.primary
                            : FerriColors.textFaint,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 10,
                          color: isActive
                              ? FerriColors.primary
                              : FerriColors.textFaint,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Active indicator dot
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? FerriColors.primary
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
