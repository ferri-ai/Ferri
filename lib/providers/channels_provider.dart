import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/channel_event_stream.dart';
import '../native/automation_notifications.dart';
import '../native/service_channel.dart';
import 'app_lifecycle_provider.dart';
import 'automation_provider.dart';
import 'chat_provider.dart';
import 'engine_provider.dart';
import 'settings_provider.dart';

/// Supported channel types.
enum ChannelType {
  telegram,
  discord,
  slack;

  String get displayName {
    switch (this) {
      case ChannelType.telegram:
        return 'Telegram';
      case ChannelType.discord:
        return 'Discord';
      case ChannelType.slack:
        return 'Slack';
    }
  }

  IconData get icon {
    switch (this) {
      case ChannelType.telegram:
        return Icons.telegram;
      case ChannelType.discord:
        return Icons.discord;
      case ChannelType.slack:
        return Icons.mark_chat_read;
    }
  }

  /// Fields required for this channel type.
  List<String> get configFields {
    switch (this) {
      case ChannelType.telegram:
        return ['token'];
      case ChannelType.discord:
        return ['token'];
      case ChannelType.slack:
        return ['bot_token', 'app_token'];
    }
  }
}

/// Connection status of a channel.
enum ChannelConnectionStatus { disconnected, connecting, connected, error }

/// State for a single channel.
class ChannelState {
  final ChannelType type;
  final bool enabled;
  final ChannelConnectionStatus connectionStatus;
  final String? errorMessage;
  final int messageCount;

  const ChannelState({
    required this.type,
    this.enabled = false,
    this.connectionStatus = ChannelConnectionStatus.disconnected,
    this.errorMessage,
    this.messageCount = 0,
  });

  ChannelState copyWith({
    bool? enabled,
    ChannelConnectionStatus? connectionStatus,
    String? Function()? errorMessage,
    int? messageCount,
  }) {
    return ChannelState(
      type: type,
      enabled: enabled ?? this.enabled,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      errorMessage:
          errorMessage != null ? errorMessage() : this.errorMessage,
      messageCount: messageCount ?? this.messageCount,
    );
  }
}

/// Overall channels state.
class ChannelsState {
  final Map<ChannelType, ChannelState> channels;
  final bool eventsInitialized;

  const ChannelsState({
    this.channels = const {},
    this.eventsInitialized = false,
  });

  ChannelState? operator [](ChannelType type) => channels[type];

  int get activeCount =>
      channels.values.where((c) => c.enabled).length;

  ChannelsState copyWith({
    Map<ChannelType, ChannelState>? channels,
    bool? eventsInitialized,
  }) {
    return ChannelsState(
      channels: channels ?? this.channels,
      eventsInitialized: eventsInitialized ?? this.eventsInitialized,
    );
  }
}

class ChannelsNotifier extends StateNotifier<ChannelsState> {
  final EngineNotifier _engine;
  final SharedPreferences _prefs;
  final Ref _ref;
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  ChannelsNotifier(this._engine, this._prefs, this._ref)
      : super(const ChannelsState()) {
    _initChannelStates();
  }

  void _initChannelStates() {
    final channels = <ChannelType, ChannelState>{};
    for (final type in ChannelType.values) {
      channels[type] = ChannelState(type: type);
    }
    state = state.copyWith(channels: channels);
  }

  /// Initialize channel event listening. Call after engine is ready.
  void initEvents() {
    if (state.eventsInitialized) return;
    final ok = _engine.initChannelEvents(onEvent: _handleEvent);
    if (ok) {
      state = state.copyWith(eventsInitialized: true);
    }
  }

  /// Enable a channel with the given config.
  Future<bool> enableChannel(
    ChannelType type,
    Map<String, String> config,
  ) async {
    // Ensure event port is set before enabling so we don't miss the
    // "connected" event that Go fires synchronously in ferri_enable_channel.
    initEvents();

    _updateChannel(type, (c) => c.copyWith(
      connectionStatus: ChannelConnectionStatus.connecting,
    ));

    // Store config securely
    await _secureStorage.write(
      key: 'channel_${type.name}_config',
      value: jsonEncode(config),
    );

    // Build config JSON for Go
    final configJson = jsonEncode(config);
    final result = _engine.enableChannel(type.name, configJson);

    if (result != 0) {
      _updateChannel(type, (c) => c.copyWith(
        connectionStatus: ChannelConnectionStatus.error,
        errorMessage: () => 'Failed to enable (code: $result)',
      ));
      return false;
    }

    _updateChannel(type, (c) => c.copyWith(enabled: true));
    await _prefs.setBool('channel_${type.name}_enabled', true);

    // Start foreground service
    final cronCount = _ref.read(automationProvider).jobs.where((j) => j.enabled).length;
    await ServiceChannel.startService(
      channelCount: state.activeCount,
      cronJobCount: cronCount,
    );

    return true;
  }

  /// Disable a channel.
  Future<void> disableChannel(ChannelType type) async {
    _engine.disableChannel(type.name);

    _updateChannel(type, (c) => c.copyWith(
      enabled: false,
      connectionStatus: ChannelConnectionStatus.disconnected,
      errorMessage: () => null,
      messageCount: 0,
    ));

    await _prefs.setBool('channel_${type.name}_enabled', false);

    // Update or stop foreground service
    final cronCount = _ref.read(automationProvider).jobs.where((j) => j.enabled).length;
    if (state.activeCount > 0 ||
        _ref.read(settingsProvider).backgroundServiceEnabled) {
      await ServiceChannel.updateNotification(
        channelCount: state.activeCount,
        cronJobCount: cronCount,
      );
    } else {
      await ServiceChannel.stopService();
    }
  }

  /// Get stored config for a channel type.
  Future<Map<String, String>?> getStoredConfig(ChannelType type) async {
    final json = await _secureStorage.read(
      key: 'channel_${type.name}_config',
    );
    if (json == null) return null;
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v.toString()));
  }

  /// Re-enable previously active channels after engine re-init.
  Future<void> restoreChannels() async {
    initEvents();
    for (final type in ChannelType.values) {
      final wasEnabled =
          _prefs.getBool('channel_${type.name}_enabled') ?? false;
      if (!wasEnabled) continue;

      final config = await getStoredConfig(type);
      if (config != null) {
        debugPrint('[Channels] Restoring ${type.name}');
        await enableChannel(type, config);
      }
    }
  }

  void _handleEvent(ChannelEvent event) {
    debugPrint(
        '[Channels] event: ${event.type} channel=${event.channel}');

    final type = ChannelType.values.where(
      (t) => t.name == event.channel,
    );

    // Events from non-standard channels (e.g. "internal") are automation
    // results from cron jobs or heartbeats — show as automation card or
    // notification depending on whether the app is in the foreground.
    if (type.isEmpty) {
      if (event.type == 'channel_response') {
        final content = event.content ?? '';
        if (content.isNotEmpty) {
          final lifecycle = _ref.read(appLifecycleProvider);
          if (lifecycle == AppLifecycleState.resumed) {
            _ref.read(chatProvider.notifier).addAutomationResult(content);
          } else {
            AutomationNotifications.showResult(
              title: 'Ferri \u2014 Automation Result',
              body: content.length > 200
                  ? '${content.substring(0, 200)}...'
                  : content,
              fullContent: content,
            );
          }
        }
      }
      return;
    }
    final channelType = type.first;

    switch (event.type) {
      case 'channel_status':
        final status = event.status;
        if (status == 'connected') {
          _updateChannel(channelType, (c) => c.copyWith(
            connectionStatus: ChannelConnectionStatus.connected,
            errorMessage: () => null,
          ));
        } else if (status == 'disconnected') {
          _updateChannel(channelType, (c) => c.copyWith(
            connectionStatus: ChannelConnectionStatus.disconnected,
          ));
        } else if (status == 'error') {
          _updateChannel(channelType, (c) => c.copyWith(
            connectionStatus: ChannelConnectionStatus.error,
            errorMessage: () => event.error,
          ));
        }

      case 'channel_message':
        _updateChannel(channelType, (c) => c.copyWith(
          messageCount: c.messageCount + 1,
        ));

      case 'channel_response':
        // Could update UI with response info
        break;
    }
  }

  void _updateChannel(
    ChannelType type,
    ChannelState Function(ChannelState) updater,
  ) {
    final channels = Map<ChannelType, ChannelState>.from(state.channels);
    final current = channels[type] ?? ChannelState(type: type);
    channels[type] = updater(current);
    state = state.copyWith(channels: channels);
  }
}

final channelsProvider =
    StateNotifierProvider<ChannelsNotifier, ChannelsState>((ref) {
  final engine = ref.watch(engineProvider.notifier);
  final prefs = ref.watch(sharedPreferencesProvider);
  return ChannelsNotifier(engine, prefs, ref);
});
