import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/channels_provider.dart';
import '../../theme/colors.dart';

class ChannelsScreen extends ConsumerStatefulWidget {
  const ChannelsScreen({super.key});

  @override
  ConsumerState<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends ConsumerState<ChannelsScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize channel events when screen is first shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(channelsProvider.notifier).initEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final channelsState = ref.watch(channelsProvider);

    return Scaffold(
      backgroundColor: FerriColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: FerriColors.text, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Channels',
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
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Connect messaging platforms so Ferri can respond on your behalf.',
                style: TextStyle(
                  color: FerriColors.textSoft,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: ChannelType.values.map((type) {
                  final channelState = channelsState[type];
                  return _ChannelCard(
                    type: type,
                    state: channelState ?? ChannelState(type: type),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelCard extends ConsumerStatefulWidget {
  final ChannelType type;
  final ChannelState state;

  const _ChannelCard({required this.type, required this.state});

  @override
  ConsumerState<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends ConsumerState<_ChannelCard> {
  bool _expanded = false;
  bool _loading = false;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (final field in widget.type.configFields) {
      _controllers[field] = TextEditingController();
    }
    _loadStoredConfig();
  }

  Future<void> _loadStoredConfig() async {
    final config = await ref
        .read(channelsProvider.notifier)
        .getStoredConfig(widget.type);
    if (config != null && mounted) {
      for (final entry in config.entries) {
        _controllers[entry.key]?.text = entry.value;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Color get _channelColor {
    switch (widget.type) {
      case ChannelType.telegram:
        return FerriColors.chTelegram;
      case ChannelType.discord:
        return FerriColors.chDiscord;
      case ChannelType.slack:
        return FerriColors.chSlack;
    }
  }

  Color get _statusColor {
    switch (widget.state.connectionStatus) {
      case ChannelConnectionStatus.connected:
        return FerriColors.success;
      case ChannelConnectionStatus.connecting:
        return FerriColors.warning;
      case ChannelConnectionStatus.error:
        return FerriColors.danger;
      case ChannelConnectionStatus.disconnected:
        return FerriColors.textFaint;
    }
  }

  String get _statusText {
    switch (widget.state.connectionStatus) {
      case ChannelConnectionStatus.connected:
        return 'Connected';
      case ChannelConnectionStatus.connecting:
        return 'Connecting...';
      case ChannelConnectionStatus.error:
        return widget.state.errorMessage ?? 'Error';
      case ChannelConnectionStatus.disconnected:
        return widget.state.enabled ? 'Disconnected' : 'Not configured';
    }
  }

  Future<void> _toggle(bool enable) async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      if (enable) {
        // Validate fields
        final config = <String, String>{};
        for (final field in widget.type.configFields) {
          final value = _controllers[field]?.text.trim() ?? '';
          if (value.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Please enter ${field.replaceAll('_', ' ')}'),
                  backgroundColor: FerriColors.danger,
                ),
              );
            }
            return;
          }
          config[field] = value;
        }
        await ref.read(channelsProvider.notifier).enableChannel(
              widget.type,
              config,
            );
      } else {
        await ref.read(channelsProvider.notifier).disableChannel(
              widget.type,
            );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: FerriColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.state.enabled
              ? _channelColor.withValues(alpha: 0.3)
              : FerriColors.border,
        ),
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Channel icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _channelColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.type.icon,
                      color: _channelColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name + status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.type.displayName,
                          style: const TextStyle(
                            color: FerriColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: _statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _statusText,
                                style: TextStyle(
                                  color: _statusColor,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Message count badge
                  if (widget.state.messageCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _channelColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.state.messageCount}',
                        style: TextStyle(
                          color: _channelColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Expand arrow
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: FerriColors.textSoft,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded config section
          if (_expanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: FerriColors.border, height: 1),
                  const SizedBox(height: 12),

                  // Config fields
                  ...widget.type.configFields.map((field) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: _controllers[field],
                        enabled: !widget.state.enabled,
                        obscureText: true,
                        style: const TextStyle(
                          color: FerriColors.text,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          labelText: field.replaceAll('_', ' ').toUpperCase(),
                          labelStyle: const TextStyle(
                            color: FerriColors.textSoft,
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: FerriColors.bgInput,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: FerriColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: FerriColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: _channelColor.withValues(alpha: 0.5)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 4),

                  // Enable/Disable button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading
                          ? null
                          : () => _toggle(!widget.state.enabled),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.state.enabled
                            ? FerriColors.danger.withValues(alpha: 0.2)
                            : _channelColor.withValues(alpha: 0.2),
                        foregroundColor: widget.state.enabled
                            ? FerriColors.danger
                            : _channelColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : Text(
                              widget.state.enabled ? 'Disconnect' : 'Connect',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
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
}
