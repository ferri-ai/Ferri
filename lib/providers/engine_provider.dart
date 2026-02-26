import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../capabilities/models/capability.dart';
import '../engine/channel_event_stream.dart';
import '../engine/ferri_engine.dart';
import '../engine/tool_dispatcher.dart';
import '../engine/token_stream.dart';
import 'settings_provider.dart';

class EngineNotifier extends StateNotifier<EngineStatus> {
  EngineNotifier() : super(EngineStatus.uninitialized);

  final FerriEngine _engine = FerriEngine();

  /// Callback to forward token messages to the chat provider.
  void Function(TokenMessage)? onTokenCallback;

  /// Callback invoked when a destructive tool needs user approval.
  /// Set by the ChatScreen. Returns true to approve, false to deny.
  Future<bool> Function(ToolRequest)? onApprovalRequired;

  String? _lastApiKey;
  String? _lastBraveApiKey;

  /// Initialize the Go engine with the given settings and API key.
  /// Re-initializes if the API key or Brave key changed since last init.
  Future<void> initialize(AppSettings settings, String apiKey,
      {String? braveApiKey}) async {
    if (state == EngineStatus.ready &&
        apiKey == _lastApiKey &&
        braveApiKey == _lastBraveApiKey) {
      return;
    }

    // Stop previous engine if re-initializing with a new key
    if (state == EngineStatus.ready) {
      _engine.stop();
    }
    _lastApiKey = apiKey;
    _lastBraveApiKey = braveApiKey;

    final documentsDir = await getApplicationDocumentsDirectory();
    final workspaceDir =
        Directory('${documentsDir.path}/ferri_workspace');
    if (!workspaceDir.existsSync()) {
      workspaceDir.createSync(recursive: true);
    }

    await _copyBundledSkills(workspaceDir.path);

    final configMap = {
      'workspace': workspaceDir.path,
      'provider': settings.provider,
      'model': settings.model,
      'api_key': apiKey,
      'api_base': settings.apiBase,
    };
    if (braveApiKey != null && braveApiKey.isNotEmpty) {
      configMap['brave_api_key'] = braveApiKey;
    }
    final configJson = jsonEncode(configMap);

    _engine.init(
      configJson: configJson,
      onToken: (TokenMessage token) {
        onTokenCallback?.call(token);
      },
    );

    // Wire approval gate — callback delegates to whatever ChatScreen sets
    _engine.onApprovalRequired = (request) async {
      return await onApprovalRequired?.call(request) ?? true;
    };
    _engine.requireApproval = settings.toolApprovalRequired;

    state = _engine.status;
  }

  /// Send a message to the Go agent engine.
  void sendMessage(String message) {
    if (state != EngineStatus.ready) {
      onTokenCallback?.call(TokenMessage(
        type: 'error',
        content: 'Engine is not ready. Try restarting the app.',
        sessionId: '',
      ));
      return;
    }
    _engine.sendMessage(message);
  }

  /// Get session history from Go engine.
  List<Map<String, dynamic>> getHistory({String sessionKey = 'default'}) {
    if (state != EngineStatus.ready) return [];
    return _engine.getHistory(sessionKey: sessionKey);
  }

  /// Clear Go engine session (history + summary).
  Map<String, dynamic> clearSession({String sessionKey = 'default'}) {
    if (state != EngineStatus.ready) return {'success': false};
    return _engine.clearSession(sessionKey: sessionKey);
  }

  /// Mapping from capability tool names to their Dart-side handlers.
  /// Set by the capabilities provider before calling registerCapabilityTools.
  final Map<String, ToolHandler> toolHandlers = {};

  /// Register all tools for a capability with the Go engine.
  void registerCapabilityTools(Capability capability) {
    if (state != EngineStatus.ready) return;

    for (final tool in capability.tools) {
      final handler = toolHandlers[tool.name];
      if (handler == null) continue;

      _engine.registerPlatformTool(
        name: tool.name,
        description: tool.description,
        schema: tool.schema,
        handler: handler,
        destructive: tool.destructive,
      );
    }
  }

  /// Update the approval toggle at runtime (e.g. when settings change).
  void setRequireApproval(bool value) {
    if (state != EngineStatus.ready) return;
    _engine.requireApproval = value;
  }

  /// Unregister all tools for a capability from the Go engine.
  void unregisterCapabilityTools(Capability capability) {
    for (final tool in capability.tools) {
      _engine.unregisterPlatformTool(tool.name);
    }
  }

  /// Initialize channel event listening.
  /// Returns false if engine isn't ready yet.
  bool initChannelEvents({
    required void Function(ChannelEvent) onEvent,
  }) {
    return _engine.initChannelEvents(onEvent: onEvent);
  }

  /// Enable a messaging channel.
  int enableChannel(String name, String configJson) {
    if (state != EngineStatus.ready) return -1;
    return _engine.enableChannel(name, configJson);
  }

  /// Disable a messaging channel.
  int disableChannel(String name) {
    if (state != EngineStatus.ready) return -1;
    return _engine.disableChannel(name);
  }

  // ─── Automation (cron + heartbeat) ──────────────────

  Map<String, dynamic> cronList() {
    if (state != EngineStatus.ready) return {'jobs': [], 'count': 0};
    return _engine.cronList();
  }

  Map<String, dynamic> cronCreate(String jobJson) {
    if (state != EngineStatus.ready) return {'success': false};
    return _engine.cronCreate(jobJson);
  }

  Map<String, dynamic> cronDelete(String jobId) {
    if (state != EngineStatus.ready) return {'success': false};
    return _engine.cronDelete(jobId);
  }

  Map<String, dynamic> cronToggle(String jobId, bool enabled) {
    if (state != EngineStatus.ready) return {'success': false};
    return _engine.cronToggle(jobId, enabled);
  }

  Map<String, dynamic> triggerGeofence(String jobId) {
    if (state != EngineStatus.ready) return {'success': false};
    return _engine.triggerGeofence(jobId);
  }

  Map<String, dynamic> heartbeatSetInterval(int minutes) {
    if (state != EngineStatus.ready) return {'success': false};
    return _engine.heartbeatSetInterval(minutes);
  }

  Map<String, dynamic> heartbeatSetEnabled(bool enabled) {
    if (state != EngineStatus.ready) return {'success': false};
    return _engine.heartbeatSetEnabled(enabled);
  }

  Map<String, dynamic> heartbeatGetStatus() {
    if (state != EngineStatus.ready) return {'enabled': false};
    return _engine.heartbeatGetStatus();
  }

  String heartbeatGetPrompt() {
    if (state != EngineStatus.ready) return '';
    return _engine.heartbeatGetPrompt();
  }

  Map<String, dynamic> heartbeatSetPrompt(String markdown) {
    if (state != EngineStatus.ready) return {'success': false};
    return _engine.heartbeatSetPrompt(markdown);
  }

  // ─── Skills ──────────────────────────────────────────

  Map<String, dynamic> listSkills() {
    if (state != EngineStatus.ready) return {'skills': [], 'count': 0};
    return _engine.listSkills();
  }

  Map<String, dynamic> installSkill(String repo) {
    if (state != EngineStatus.ready) return {'success': false};
    return _engine.installSkill(repo);
  }

  Map<String, dynamic> uninstallSkill(String name) {
    if (state != EngineStatus.ready) return {'success': false};
    return _engine.uninstallSkill(name);
  }

  /// Skips skills that already exist (user may have edited them).
  Future<void> _copyBundledSkills(String workspacePath) async {
    const bundledSkills = [
      'skill-creator',
      'morning-briefing',
      'meeting-prep',
      'travel-assistant',
      'health-check',
    ];

    final skillsDir = Directory('$workspacePath/skills');
    if (!skillsDir.existsSync()) {
      skillsDir.createSync(recursive: true);
    }

    for (final name in bundledSkills) {
      final targetDir = Directory('$workspacePath/skills/$name');
      final targetFile = File('${targetDir.path}/SKILL.md');
      if (targetFile.existsSync()) continue; // Don't overwrite user edits

      try {
        final content =
            await rootBundle.loadString('assets/skills/$name/SKILL.md');
        targetDir.createSync(recursive: true);
        targetFile.writeAsStringSync(content);
      } catch (e) {
        // Asset missing — skip silently
      }
    }
  }

  @override
  void dispose() {
    if (state == EngineStatus.ready) {
      _engine.stop();
    }
    super.dispose();
  }
}

final engineProvider =
    StateNotifierProvider<EngineNotifier, EngineStatus>((ref) {
  return EngineNotifier();
});
