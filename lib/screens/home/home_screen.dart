import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../capabilities/models/capability.dart';
import '../../providers/automation_provider.dart';
import '../../providers/capabilities_provider.dart';
import '../../providers/channels_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../engine/ferri_engine.dart';
import '../../providers/engine_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/colors.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final engineStatus = ref.watch(engineProvider);
    final isOnline = ref.watch(connectivityProvider);
    final automationState = ref.watch(automationProvider);
    final capState = ref.watch(capabilitiesProvider);
    final channelsState = ref.watch(channelsProvider);

    final enabledCaps = capState.statuses.values
        .where((s) => s == CapabilityStatus.enabled)
        .length;

    return Scaffold(
      backgroundColor: FerriColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Row(
                children: [
                  Icon(Icons.auto_awesome, size: 24, color: FerriColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Ferri',
                    style: TextStyle(
                      color: FerriColors.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // LLM Status
              const Text(
                'LLM CONNECTION',
                style: TextStyle(
                  color: FerriColors.textFaint,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              _buildLlmStatusCard(settings, engineStatus, isOnline),
              const SizedBox(height: 24),

              // Stats
              const Text(
                'OVERVIEW',
                style: TextStyle(
                  color: FerriColors.textFaint,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStatCard(
                    icon: Icons.schedule,
                    color: FerriColors.primary,
                    count: automationState.jobs.length,
                    label: 'Automations',
                  ),
                  const SizedBox(width: 10),
                  _buildStatCard(
                    icon: Icons.bolt,
                    color: FerriColors.warning,
                    count: enabledCaps,
                    label: 'Capabilities',
                  ),
                  const SizedBox(width: 10),
                  _buildStatCard(
                    icon: Icons.sensors,
                    color: FerriColors.success,
                    count: channelsState.activeCount,
                    label: 'Channels',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLlmStatusCard(
      AppSettings settings, EngineStatus status, bool isOnline) {
    final Color engineColor;
    final String engineText;
    switch (status) {
      case EngineStatus.ready:
        engineColor = FerriColors.success;
        engineText = 'Ready';
      case EngineStatus.error:
        engineColor = FerriColors.danger;
        engineText = 'Error';
      case EngineStatus.uninitialized:
        engineColor = FerriColors.textFaint;
        engineText = 'Not initialized';
    }

    final networkColor = isOnline ? FerriColors.success : FerriColors.danger;
    final networkText = isOnline ? 'Online' : 'Offline';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FerriColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FerriColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: engineColor.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.hub, color: engineColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.provider.isNotEmpty
                      ? settings.provider[0].toUpperCase() +
                          settings.provider.substring(1)
                      : 'No provider',
                  style: const TextStyle(
                    color: FerriColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  settings.model.isNotEmpty ? settings.model : 'No model set',
                  style: const TextStyle(
                    color: FerriColors.textSoft,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildStatusChip(engineText, engineColor),
              const SizedBox(height: 4),
              _buildStatusChip(networkText, networkColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required int count,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: FerriColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FerriColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: const TextStyle(
                color: FerriColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: FerriColors.textSoft,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
