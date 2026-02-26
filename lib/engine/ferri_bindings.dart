import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// ─── Existing FFI signatures ────────────────────────────────

typedef FerriInitNative = Int32 Function(Pointer<Utf8> configJson);
typedef FerriInitDart = int Function(Pointer<Utf8> configJson);

typedef FerriInitDartApiNative = Void Function(Pointer<Void> postCObject);
typedef FerriInitDartApiDart = void Function(Pointer<Void> postCObject);

typedef FerriSetTokenPortNative = Void Function(Int64 port);
typedef FerriSetTokenPortDart = void Function(int port);

typedef FerriSendMessageNative = Int32 Function(
    Pointer<Utf8> message, Pointer<Utf8> sessionId);
typedef FerriSendMessageDart = int Function(
    Pointer<Utf8> message, Pointer<Utf8> sessionId);

typedef FerriStopNative = Void Function();
typedef FerriStopDart = void Function();

// ─── Platform tool dispatch FFI signatures ──────────────────

typedef FerriSetToolDispatchPortNative = Void Function(Int64 port);
typedef FerriSetToolDispatchPortDart = void Function(int port);

typedef FerriRegisterPlatformToolNative = Int32 Function(
    Pointer<Utf8> name, Pointer<Utf8> desc, Pointer<Utf8> schema);
typedef FerriRegisterPlatformToolDart = int Function(
    Pointer<Utf8> name, Pointer<Utf8> desc, Pointer<Utf8> schema);

typedef FerriUnregisterPlatformToolNative = Int32 Function(Pointer<Utf8> name);
typedef FerriUnregisterPlatformToolDart = int Function(Pointer<Utf8> name);

typedef FerriToolResultNative = Void Function(
    Pointer<Utf8> requestId, Pointer<Utf8> resultJson);
typedef FerriToolResultDart = void Function(
    Pointer<Utf8> requestId, Pointer<Utf8> resultJson);

// ─── Channel management FFI signatures ──────────────────

typedef FerriSetChannelEventPortNative = Void Function(Int64 port);
typedef FerriSetChannelEventPortDart = void Function(int port);

typedef FerriEnableChannelNative = Int32 Function(
    Pointer<Utf8> name, Pointer<Utf8> configJson);
typedef FerriEnableChannelDart = int Function(
    Pointer<Utf8> name, Pointer<Utf8> configJson);

typedef FerriDisableChannelNative = Int32 Function(Pointer<Utf8> name);
typedef FerriDisableChannelDart = int Function(Pointer<Utf8> name);

typedef FerriGetChannelStatusNative = Pointer<Utf8> Function();
typedef FerriGetChannelStatusDart = Pointer<Utf8> Function();

typedef FerriFreeStringNative = Void Function(Pointer<Utf8> s);
typedef FerriFreeStringDart = void Function(Pointer<Utf8> s);

// ─── Automation (cron + heartbeat) FFI signatures ──────────

typedef FerriCronListNative = Pointer<Utf8> Function();
typedef FerriCronListDart = Pointer<Utf8> Function();

typedef FerriCronCreateNative = Pointer<Utf8> Function(Pointer<Utf8> jobJson);
typedef FerriCronCreateDart = Pointer<Utf8> Function(Pointer<Utf8> jobJson);

typedef FerriCronDeleteNative = Pointer<Utf8> Function(Pointer<Utf8> jobId);
typedef FerriCronDeleteDart = Pointer<Utf8> Function(Pointer<Utf8> jobId);

typedef FerriCronToggleNative = Pointer<Utf8> Function(Pointer<Utf8> jobId, Int32 enabled);
typedef FerriCronToggleDart = Pointer<Utf8> Function(Pointer<Utf8> jobId, int enabled);

typedef FerriTriggerGeofenceNative = Pointer<Utf8> Function(Pointer<Utf8> jobId);
typedef FerriTriggerGeofenceDart = Pointer<Utf8> Function(Pointer<Utf8> jobId);

typedef FerriHeartbeatSetEnabledNative = Pointer<Utf8> Function(Int32 enabled);
typedef FerriHeartbeatSetEnabledDart = Pointer<Utf8> Function(int enabled);

typedef FerriHeartbeatSetIntervalNative = Pointer<Utf8> Function(Int32 minutes);
typedef FerriHeartbeatSetIntervalDart = Pointer<Utf8> Function(int minutes);

typedef FerriHeartbeatGetStatusNative = Pointer<Utf8> Function();
typedef FerriHeartbeatGetStatusDart = Pointer<Utf8> Function();

typedef FerriHeartbeatGetPromptNative = Pointer<Utf8> Function();
typedef FerriHeartbeatGetPromptDart = Pointer<Utf8> Function();

typedef FerriHeartbeatSetPromptNative = Pointer<Utf8> Function(Pointer<Utf8> markdown);
typedef FerriHeartbeatSetPromptDart = Pointer<Utf8> Function(Pointer<Utf8> markdown);

// ─── Skills FFI signatures ──────────────────────────────
typedef FerriListSkillsNative = Pointer<Utf8> Function();
typedef FerriListSkillsDart = Pointer<Utf8> Function();

typedef FerriInstallSkillNative = Pointer<Utf8> Function(Pointer<Utf8> repo);
typedef FerriInstallSkillDart = Pointer<Utf8> Function(Pointer<Utf8> repo);

typedef FerriUninstallSkillNative = Pointer<Utf8> Function(Pointer<Utf8> name);
typedef FerriUninstallSkillDart = Pointer<Utf8> Function(Pointer<Utf8> name);

// ─── History FFI signatures ──────────────────────────────
typedef FerriGetHistoryNative = Pointer<Utf8> Function(Pointer<Utf8> sessionKey);
typedef FerriGetHistoryDart = Pointer<Utf8> Function(Pointer<Utf8> sessionKey);

typedef FerriClearSessionNative = Pointer<Utf8> Function(Pointer<Utf8> sessionKey);
typedef FerriClearSessionDart = Pointer<Utf8> Function(Pointer<Utf8> sessionKey);

class FerriBindings {
  late final DynamicLibrary _lib;

  // Existing bindings
  late final FerriInitDart ferriInit;
  late final FerriInitDartApiDart ferriInitDartApi;
  late final FerriSetTokenPortDart ferriSetTokenPort;
  late final FerriSendMessageDart ferriSendMessage;
  late final FerriStopDart ferriStop;

  // Platform tool dispatch bindings
  late final FerriSetToolDispatchPortDart ferriSetToolDispatchPort;
  late final FerriRegisterPlatformToolDart ferriRegisterPlatformTool;
  late final FerriUnregisterPlatformToolDart ferriUnregisterPlatformTool;
  late final FerriToolResultDart ferriToolResult;

  // Channel management bindings
  late final FerriSetChannelEventPortDart ferriSetChannelEventPort;
  late final FerriEnableChannelDart ferriEnableChannel;
  late final FerriDisableChannelDart ferriDisableChannel;
  late final FerriGetChannelStatusDart ferriGetChannelStatus;
  late final FerriFreeStringDart ferriFreeString;

  // History binding
  late final FerriGetHistoryDart ferriGetHistory;
  late final FerriClearSessionDart ferriClearSession;

  // Skills bindings
  late final FerriListSkillsDart ferriListSkills;
  late final FerriInstallSkillDart ferriInstallSkill;
  late final FerriUninstallSkillDart ferriUninstallSkill;

  // Automation bindings
  late final FerriCronListDart ferriCronList;
  late final FerriCronCreateDart ferriCronCreate;
  late final FerriCronDeleteDart ferriCronDelete;
  late final FerriCronToggleDart ferriCronToggle;
  late final FerriTriggerGeofenceDart ferriTriggerGeofence;
  late final FerriHeartbeatSetEnabledDart ferriHeartbeatSetEnabled;
  late final FerriHeartbeatSetIntervalDart ferriHeartbeatSetInterval;
  late final FerriHeartbeatGetStatusDart ferriHeartbeatGetStatus;
  late final FerriHeartbeatGetPromptDart ferriHeartbeatGetPrompt;
  late final FerriHeartbeatSetPromptDart ferriHeartbeatSetPrompt;

  FerriBindings() {
    _lib = Platform.isAndroid
        ? DynamicLibrary.open('libferri.so')
        : DynamicLibrary.process(); // iOS: statically linked (future)

    ferriInit = _lib
        .lookupFunction<FerriInitNative, FerriInitDart>('ferri_init');

    ferriInitDartApi = _lib
        .lookupFunction<FerriInitDartApiNative, FerriInitDartApiDart>(
            'ferri_init_dart_api');

    ferriSetTokenPort = _lib
        .lookupFunction<FerriSetTokenPortNative, FerriSetTokenPortDart>(
            'ferri_set_token_port');

    ferriSendMessage = _lib
        .lookupFunction<FerriSendMessageNative, FerriSendMessageDart>(
            'ferri_send_message');

    ferriStop = _lib
        .lookupFunction<FerriStopNative, FerriStopDart>('ferri_stop');

    ferriSetToolDispatchPort = _lib
        .lookupFunction<FerriSetToolDispatchPortNative,
            FerriSetToolDispatchPortDart>('ferri_set_tool_dispatch_port');

    ferriRegisterPlatformTool = _lib
        .lookupFunction<FerriRegisterPlatformToolNative,
            FerriRegisterPlatformToolDart>('ferri_register_platform_tool');

    ferriUnregisterPlatformTool = _lib
        .lookupFunction<FerriUnregisterPlatformToolNative,
            FerriUnregisterPlatformToolDart>('ferri_unregister_platform_tool');

    ferriToolResult = _lib
        .lookupFunction<FerriToolResultNative, FerriToolResultDart>(
            'ferri_tool_result');

    ferriSetChannelEventPort = _lib
        .lookupFunction<FerriSetChannelEventPortNative,
            FerriSetChannelEventPortDart>('ferri_set_channel_event_port');

    ferriEnableChannel = _lib
        .lookupFunction<FerriEnableChannelNative, FerriEnableChannelDart>(
            'ferri_enable_channel');

    ferriDisableChannel = _lib
        .lookupFunction<FerriDisableChannelNative, FerriDisableChannelDart>(
            'ferri_disable_channel');

    ferriGetChannelStatus = _lib
        .lookupFunction<FerriGetChannelStatusNative,
            FerriGetChannelStatusDart>('ferri_get_channel_status');

    ferriFreeString = _lib
        .lookupFunction<FerriFreeStringNative, FerriFreeStringDart>(
            'ferri_free_string');

    ferriGetHistory = _lib
        .lookupFunction<FerriGetHistoryNative, FerriGetHistoryDart>('ferri_get_history');
    ferriClearSession = _lib
        .lookupFunction<FerriClearSessionNative, FerriClearSessionDart>('ferri_clear_session');

    ferriListSkills = _lib
        .lookupFunction<FerriListSkillsNative, FerriListSkillsDart>('ferri_list_skills');
    ferriInstallSkill = _lib
        .lookupFunction<FerriInstallSkillNative, FerriInstallSkillDart>('ferri_install_skill');
    ferriUninstallSkill = _lib
        .lookupFunction<FerriUninstallSkillNative, FerriUninstallSkillDart>('ferri_uninstall_skill');

    ferriCronList = _lib
        .lookupFunction<FerriCronListNative, FerriCronListDart>('ferri_cron_list');
    ferriCronCreate = _lib
        .lookupFunction<FerriCronCreateNative, FerriCronCreateDart>('ferri_cron_create');
    ferriCronDelete = _lib
        .lookupFunction<FerriCronDeleteNative, FerriCronDeleteDart>('ferri_cron_delete');
    ferriCronToggle = _lib
        .lookupFunction<FerriCronToggleNative, FerriCronToggleDart>('ferri_cron_toggle');
    ferriTriggerGeofence = _lib
        .lookupFunction<FerriTriggerGeofenceNative, FerriTriggerGeofenceDart>('ferri_trigger_geofence');
    ferriHeartbeatSetEnabled = _lib
        .lookupFunction<FerriHeartbeatSetEnabledNative, FerriHeartbeatSetEnabledDart>('ferri_heartbeat_set_enabled');
    ferriHeartbeatSetInterval = _lib
        .lookupFunction<FerriHeartbeatSetIntervalNative, FerriHeartbeatSetIntervalDart>('ferri_heartbeat_set_interval');
    ferriHeartbeatGetStatus = _lib
        .lookupFunction<FerriHeartbeatGetStatusNative, FerriHeartbeatGetStatusDart>('ferri_heartbeat_get_status');
    ferriHeartbeatGetPrompt = _lib
        .lookupFunction<FerriHeartbeatGetPromptNative, FerriHeartbeatGetPromptDart>('ferri_heartbeat_get_prompt');
    ferriHeartbeatSetPrompt = _lib
        .lookupFunction<FerriHeartbeatSetPromptNative, FerriHeartbeatSetPromptDart>('ferri_heartbeat_set_prompt');
  }
}
