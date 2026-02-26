import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'services/chat_log_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final documentsDir = await getApplicationDocumentsDirectory();
  final chatLog = ChatLogService('${documentsDir.path}/ferri_workspace');

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        chatLogServiceProvider.overrideWithValue(chatLog),
      ],
      child: const FerriApp(),
    ),
  );
}
