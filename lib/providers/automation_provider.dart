import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/ferri_engine.dart';
import '../native/geofence_channel.dart';
import 'channels_provider.dart';
import 'chat_provider.dart';
import 'engine_provider.dart';

// ─── Data Models ──────────────────────────────────────────────

class CronScheduleModel {
  final String kind;
  final int? atMs;
  final int? everyMs;
  final String? expr;
  final double? lat;
  final double? lng;
  final int? radiusMeters;
  final String? trigger;

  const CronScheduleModel({
    required this.kind,
    this.atMs,
    this.everyMs,
    this.expr,
    this.lat,
    this.lng,
    this.radiusMeters,
    this.trigger,
  });

  factory CronScheduleModel.fromJson(Map<String, dynamic> json) {
    return CronScheduleModel(
      kind: json['kind'] as String,
      atMs: json['atMs'] as int?,
      everyMs: json['everyMs'] as int?,
      expr: json['expr'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      radiusMeters: json['radius_meters'] as int?,
      trigger: json['trigger'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kind': kind,
      if (atMs != null) 'atMs': atMs,
      if (everyMs != null) 'everyMs': everyMs,
      if (expr != null && expr!.isNotEmpty) 'expr': expr,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (radiusMeters != null) 'radius_meters': radiusMeters,
      if (trigger != null) 'trigger': trigger,
    };
  }

  String get displayText {
    switch (kind) {
      case 'at':
        if (atMs == null) return 'One-time';
        final dt = DateTime.fromMillisecondsSinceEpoch(atMs!);
        final month = _monthName(dt.month);
        final hour = dt.hour;
        final minute = dt.minute.toString().padLeft(2, '0');
        final amPm = hour >= 12 ? 'PM' : 'AM';
        final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        return '$month ${dt.day}, ${dt.year} at $hour12:$minute $amPm';

      case 'every':
        if (everyMs == null) return 'Recurring';
        final ms = everyMs!;
        if (ms >= 3600000) {
          final hours = ms ~/ 3600000;
          return 'Every ${hours}h';
        } else if (ms >= 60000) {
          final minutes = ms ~/ 60000;
          return 'Every ${minutes}m';
        } else {
          final seconds = ms ~/ 1000;
          return 'Every ${seconds}s';
        }

      case 'cron':
        if (expr == null || expr!.isEmpty) return 'Cron';
        return _humanizeCron(expr!);

      case 'geofence':
        final t = trigger ?? 'enter';
        final r = radiusMeters ?? 0;
        return '$t zone (${r}m)';

      default:
        return kind;
    }
  }

  static String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }

  static String _humanizeCron(String expr) {
    final parts = expr.trim().split(RegExp(r'\s+'));
    if (parts.length != 5) return expr;

    final minute = parts[0];
    final hour = parts[1];
    final dom = parts[2];
    final month = parts[3];
    final dow = parts[4];

    // "*/N * * * *" → "Every N min"
    if (minute.startsWith('*/') &&
        hour == '*' &&
        dom == '*' &&
        month == '*' &&
        dow == '*') {
      final n = minute.substring(2);
      return 'Every $n min';
    }

    // Fixed hour patterns
    final hourInt = int.tryParse(hour);
    final minuteInt = int.tryParse(minute);
    if (hourInt != null && minuteInt != null && dom == '*' && month == '*') {
      final hour12 = hourInt == 0 ? 12 : (hourInt > 12 ? hourInt - 12 : hourInt);
      final amPm = hourInt >= 12 ? 'PM' : 'AM';
      final timeStr = '$hour12:${minuteInt.toString().padLeft(2, '0')} $amPm';

      // "M H * * *" → "Daily at H:MM AM/PM"
      if (dow == '*') {
        return 'Daily at $timeStr';
      }

      // "M H * * 1-5" → "Mon-Fri at H:MM AM/PM"
      if (dow == '1-5') {
        return 'Mon-Fri at $timeStr';
      }

      // "M H * * 0,6" → "Weekends at H:MM AM/PM"
      if (dow == '0,6') {
        return 'Weekends at $timeStr';
      }

      // Other dow patterns: show day range
      return '$timeStr ($dow)';
    }

    return expr;
  }
}

class CronJobStateModel {
  final int? nextRunAtMs;
  final int? lastRunAtMs;
  final String? lastStatus;
  final String? lastError;

  const CronJobStateModel({
    this.nextRunAtMs,
    this.lastRunAtMs,
    this.lastStatus,
    this.lastError,
  });

  factory CronJobStateModel.fromJson(Map<String, dynamic> json) {
    return CronJobStateModel(
      nextRunAtMs: json['nextRunAtMs'] as int?,
      lastRunAtMs: json['lastRunAtMs'] as int?,
      lastStatus: json['lastStatus'] as String?,
      lastError: json['lastError'] as String?,
    );
  }
}

class CronJobModel {
  final String id;
  final String name;
  final bool enabled;
  final CronScheduleModel schedule;
  final CronJobStateModel state;
  final int createdAtMs;

  const CronJobModel({
    required this.id,
    required this.name,
    required this.enabled,
    required this.schedule,
    required this.state,
    required this.createdAtMs,
  });

  factory CronJobModel.fromJson(Map<String, dynamic> json) {
    return CronJobModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
      schedule: CronScheduleModel.fromJson(
        json['schedule'] as Map<String, dynamic>? ?? {},
      ),
      state: CronJobStateModel.fromJson(
        json['state'] as Map<String, dynamic>? ?? {},
      ),
      createdAtMs: json['createdAtMs'] as int? ?? 0,
    );
  }

  bool get isGeofence => schedule.kind == 'geofence';
  bool get isScheduled => !isGeofence;
}

class HeartbeatStatus {
  final bool enabled;
  final int intervalMinutes;

  const HeartbeatStatus({
    this.enabled = false,
    this.intervalMinutes = 30,
  });

  factory HeartbeatStatus.fromJson(Map<String, dynamic> json) {
    return HeartbeatStatus(
      enabled: json['enabled'] as bool? ?? false,
      intervalMinutes: json['interval_minutes'] as int? ?? 30,
    );
  }
}

// ─── AutomationState ──────────────────────────────────────────

class AutomationState {
  final List<CronJobModel> jobs;
  final HeartbeatStatus heartbeat;
  final String heartbeatPrompt;
  final bool loading;

  const AutomationState({
    this.jobs = const [],
    this.heartbeat = const HeartbeatStatus(),
    this.heartbeatPrompt = '',
    this.loading = false,
  });

  AutomationState copyWith({
    List<CronJobModel>? jobs,
    HeartbeatStatus? heartbeat,
    String? heartbeatPrompt,
    bool? loading,
  }) {
    return AutomationState(
      jobs: jobs ?? this.jobs,
      heartbeat: heartbeat ?? this.heartbeat,
      heartbeatPrompt: heartbeatPrompt ?? this.heartbeatPrompt,
      loading: loading ?? this.loading,
    );
  }

  List<CronJobModel> get scheduledJobs =>
      jobs.where((j) => j.isScheduled).toList();

  List<CronJobModel> get geofenceJobs =>
      jobs.where((j) => j.isGeofence).toList();
}

// ─── AutomationNotifier ───────────────────────────────────────

class AutomationNotifier extends StateNotifier<AutomationState> {
  final Ref _ref;

  AutomationNotifier(this._ref) : super(const AutomationState()) {
    // Auto-refresh when engine becomes ready (it initializes lazily on first
    // chat message, so we may miss the initial refresh from initState).
    _ref.listen<EngineStatus>(engineProvider, (prev, next) {
      if (next == EngineStatus.ready && prev != EngineStatus.ready) {
        // Ensure the channel event port is registered so cron/heartbeat
        // results can reach Dart even when no messaging channels are enabled.
        _ref.read(channelsProvider.notifier).initEvents();

        // Load persisted chat history: prefer JSONL log (includes tool calls),
        // fall back to Go engine history (4-8 msgs) for pre-JSONL upgrades.
        final chatNotifier = _ref.read(chatProvider.notifier);
        final chatLog = _ref.read(chatLogServiceProvider);
        if (chatLog != null && chatLog.hasLog()) {
          chatNotifier.loadFromChatLog();
        } else {
          final history = _ref.read(engineProvider.notifier).getHistory();
          chatNotifier.loadFromHistory(history);
        }

        // Restore persisted heartbeat state
        _restoreHeartbeatState();

        refresh();
      }
    });
  }

  EngineNotifier get _engine => _ref.read(engineProvider.notifier);

  /// Restore heartbeat enabled/interval from SharedPreferences on engine start.
  Future<void> _restoreHeartbeatState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEnabled = prefs.getBool('heartbeat_enabled') ?? false;
    final savedInterval = prefs.getInt('heartbeat_interval_minutes') ?? 30;

    if (savedInterval != 30) {
      _engine.heartbeatSetInterval(savedInterval);
    }
    if (savedEnabled) {
      _engine.heartbeatSetEnabled(true);
    }
    debugPrint('[AutomationNotifier] restored heartbeat: enabled=$savedEnabled interval=$savedInterval');
  }

  /// Persist heartbeat state to SharedPreferences.
  Future<void> _saveHeartbeatState({bool? enabled, int? interval}) async {
    final prefs = await SharedPreferences.getInstance();
    if (enabled != null) await prefs.setBool('heartbeat_enabled', enabled);
    if (interval != null) await prefs.setInt('heartbeat_interval_minutes', interval);
  }

  /// Fetch all cron jobs and heartbeat status from the Go engine.
  void refresh() {
    debugPrint('[AutomationNotifier] refresh() called');
    state = state.copyWith(loading: true);

    try {
      // Fetch cron jobs
      final cronResult = _engine.cronList();
      debugPrint('[AutomationNotifier] cronList result: $cronResult');
      final jobsList = cronResult['jobs'] as List<dynamic>? ?? [];
      final jobs = jobsList
          .map((j) => CronJobModel.fromJson(j as Map<String, dynamic>))
          .toList();
      debugPrint('[AutomationNotifier] parsed ${jobs.length} jobs');

      // Fetch heartbeat status
      final hbStatus = _engine.heartbeatGetStatus();
      final heartbeat = HeartbeatStatus.fromJson(hbStatus);

      // Fetch heartbeat prompt
      final prompt = _engine.heartbeatGetPrompt();

      state = state.copyWith(
        jobs: jobs,
        heartbeat: heartbeat,
        heartbeatPrompt: prompt,
        loading: false,
      );
    } catch (e) {
      debugPrint('[AutomationNotifier] refresh() error: $e');
      state = state.copyWith(loading: false);
    }
  }

  /// Create a new cron job. For geofence jobs, also registers a native GMS fence.
  Future<void> createJob({
    required String name,
    required CronScheduleModel schedule,
    required String message,
    bool deliver = false,
    String channel = 'chat',
    String to = 'automation',
  }) async {
    final jobJson = jsonEncode({
      'name': name,
      'schedule': schedule.toJson(),
      'payload': {
        'kind': 'agent_turn',
        'message': message,
        'deliver': deliver,
        'channel': channel,
        'to': to,
      },
    });

    final result = _engine.cronCreate(jobJson);
    if (result['success'] == true) {
      // For geofence jobs, also create the native GMS fence
      if (schedule.kind == 'geofence' &&
          schedule.lat != null &&
          schedule.lng != null) {
        final cronJob = result['job'] as Map<String, dynamic>?;
        final cronJobId = cronJob?['id'] as String? ?? '';
        await GeofenceChannel.createNativeFence({
          'id': cronJobId,
          'latitude': schedule.lat,
          'longitude': schedule.lng,
          'radius': schedule.radiusMeters ?? 100,
          'trigger': schedule.trigger ?? 'enter',
        });
      }
      refresh();
    }
  }

  /// Delete a cron job by ID. For geofence jobs, also removes the native GMS fence.
  Future<void> deleteJob(String jobId) async {
    // Check if this is a geofence job before deleting
    final isGeofence =
        state.jobs.any((j) => j.id == jobId && j.isGeofence);

    final result = _engine.cronDelete(jobId);
    if (result['success'] == true) {
      if (isGeofence) {
        await GeofenceChannel.handleToolCall(
            'geofence_remove', {'id': jobId});
      }
      refresh();
    }
  }

  /// Toggle a cron job's enabled state.
  void toggleJob(String jobId, bool enabled) {
    final result = _engine.cronToggle(jobId, enabled);
    if (result['success'] == true) {
      refresh();
    }
  }

  /// Set the heartbeat interval in minutes. Restarts if currently running.
  void setHeartbeatInterval(int minutes) {
    final result = _engine.heartbeatSetInterval(minutes);
    if (result['success'] == true) {
      _saveHeartbeatState(interval: minutes);
      // If currently running, restart to pick up new interval
      if (state.heartbeat.enabled) {
        _engine.heartbeatSetEnabled(false);
        _engine.heartbeatSetEnabled(true);
      }
      refresh();
    }
  }

  /// Enable or disable the heartbeat.
  void setHeartbeatEnabled(bool enabled) {
    final result = _engine.heartbeatSetEnabled(enabled);
    if (result['success'] == true) {
      _saveHeartbeatState(enabled: enabled);
      refresh();
    }
  }

  /// Update the heartbeat prompt markdown.
  void setHeartbeatPrompt(String markdown) {
    final result = _engine.heartbeatSetPrompt(markdown);
    if (result['success'] == true) {
      state = state.copyWith(heartbeatPrompt: markdown);
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────

final automationProvider =
    StateNotifierProvider<AutomationNotifier, AutomationState>((ref) {
  return AutomationNotifier(ref);
});
