import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../native/automation_notifications.dart';
import '../native/service_channel.dart';
import '../providers/app_lifecycle_provider.dart';
import '../providers/automation_provider.dart';
import '../providers/capabilities_provider.dart';
import '../providers/channels_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/engine_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/nav_bar.dart';
import 'automation/automation_screen.dart';
import 'chat/chat_screen.dart';
import 'home/home_screen.dart';
import 'settings/settings_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  static const _automationTabIndex = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoStartServiceIfNeeded();
    _initializeEngine();
    _setupNotificationTapHandler();
    _flushPendingAutomationResults();
    ref.read(appLifecycleProvider);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _flushPendingAutomationResults();
    }
  }

  /// Wire up the notification tap callback to insert results into chat.
  void _setupNotificationTapHandler() {
    AutomationNotifications.onNotificationTapped = (content) {
      ref.read(chatProvider.notifier).addAutomationResult(content);
      // Switch to chat tab so the user sees the result
      setState(() => _currentIndex = 1);
    };
  }

  /// Drain any automation results that arrived while the app was backgrounded
  /// and insert them into the chat as automation cards.
  Future<void> _flushPendingAutomationResults() async {
    final pending = await AutomationNotifications.drainPending();
    if (pending.isEmpty || !mounted) return;
    final chat = ref.read(chatProvider.notifier);
    for (final result in pending) {
      chat.addAutomationResult(result.content, ranAt: result.ranAt);
    }
  }

  void _autoStartServiceIfNeeded() {
    final settings = ref.read(settingsProvider);
    if (settings.backgroundServiceEnabled) {
      ServiceChannel.startService();
    }
  }

  /// Initialize the Go engine eagerly so history loads on app open
  /// and cron jobs/capabilities are available immediately.
  Future<void> _initializeEngine() async {
    final settings = ref.read(settingsProvider);
    final apiKey = await ref.read(settingsProvider.notifier).getApiKey();
    if (apiKey == null || apiKey.isEmpty) return;

    final braveApiKey =
        await ref.read(settingsProvider.notifier).getBraveApiKey();
    final engineNotifier = ref.read(engineProvider.notifier);
    await engineNotifier.initialize(settings, apiKey,
        braveApiKey: braveApiKey);

    // Register capability tools
    if (mounted) {
      ref.read(capabilitiesProvider.notifier).registerAllEnabled();
    }

    // Restore previously-enabled channels (e.g. Telegram) after engine is ready
    if (mounted) {
      await ref.read(channelsProvider.notifier).restoreChannels();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),
          ChatScreen(),
          AutomationScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: FerriNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == _automationTabIndex) {
            ref.read(automationProvider.notifier).refresh();
          }
        },
      ),
    );
  }
}
