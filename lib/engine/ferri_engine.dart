import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'channel_event_stream.dart';
import 'ferri_bindings.dart';
import 'token_stream.dart';
import 'tool_dispatcher.dart';

enum EngineStatus { uninitialized, ready, error }

class FerriEngine {
  late FerriBindings _bindings;
  late TokenStream _tokenStream;
  late ToolDispatcher _toolDispatcher;
  late ChannelEventStream _channelEventStream;
  EngineStatus _status = EngineStatus.uninitialized;

  EngineStatus get status => _status;

  /// Initialize the Go engine and set up NativePorts for token streaming
  /// and tool dispatch.
  void init({
    required String configJson,
    required void Function(TokenMessage) onToken,
  }) {
    debugPrint('[FerriEngine] init: starting');
    _bindings = FerriBindings();
    _tokenStream = TokenStream();
    _toolDispatcher = ToolDispatcher(_bindings);

    // Set up the Dart API for NativePort posting
    _bindings.ferriInitDartApi(NativeApi.postCObject.cast<Void>());

    // Set up token stream
    _tokenStream.listen(onToken: onToken);
    _bindings.ferriSetTokenPort(_tokenStream.port);

    // Set up tool dispatch port
    _toolDispatcher.listen();
    _bindings.ferriSetToolDispatchPort(_toolDispatcher.port);

    // Set up channel event stream
    _channelEventStream = ChannelEventStream();

    // Initialize Go engine
    final configPtr = configJson.toNativeUtf8();
    final result = _bindings.ferriInit(configPtr);
    calloc.free(configPtr);

    if (result == 0) {
      _status = EngineStatus.ready;
      debugPrint('[FerriEngine] init: success (ready)');
    } else {
      _status = EngineStatus.error;
      debugPrint('[FerriEngine] init: FAILED (result=$result)');
    }
  }

  /// Send a message to the Go agent loop.
  void sendMessage(String message, {String sessionId = 'default'}) {
    debugPrint('[FerriEngine] sendMessage: status=$_status msg="${message.length > 50 ? message.substring(0, 50) : message}"');
    if (_status != EngineStatus.ready) {
      debugPrint('[FerriEngine] sendMessage: SKIPPED (not ready)');
      return;
    }

    final msgPtr = message.toNativeUtf8();
    final sidPtr = sessionId.toNativeUtf8();
    _bindings.ferriSendMessage(msgPtr, sidPtr);
    calloc.free(msgPtr);
    calloc.free(sidPtr);
    debugPrint('[FerriEngine] sendMessage: dispatched to Go');
  }

  /// Get session history from the Go engine. Returns list of message maps.
  List<Map<String, dynamic>> getHistory({String sessionKey = 'default'}) {
    if (_status != EngineStatus.ready) return [];

    final keyPtr = sessionKey.toNativeUtf8();
    final resultPtr = _bindings.ferriGetHistory(keyPtr);
    calloc.free(keyPtr);
    final resultStr = resultPtr.toDartString();
    _bindings.ferriFreeString(resultPtr);
    try {
      final list = jsonDecode(resultStr) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Clear a Go engine session (history + summary).
  Map<String, dynamic> clearSession({String sessionKey = 'default'}) {
    if (_status != EngineStatus.ready) return {'success': false};

    final keyPtr = sessionKey.toNativeUtf8();
    final resultPtr = _bindings.ferriClearSession(keyPtr);
    calloc.free(keyPtr);
    final resultStr = resultPtr.toDartString();
    _bindings.ferriFreeString(resultPtr);
    try {
      return jsonDecode(resultStr) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false};
    }
  }

  /// Set whether destructive tools require user approval before execution.
  set requireApproval(bool value) => _toolDispatcher.requireApproval = value;

  /// Set the callback invoked when a destructive tool needs user approval.
  set onApprovalRequired(Future<bool> Function(ToolRequest)? callback) =>
      _toolDispatcher.onApprovalRequired = callback;

  /// Register a platform tool with the Go engine and set up a Dart handler.
  ///
  /// [name] — tool name the LLM will see (e.g. "calendar_read_events")
  /// [description] — human-readable description for the LLM
  /// [schema] — JSON Schema parameters map
  /// [handler] — async callback that executes the tool and returns result JSON
  /// [destructive] — if true, this tool may require user approval
  void registerPlatformTool({
    required String name,
    required String description,
    required Map<String, dynamic> schema,
    required ToolHandler handler,
    bool destructive = false,
  }) {
    if (_status != EngineStatus.ready) {
      debugPrint('[FerriEngine] registerPlatformTool: SKIPPED (not ready)');
      return;
    }

    // Register Dart-side handler so ToolDispatcher can route requests
    _toolDispatcher.registerHandler(name, handler, destructive: destructive);

    // Register with Go so the LLM sees the tool
    final namePtr = name.toNativeUtf8();
    final descPtr = description.toNativeUtf8();
    final schemaPtr = jsonEncode(schema).toNativeUtf8();
    final result = _bindings.ferriRegisterPlatformTool(namePtr, descPtr, schemaPtr);
    calloc.free(namePtr);
    calloc.free(descPtr);
    calloc.free(schemaPtr);

    if (result == 0) {
      debugPrint('[FerriEngine] registerPlatformTool: registered $name');
    } else {
      debugPrint('[FerriEngine] registerPlatformTool: FAILED $name (result=$result)');
      _toolDispatcher.unregisterHandler(name);
    }
  }

  /// Unregister a platform tool from both Go and Dart.
  void unregisterPlatformTool(String name) {
    _toolDispatcher.unregisterHandler(name);

    if (_status != EngineStatus.ready) return;

    final namePtr = name.toNativeUtf8();
    _bindings.ferriUnregisterPlatformTool(namePtr);
    calloc.free(namePtr);
    debugPrint('[FerriEngine] unregisterPlatformTool: unregistered $name');
  }

  /// Set up channel event listener and port.
  /// Returns false if engine isn't ready yet (caller should retry later).
  bool initChannelEvents({
    required void Function(ChannelEvent) onEvent,
  }) {
    if (_status != EngineStatus.ready) return false;
    _channelEventStream.listen(onEvent: onEvent);
    _bindings.ferriSetChannelEventPort(_channelEventStream.port);
    return true;
  }

  /// Enable a messaging channel (telegram, discord, slack).
  /// [configJson] contains channel-specific credentials.
  int enableChannel(String name, String configJson) {
    if (_status != EngineStatus.ready) return -1;

    final namePtr = name.toNativeUtf8();
    final configPtr = configJson.toNativeUtf8();
    final result = _bindings.ferriEnableChannel(namePtr, configPtr);
    calloc.free(namePtr);
    calloc.free(configPtr);

    debugPrint('[FerriEngine] enableChannel: $name → result=$result');
    return result;
  }

  /// Disable a messaging channel.
  int disableChannel(String name) {
    if (_status != EngineStatus.ready) return -1;

    final namePtr = name.toNativeUtf8();
    final result = _bindings.ferriDisableChannel(namePtr);
    calloc.free(namePtr);

    debugPrint('[FerriEngine] disableChannel: $name → result=$result');
    return result;
  }

  /// Get status of all channels as a JSON map.
  Map<String, dynamic> getChannelStatus() {
    if (_status != EngineStatus.ready) return {};

    final resultPtr = _bindings.ferriGetChannelStatus();
    final resultStr = resultPtr.toDartString();
    _bindings.ferriFreeString(resultPtr); // Free C-allocated string
    try {
      return jsonDecode(resultStr) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  // ─── Automation (cron + heartbeat) ──────────────────

  /// List all cron jobs. Returns decoded JSON map with 'jobs' and 'count'.
  Map<String, dynamic> cronList() {
    if (_status != EngineStatus.ready) return {'jobs': [], 'count': 0};

    final resultPtr = _bindings.ferriCronList();
    final resultStr = resultPtr.toDartString();
    _bindings.ferriFreeString(resultPtr);
    try {
      return jsonDecode(resultStr) as Map<String, dynamic>;
    } catch (e) {
      return {'jobs': [], 'count': 0};
    }
  }

  /// Create a cron job from a JSON spec. Returns decoded JSON result.
  Map<String, dynamic> cronCreate(String jobJson) {
    if (_status != EngineStatus.ready) return {'success': false};

    final jobPtr = jobJson.toNativeUtf8();
    final resultPtr = _bindings.ferriCronCreate(jobPtr);
    calloc.free(jobPtr);
    final resultStr = resultPtr.toDartString();
    _bindings.ferriFreeString(resultPtr);
    try {
      return jsonDecode(resultStr) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false};
    }
  }

  /// Delete a cron job by ID. Returns decoded JSON result.
  Map<String, dynamic> cronDelete(String jobId) {
    if (_status != EngineStatus.ready) return {'success': false};

    final idPtr = jobId.toNativeUtf8();
    final resultPtr = _bindings.ferriCronDelete(idPtr);
    calloc.free(idPtr);
    final resultStr = resultPtr.toDartString();
    _bindings.ferriFreeString(resultPtr);
    try {
      return jsonDecode(resultStr) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false};
    }
  }

  /// Toggle a cron job enabled/disabled. Returns decoded JSON result.
  Map<String, dynamic> cronToggle(String jobId, bool enabled) {
    if (_status != EngineStatus.ready) return {'success': false};

    final idPtr = jobId.toNativeUtf8();
    final resultPtr = _bindings.ferriCronToggle(idPtr, enabled ? 1 : 0);
    calloc.free(idPtr);
    final resultStr = resultPtr.toDartString();
    _bindings.ferriFreeString(resultPtr);
    try {
      return jsonDecode(resultStr) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false};
    }
  }

  /// Trigger a geofence-bound job manually. Returns decoded JSON result.
  Map<String, dynamic> triggerGeofence(String jobId) {
    if (_status != EngineStatus.ready) return {'success': false};

    final idPtr = jobId.toNativeUtf8();
    final resultPtr = _bindings.ferriTriggerGeofence(idPtr);
    calloc.free(idPtr);
    final resultStr = resultPtr.toDartString();
    _bindings.ferriFreeString(resultPtr);
    try {
      return jsonDecode(resultStr) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false};
    }
  }

  /// Enable or disable the heartbeat loop. Returns decoded JSON result.
  Map<String, dynamic> heartbeatSetEnabled(bool enabled) {
    if (_status != EngineStatus.ready) return {'success': false};

    final resultPtr = _bindings.ferriHeartbeatSetEnabled(enabled ? 1 : 0);
    final resultStr = resultPtr.toDartString();
    _bindings.ferriFreeString(resultPtr);
    try {
      return jsonDecode(resultStr) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false};
    }
  }

  /// Set the heartbeat interval in minutes. Returns decoded JSON result.
  Map<String, dynamic> heartbeatSetInterval(int minutes) {
    if (_status != EngineStatus.ready) return {'success': false};

    final resultPtr = _bindings.ferriHeartbeatSetInterval(minutes);
    final resultStr = resultPtr.toDartString();
    _bindings.ferriFreeString(resultPtr);
    try {
      return jsonDecode(resultStr) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false};
    }
  }

  /// Get heartbeat status. Returns decoded JSON map.
  Map<String, dynamic> heartbeatGetStatus() {
    if (_status != EngineStatus.ready) return {'enabled': false};

    final resultPtr = _bindings.ferriHeartbeatGetStatus();
    final resultStr = resultPtr.toDartString();
    _bindings.ferriFreeString(resultPtr);
    try {
      return jsonDecode(resultStr) as Map<String, dynamic>;
    } catch (e) {
      return {'enabled': false};
    }
  }

  /// Get the heartbeat prompt markdown. Returns the prompt string.
  String heartbeatGetPrompt() {
    if (_status != EngineStatus.ready) return '';

    final resultPtr = _bindings.ferriHeartbeatGetPrompt();
    final resultStr = resultPtr.toDartString();
    _bindings.ferriFreeString(resultPtr);
    try {
      final decoded = jsonDecode(resultStr) as Map<String, dynamic>;
      return decoded['prompt'] as String? ?? '';
    } catch (e) {
      return '';
    }
  }

  /// Set the heartbeat prompt markdown. Returns decoded JSON result.
  Map<String, dynamic> heartbeatSetPrompt(String markdown) {
    if (_status != EngineStatus.ready) return {'success': false};

    final mdPtr = markdown.toNativeUtf8();
    final resultPtr = _bindings.ferriHeartbeatSetPrompt(mdPtr);
    calloc.free(mdPtr);
    final resultStr = resultPtr.toDartString();
    _bindings.ferriFreeString(resultPtr);
    try {
      return jsonDecode(resultStr) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false};
    }
  }

  // ─── Skills ──────────────────────────────────────────

  /// List all available skills. Returns decoded JSON with 'skills' and 'count'.
  Map<String, dynamic> listSkills() {
    if (_status != EngineStatus.ready) return {'skills': [], 'count': 0};

    final resultPtr = _bindings.ferriListSkills();
    final resultStr = resultPtr.toDartString();
    _bindings.ferriFreeString(resultPtr);
    try {
      return jsonDecode(resultStr) as Map<String, dynamic>;
    } catch (e) {
      return {'skills': [], 'count': 0};
    }
  }

  /// Install a skill from a GitHub repo (e.g. "user/skill-name").
  Map<String, dynamic> installSkill(String repo) {
    if (_status != EngineStatus.ready) return {'success': false};

    final repoPtr = repo.toNativeUtf8();
    final resultPtr = _bindings.ferriInstallSkill(repoPtr);
    calloc.free(repoPtr);
    final resultStr = resultPtr.toDartString();
    _bindings.ferriFreeString(resultPtr);
    try {
      return jsonDecode(resultStr) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false};
    }
  }

  /// Uninstall a skill by name.
  Map<String, dynamic> uninstallSkill(String name) {
    if (_status != EngineStatus.ready) return {'success': false};

    final namePtr = name.toNativeUtf8();
    final resultPtr = _bindings.ferriUninstallSkill(namePtr);
    calloc.free(namePtr);
    final resultStr = resultPtr.toDartString();
    _bindings.ferriFreeString(resultPtr);
    try {
      return jsonDecode(resultStr) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false};
    }
  }

  /// Stop the Go engine and clean up resources.
  void stop() {
    _bindings.ferriStop();
    _tokenStream.dispose();
    _toolDispatcher.dispose();
    _channelEventStream.dispose();
    _status = EngineStatus.uninitialized;
  }
}
