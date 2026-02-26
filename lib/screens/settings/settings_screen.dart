import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../native/service_channel.dart';
import '../../providers/channels_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/engine_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/colors.dart';
import '../channels/channels_screen.dart';
import '../capabilities/capabilities_screen.dart';
import 'llm_config_screen.dart';
import 'memory_screen.dart';
import 'search_settings_screen.dart';
import 'skills_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: FerriColors.bg,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            const Row(
              children: [
                Icon(Icons.settings, size: 24, color: FerriColors.primary),
                SizedBox(width: 8),
                Text(
                  'Settings',
                  style: TextStyle(
                    color: FerriColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── CONFIGURATION ───
            const Text(
              'CONFIGURATION',
              style: TextStyle(
                color: FerriColors.textFaint,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            _buildNavTile(
              context: context,
              icon: Icons.hub,
              iconColor: FerriColors.primary,
              title: 'LLM Configuration',
              description: 'Provider, model, and API key',
              screen: const LlmConfigScreen(),
            ),
            const SizedBox(height: 8),
            _buildNavTile(
              context: context,
              icon: Icons.sensors,
              iconColor: FerriColors.success,
              title: 'Channels',
              description: 'Telegram, Discord, Slack connections',
              screen: const ChannelsScreen(),
            ),
            const SizedBox(height: 8),
            _buildNavTile(
              context: context,
              icon: Icons.bolt,
              iconColor: FerriColors.warning,
              title: 'Capabilities',
              description: 'Device features available to Ferri',
              screen: const CapabilitiesScreen(),
            ),
            const SizedBox(height: 8),
            _buildNavTile(
              context: context,
              icon: Icons.search,
              iconColor: const Color(0xFFFF6B2C),
              title: 'Search',
              description: 'Web search provider for Ferri',
              screen: const SearchSettingsScreen(),
            ),
            const SizedBox(height: 8),
            _buildNavTile(
              context: context,
              icon: Icons.auto_awesome,
              iconColor: FerriColors.primary,
              title: 'Skills',
              description: 'Specialized workflows for Ferri',
              screen: const SkillsScreen(),
            ),
            const SizedBox(height: 24),

            // ─── PREFERENCES ───
            const Text(
              'PREFERENCES',
              style: TextStyle(
                color: FerriColors.textFaint,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            _buildToggleTile(
              icon: Icons.shield_outlined,
              iconColor: FerriColors.warning,
              title: 'Approve destructive actions',
              description: 'Ask before update or delete operations',
              value: settings.toolApprovalRequired,
              activeColor: FerriColors.warning,
              onChanged: (v) {
                ref.read(settingsProvider.notifier).setToolApprovalRequired(v);
                ref.read(engineProvider.notifier).setRequireApproval(v);
              },
            ),
            const SizedBox(height: 8),
            _buildToggleTile(
              icon: Icons.build_outlined,
              iconColor: FerriColors.primary,
              title: 'Visual automation builder',
              description: 'Create automations without chat',
              value: settings.showVisualBuilder,
              activeColor: FerriColors.primary,
              onChanged: (v) {
                ref.read(settingsProvider.notifier).setShowVisualBuilder(v);
              },
            ),
            const SizedBox(height: 8),
            _BackgroundToggleTile(settings: settings),
            const SizedBox(height: 24),

            // ─── DATA ───
            const Text(
              'DATA',
              style: TextStyle(
                color: FerriColors.textFaint,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            _buildNavTile(
              context: context,
              icon: Icons.psychology,
              iconColor: FerriColors.primary,
              title: 'Memory',
              description: 'View and edit what Ferri remembers',
              screen: const MemoryScreen(),
            ),
            const SizedBox(height: 8),
            _ClearChatTile(),
          ],
        ),
      ),
    );
  }

  static Widget _buildNavTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required Widget screen,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => screen),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: FerriColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FerriColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: FerriColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      color: FerriColors.textFaint,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: FerriColors.textFaint, size: 20),
          ],
        ),
      ),
    );
  }

  static Widget _buildToggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: FerriColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FerriColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: FerriColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    color: FerriColors.textFaint,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: activeColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Background toggle needs Consumer for async + ref access in onChanged.
class _BackgroundToggleTile extends ConsumerWidget {
  final AppSettings settings;
  const _BackgroundToggleTile({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: FerriColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FerriColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync, size: 18, color: FerriColors.success),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Background service',
                  style: TextStyle(
                    color: FerriColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Keeps Ferri running for cron jobs and automations. '
                  'Required when channels are off.',
                  style: TextStyle(
                    color: FerriColors.textFaint,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: settings.backgroundServiceEnabled,
            activeTrackColor: FerriColors.success,
            onChanged: (v) async {
              await ref
                  .read(settingsProvider.notifier)
                  .setBackgroundServiceEnabled(v);
              if (v) {
                await ServiceChannel.startService();
              } else {
                final channels = ref.read(channelsProvider);
                if (channels.activeCount == 0) {
                  await ServiceChannel.stopService();
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ClearChatTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showConfirmDialog(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: FerriColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FerriColors.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.delete_outline, size: 18, color: FerriColors.danger),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clear Chat',
                    style: TextStyle(
                      color: FerriColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Delete all conversation history',
                    style: TextStyle(
                      color: FerriColors.textFaint,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: FerriColors.textFaint, size: 20),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FerriColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear Chat',
          style: TextStyle(color: FerriColors.text),
        ),
        content: const Text(
          'This will permanently delete all messages, tool calls, and '
          'automation results. This cannot be undone.',
          style: TextStyle(color: FerriColors.textSoft, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: FerriColors.textFaint),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(chatProvider.notifier).clearAll();
              ref.read(engineProvider.notifier).clearSession();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chat history cleared'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: FerriColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
