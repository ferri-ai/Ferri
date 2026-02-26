import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/settings_provider.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'theme/colors.dart';
import 'theme/ferri_theme.dart';

class FerriApp extends ConsumerWidget {
  const FerriApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    final Widget home;
    if (!settings.loaded) {
      home = const Scaffold(
        backgroundColor: FerriColors.bg,
        body: SizedBox.shrink(),
      );
    } else if (settings.onboardingComplete) {
      home = const MainShell();
    } else {
      home = const OnboardingFlow();
    }

    return MaterialApp(
      title: 'Ferri',
      theme: FerriTheme.dark,
      home: home,
      debugShowCheckedModeBanner: false,
    );
  }
}
