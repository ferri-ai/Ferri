import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../capabilities/capability_registry.dart';
import '../capabilities/models/capability.dart';
import '../capabilities/permission_manager.dart';
import '../native/permissions_channel.dart';
import '../native/alarm_channel.dart';
import '../native/app_launcher_channel.dart';
import '../native/calendar_channel.dart';
import '../native/camera_channel.dart';
import '../native/clipboard_channel.dart';
import '../native/contacts_channel.dart';
import '../native/device_info_channel.dart';
import '../native/health_channel.dart';
import '../native/location_channel.dart';
import '../native/notification_channel.dart';
import '../native/reminder_channel.dart';
import '../native/bluetooth_channel.dart';
import '../native/calllog_channel.dart';
import '../native/notification_listener_channel.dart';
import '../native/sms_channel.dart';
import '../native/accessibility_channel.dart';
import '../native/phone_dial_channel.dart';
import '../native/email_channel.dart';
import '../native/maps_channel.dart';
import '../native/sharing_channel.dart';
import '../native/audio_channel.dart';
import '../native/wifi_channel.dart';
import '../native/sensor_channel.dart';
import '../native/files_channel.dart';
import '../native/nfc_channel.dart';
import '../native/geofence_channel.dart';
import '../native/usage_stats_channel.dart';
import '../native/voice_channel.dart';
import 'engine_provider.dart';
import 'settings_provider.dart';

/// Tracks enabled/disabled state for each capability.
class CapabilitiesState {
  final Map<String, CapabilityStatus> statuses;

  const CapabilitiesState({this.statuses = const {}});

  CapabilityStatus statusOf(String capabilityId) {
    return statuses[capabilityId] ?? CapabilityStatus.disabled;
  }

  CapabilitiesState copyWith({Map<String, CapabilityStatus>? statuses}) {
    return CapabilitiesState(statuses: statuses ?? this.statuses);
  }
}

class CapabilitiesNotifier extends StateNotifier<CapabilitiesState> {
  final SharedPreferences _prefs;
  final EngineNotifier _engine;

  CapabilitiesNotifier(this._prefs, this._engine)
      : super(const CapabilitiesState()) {
    _registerToolHandlers();
    _load();
  }

  /// Register Dart-side tool handlers with the engine.
  /// These are the callbacks that ToolDispatcher routes requests to.
  void _registerToolHandlers() {
    // Calendar tools → CalendarChannel
    _engine.toolHandlers['calendar_read_events'] =
        CalendarChannel.handleToolCall;
    _engine.toolHandlers['calendar_create_event'] =
        CalendarChannel.handleToolCall;
    _engine.toolHandlers['calendar_update_event'] =
        CalendarChannel.handleToolCall;
    _engine.toolHandlers['calendar_delete_event'] =
        CalendarChannel.handleToolCall;

    // Contacts tools → ContactsChannel
    _engine.toolHandlers['contacts_search'] =
        ContactsChannel.handleToolCall;
    _engine.toolHandlers['contacts_read'] =
        ContactsChannel.handleToolCall;
    _engine.toolHandlers['contacts_create'] =
        ContactsChannel.handleToolCall;
    _engine.toolHandlers['contacts_update'] =
        ContactsChannel.handleToolCall;
    _engine.toolHandlers['contacts_delete'] =
        ContactsChannel.handleToolCall;

    // Location tools → LocationChannel
    _engine.toolHandlers['location_get_current'] =
        LocationChannel.handleToolCall;
    _engine.toolHandlers['location_geocode'] =
        LocationChannel.handleToolCall;
    _engine.toolHandlers['location_reverse_geocode'] =
        LocationChannel.handleToolCall;

    // SMS tools → SmsChannel
    _engine.toolHandlers['sms_read'] = SmsChannel.handleToolCall;
    _engine.toolHandlers['sms_send'] = SmsChannel.handleToolCall;

    // Call Log tools → CallLogChannel
    _engine.toolHandlers['calllog_read'] = CallLogChannel.handleToolCall;
    _engine.toolHandlers['calllog_summary'] = CallLogChannel.handleToolCall;

    // Bluetooth tools → BluetoothChannel
    _engine.toolHandlers['bluetooth_get_state'] = BluetoothChannel.handleToolCall;
    _engine.toolHandlers['bluetooth_list_paired'] = BluetoothChannel.handleToolCall;
    _engine.toolHandlers['bluetooth_scan'] = BluetoothChannel.handleToolCall;

    // Notification Listener tools → NotificationListenerChannel
    _engine.toolHandlers['notification_listener_read'] =
        NotificationListenerChannel.handleToolCall;
    _engine.toolHandlers['notification_listener_active'] =
        NotificationListenerChannel.handleToolCall;

    // Usage Stats tools → UsageStatsChannel
    _engine.toolHandlers['usage_stats_query'] = UsageStatsChannel.handleToolCall;
    _engine.toolHandlers['usage_stats_current'] = UsageStatsChannel.handleToolCall;

    // Accessibility tools → AccessibilityChannel
    _engine.toolHandlers['accessibility_read_screen'] =
        AccessibilityChannel.handleToolCall;
    _engine.toolHandlers['accessibility_tap'] =
        AccessibilityChannel.handleToolCall;
    _engine.toolHandlers['accessibility_scroll'] =
        AccessibilityChannel.handleToolCall;
    _engine.toolHandlers['accessibility_type'] =
        AccessibilityChannel.handleToolCall;

    // Notification tools → NotificationChannel
    _engine.toolHandlers['notification_send'] =
        NotificationChannel.handleToolCall;
    _engine.toolHandlers['notification_schedule'] =
        NotificationChannel.handleToolCall;

    // Camera tools → CameraChannel
    _engine.toolHandlers['camera_capture_photo'] =
        CameraChannel.handleToolCall;
    _engine.toolHandlers['camera_pick_image'] =
        CameraChannel.handleToolCall;

    // Voice tools → VoiceChannel
    _engine.toolHandlers['voice_speak'] = VoiceChannel.handleToolCall;
    _engine.toolHandlers['voice_listen'] = VoiceChannel.handleToolCall;

    // Health tools → HealthChannel
    _engine.toolHandlers['health_check_availability'] =
        HealthChannel.handleToolCall;
    _engine.toolHandlers['health_read_steps'] =
        HealthChannel.handleToolCall;
    _engine.toolHandlers['health_read_heart_rate'] =
        HealthChannel.handleToolCall;
    _engine.toolHandlers['health_read_data'] =
        HealthChannel.handleToolCall;

    // Alarm tools → AlarmChannel
    _engine.toolHandlers['alarm_set'] = AlarmChannel.handleToolCall;
    _engine.toolHandlers['alarm_set_timer'] = AlarmChannel.handleToolCall;
    _engine.toolHandlers['alarm_show'] = AlarmChannel.handleToolCall;

    // Reminder tools → ReminderChannel
    _engine.toolHandlers['reminder_set'] = ReminderChannel.handleToolCall;
    _engine.toolHandlers['reminder_list'] = ReminderChannel.handleToolCall;
    _engine.toolHandlers['reminder_cancel'] = ReminderChannel.handleToolCall;

    // Clipboard tools → ClipboardChannel
    _engine.toolHandlers['clipboard_read'] = ClipboardChannel.handleToolCall;
    _engine.toolHandlers['clipboard_write'] = ClipboardChannel.handleToolCall;

    // App Launcher tools → AppLauncherChannel
    _engine.toolHandlers['app_launch'] = AppLauncherChannel.handleToolCall;
    _engine.toolHandlers['app_list'] = AppLauncherChannel.handleToolCall;

    // Phone Dial tools → PhoneDialChannel
    _engine.toolHandlers['phone_dial'] = PhoneDialChannel.handleToolCall;

    // Email Compose tools → EmailChannel
    _engine.toolHandlers['email_compose'] = EmailChannel.handleToolCall;

    // Maps tools → MapsChannel
    _engine.toolHandlers['maps_open'] = MapsChannel.handleToolCall;
    _engine.toolHandlers['maps_navigate'] = MapsChannel.handleToolCall;

    // Sharing tools → SharingChannel
    _engine.toolHandlers['share_text'] = SharingChannel.handleToolCall;
    _engine.toolHandlers['share_file'] = SharingChannel.handleToolCall;

    // Audio tools → AudioChannel
    _engine.toolHandlers['audio_get_volume'] = AudioChannel.handleToolCall;
    _engine.toolHandlers['audio_set_volume'] = AudioChannel.handleToolCall;
    _engine.toolHandlers['audio_get_mode'] = AudioChannel.handleToolCall;
    _engine.toolHandlers['audio_set_mode'] = AudioChannel.handleToolCall;
    _engine.toolHandlers['audio_media_control'] = AudioChannel.handleToolCall;

    // Wi-Fi tools → WifiChannel
    _engine.toolHandlers['wifi_get_info'] = WifiChannel.handleToolCall;
    _engine.toolHandlers['wifi_scan'] = WifiChannel.handleToolCall;
    _engine.toolHandlers['wifi_get_state'] = WifiChannel.handleToolCall;

    // Sensor tools → SensorChannel
    _engine.toolHandlers['sensor_list'] = SensorChannel.handleToolCall;
    _engine.toolHandlers['sensor_read'] = SensorChannel.handleToolCall;

    // Files tools → FilesChannel
    _engine.toolHandlers['files_list'] = FilesChannel.handleToolCall;
    _engine.toolHandlers['files_read'] = FilesChannel.handleToolCall;
    _engine.toolHandlers['files_write'] = FilesChannel.handleToolCall;
    _engine.toolHandlers['files_pick'] = FilesChannel.handleToolCall;
    _engine.toolHandlers['files_delete'] = FilesChannel.handleToolCall;

    // NFC tools → NfcChannel
    _engine.toolHandlers['nfc_read'] = NfcChannel.handleToolCall;
    _engine.toolHandlers['nfc_write'] = NfcChannel.handleToolCall;

    // Geofence tools → GeofenceChannel (with cron job + native fence sync)
    GeofenceChannel.init(_engine);
    _engine.toolHandlers['geofence_create'] = _handleGeofenceCreate;
    _engine.toolHandlers['geofence_list'] = GeofenceChannel.handleToolCall;
    _engine.toolHandlers['geofence_remove'] = _handleGeofenceRemove;

    // Device Info tools → DeviceInfoChannel
    _engine.toolHandlers['device_info'] = DeviceInfoChannel.handleToolCall;
    _engine.toolHandlers['device_battery'] = DeviceInfoChannel.handleToolCall;
    _engine.toolHandlers['device_storage'] = DeviceInfoChannel.handleToolCall;
    _engine.toolHandlers['device_connectivity'] =
        DeviceInfoChannel.handleToolCall;
    _engine.toolHandlers['device_flashlight'] =
        DeviceInfoChannel.handleToolCall;
    _engine.toolHandlers['device_brightness'] =
        DeviceInfoChannel.handleToolCall;
  }

  /// Geofence create: geocode → cron job → native GMS fence.
  Future<String> _handleGeofenceCreate(
      String toolName, Map<String, dynamic> params) async {
    // Step 1: Geocode location_name → lat/lng if no coordinates provided
    var resolvedParams = Map<String, dynamic>.from(params);
    if (resolvedParams['latitude'] == null &&
        resolvedParams['location_name'] != null) {
      final geocodeResult = await LocationChannel.handleToolCall(
        'location_geocode',
        {'address': resolvedParams['location_name']},
      );
      final decoded = jsonDecode(geocodeResult);
      if (decoded is Map && decoded.containsKey('results')) {
        final results = decoded['results'] as List?;
        if (results != null && results.isNotEmpty) {
          resolvedParams['latitude'] = results[0]['latitude'];
          resolvedParams['longitude'] = results[0]['longitude'];
        } else {
          return jsonEncode({
            'error': 'geocode_failed',
            'message':
                'Could not find coordinates for: ${resolvedParams['location_name']}',
          });
        }
      } else if (decoded is List && decoded.isNotEmpty) {
        resolvedParams['latitude'] = decoded[0]['latitude'];
        resolvedParams['longitude'] = decoded[0]['longitude'];
      } else {
        return jsonEncode({
          'error': 'geocode_failed',
          'message':
              'Could not find coordinates for: ${resolvedParams['location_name']}',
        });
      }
    }

    final lat = (resolvedParams['latitude'] as num?)?.toDouble();
    final lng = (resolvedParams['longitude'] as num?)?.toDouble();
    final radius =
        (resolvedParams['radius'] as num?)?.toInt() ?? 100;
    final trigger =
        resolvedParams['trigger'] as String? ?? 'enter';
    final name = resolvedParams['location_name'] as String? ??
        resolvedParams['name'] as String? ??
        'Geofence';

    if (lat == null || lng == null) {
      return jsonEncode({
        'error': 'missing_coordinates',
        'message': 'latitude and longitude are required',
      });
    }

    // Step 2: Create cron job with schedule.kind = 'geofence'
    final jobJson = jsonEncode({
      'name': name,
      'schedule': {
        'kind': 'geofence',
        'lat': lat,
        'lng': lng,
        'radius_meters': radius,
        'trigger': trigger,
      },
      'payload': {
        'kind': 'agent_turn',
        'message':
            'Geofence "$name" triggered ($trigger at $lat,$lng, ${radius}m radius)',
        'deliver': true,
        'channel': 'chat',
        'to': 'automation',
      },
    });

    final cronResult = _engine.cronCreate(jobJson);
    if (cronResult['success'] != true) {
      return jsonEncode({
        'error': 'cron_create_failed',
        'message': 'Failed to create geofence automation job',
      });
    }

    final cronJob = cronResult['job'] as Map<String, dynamic>?;
    final cronJobId = cronJob?['id'] as String? ?? '';

    // Step 3: Create native GMS fence with id = cronJobId
    final nativeResult = await GeofenceChannel.createNativeFence({
      'id': cronJobId,
      'latitude': lat,
      'longitude': lng,
      'radius': radius,
      'trigger': trigger,
    });

    final nativeDecoded = jsonDecode(nativeResult);
    if (nativeDecoded is Map && nativeDecoded['success'] != true) {
      // Roll back cron job if native fence failed
      _engine.cronDelete(cronJobId);
      return nativeResult;
    }

    return jsonEncode({
      'success': true,
      'id': cronJobId,
      'latitude': lat,
      'longitude': lng,
      'radius': radius,
      'trigger': trigger,
      'name': name,
    });
  }

  /// Geofence remove: delete both native GMS fence and cron job.
  Future<String> _handleGeofenceRemove(
      String toolName, Map<String, dynamic> params) async {
    final id = params['id'] as String?;
    if (id == null) {
      return jsonEncode({
        'error': 'missing_id',
        'message': 'id is required',
      });
    }

    // Remove native GMS fence
    final nativeResult =
        await GeofenceChannel.handleToolCall('geofence_remove', params);

    // Delete cron job
    _engine.cronDelete(id);

    return nativeResult;
  }

  /// Load persisted capability states from SharedPreferences.
  void _load() {
    final statuses = <String, CapabilityStatus>{};
    for (final cap in CapabilityRegistry.allCapabilities) {
      final enabled = _prefs.getBool('cap_${cap.id}_enabled') ?? false;
      statuses[cap.id] = enabled
          ? CapabilityStatus.enabled
          : CapabilityStatus.disabled;
    }
    state = CapabilitiesState(statuses: statuses);
  }

  /// Enable a capability: request permissions, register tools with Go engine.
  /// Returns true if successfully enabled.
  Future<bool> enable(String capabilityId) async {
    final cap = CapabilityRegistry.byId(capabilityId);
    if (cap == null) return false;

    if (cap.privileged) {
      return _enablePrivileged(cap);
    }

    // Standard runtime permission flow
    final granted = await PermissionManager.requestPermissions(cap.permissions);
    if (!granted) {
      debugPrint('[Capabilities] Permission denied for ${cap.displayName}');
      _setStatus(capabilityId, CapabilityStatus.permissionRequired);
      return false;
    }

    _registerAndPersist(cap);
    return true;
  }

  Future<bool> _enablePrivileged(Capability cap) async {
    final granted = await _checkPrivilegedAccess(cap.id);
    if (!granted) {
      debugPrint(
          '[Capabilities] Privileged access not granted for ${cap.displayName}, opening settings');
      _setStatus(cap.id, CapabilityStatus.permissionRequired);
      // Open the system settings screen so the user can grant access
      if (cap.settingsRoute != null) {
        await PermissionsChannel.openSettings(cap.settingsRoute!);
      }
      return false;
    }

    _registerAndPersist(cap);
    return true;
  }

  Future<bool> checkPrivilegedAccess(String capabilityId) async {
    return _checkPrivilegedAccess(capabilityId);
  }

  Future<bool> _checkPrivilegedAccess(String capabilityId) async {
    switch (capabilityId) {
      case 'notification_listener':
        return PermissionsChannel.checkNotificationListener();
      case 'usage_stats':
        return PermissionsChannel.checkUsageStats();
      case 'accessibility':
        return PermissionsChannel.checkAccessibilityService();
      default:
        return false;
    }
  }

  Future<bool> openPrivilegedSettings(String capabilityId) async {
    final cap = CapabilityRegistry.byId(capabilityId);
    if (cap == null || cap.settingsRoute == null) return false;
    return PermissionsChannel.openSettings(cap.settingsRoute!);
  }

  void _registerAndPersist(Capability cap) {
    _engine.registerCapabilityTools(cap);
    _prefs.setBool('cap_${cap.id}_enabled', true);
    _setStatus(cap.id, CapabilityStatus.enabled);
    debugPrint('[Capabilities] Enabled ${cap.displayName}');
  }

  /// Disable a capability: unregister tools from Go engine.
  Future<void> disable(String capabilityId) async {
    final cap = CapabilityRegistry.byId(capabilityId);
    if (cap == null) return;

    // Unregister each tool from the Go engine
    _engine.unregisterCapabilityTools(cap);

    // Persist and update state
    await _prefs.setBool('cap_${cap.id}_enabled', false);
    _setStatus(capabilityId, CapabilityStatus.disabled);
    debugPrint('[Capabilities] Disabled ${cap.displayName}');
  }

  /// Re-register all enabled capabilities with the engine.
  /// Called after engine (re-)initialization.
  void registerAllEnabled() {
    for (final cap in CapabilityRegistry.allCapabilities) {
      if (state.statusOf(cap.id) == CapabilityStatus.enabled) {
        _engine.registerCapabilityTools(cap);
      }
    }
  }

  void _setStatus(String id, CapabilityStatus status) {
    final updated = Map<String, CapabilityStatus>.from(state.statuses);
    updated[id] = status;
    state = state.copyWith(statuses: updated);
  }
}

final capabilitiesProvider =
    StateNotifierProvider<CapabilitiesNotifier, CapabilitiesState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final engine = ref.watch(engineProvider.notifier);
  return CapabilitiesNotifier(prefs, engine);
});
