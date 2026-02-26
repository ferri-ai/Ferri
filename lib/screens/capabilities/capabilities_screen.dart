import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../capabilities/capability_registry.dart';
import '../../capabilities/models/capability.dart';
import '../../providers/capabilities_provider.dart';
import '../../theme/colors.dart';
import '../../widgets/capability_tile.dart';

class CapabilitiesScreen extends ConsumerStatefulWidget {
  const CapabilitiesScreen({super.key});

  @override
  ConsumerState<CapabilitiesScreen> createState() => _CapabilitiesScreenState();
}

class _CapabilitiesScreenState extends ConsumerState<CapabilitiesScreen>
    with WidgetsBindingObserver {
  final Set<String> _toggling = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check privileged capabilities when returning from settings
      _recheckPrivilegedCapabilities();
    }
  }

  Future<void> _recheckPrivilegedCapabilities() async {
    final notifier = ref.read(capabilitiesProvider.notifier);
    final capState = ref.read(capabilitiesProvider);

    for (final cap in CapabilityRegistry.allCapabilities) {
      if (!cap.privileged) continue;
      if (capState.statusOf(cap.id) != CapabilityStatus.permissionRequired) {
        continue;
      }
      // Re-check if user granted access while in settings
      final granted = await notifier.checkPrivilegedAccess(cap.id);
      if (granted) {
        await notifier.enable(cap.id);
      }
    }
  }

  Future<void> _onToggle(String capabilityId, bool enable) async {
    if (_toggling.contains(capabilityId)) return;

    setState(() => _toggling.add(capabilityId));

    try {
      final notifier = ref.read(capabilitiesProvider.notifier);
      if (enable) {
        await notifier.enable(capabilityId);
      } else {
        await notifier.disable(capabilityId);
      }
    } finally {
      if (mounted) {
        setState(() => _toggling.remove(capabilityId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final capState = ref.watch(capabilitiesProvider);

    // Group capabilities by tier
    final coreCaps = CapabilityRegistry.allCapabilities
        .where((c) => c.tier == CapabilityTier.core)
        .toList();
    final extendedCaps = CapabilityRegistry.allCapabilities
        .where((c) => c.tier == CapabilityTier.extended)
        .toList();

    return Scaffold(
      backgroundColor: FerriColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: FerriColors.text, size: 22),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text(
                          'Capabilities',
                          style: TextStyle(
                            color: FerriColors.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Text(
                      'Enable capabilities to let Ferri access your device features. '
                      'The AI agent only uses enabled capabilities.',
                      style: TextStyle(
                        color: FerriColors.textSoft,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Core capabilities
            if (coreCaps.isNotEmpty) ...[
              _buildSectionHeader('Core'),
              _buildCapabilityList(coreCaps, capState),
            ],

            // Extended capabilities
            if (extendedCaps.isNotEmpty) ...[
              _buildSectionHeader('Extended'),
              _buildCapabilityList(extendedCaps, capState),
            ],

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: FerriColors.textFaint,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  SliverList _buildCapabilityList(
      List<Capability> capabilities, CapabilitiesState capState) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final cap = capabilities[index];
          return CapabilityTile(
            capability: cap,
            status: capState.statusOf(cap.id),
            isToggling: _toggling.contains(cap.id),
            onToggle: (enable) => _onToggle(cap.id, enable),
          );
        },
        childCount: capabilities.length,
      ),
    );
  }
}
