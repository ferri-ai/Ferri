/// Health capability — provides tools for reading health and fitness data
/// from Google Health Connect (Android) or Apple HealthKit (iOS).
///
/// Channel: none (pure-Dart via `health` package)
/// Kotlin handler: none
///
/// Tools:
/// - `health_read_steps` — Read step count for a date range
/// - `health_read_heart_rate` — Read heart rate data for a date range
/// - `health_read_data` — Read arbitrary health data types (weight, glucose, etc.)
/// - `health_check_availability` — Check if Health Connect / HealthKit is available
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Handles health data operations using the health package.
/// Reads from Google Health Connect (Android) / Apple HealthKit (iOS).
class HealthChannel {
  static final _health = Health();
  static bool _configured = false;

  HealthChannel._();

  static Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[HealthChannel] handleToolCall: $toolName');

    switch (toolName) {
      case 'health_read_steps':
        return _readSteps(params);
      case 'health_read_heart_rate':
        return _readHeartRate(params);
      case 'health_read_data':
        return _readData(params);
      case 'health_check_availability':
        return _checkAvailability();
      default:
        throw Exception('Unknown health tool: $toolName');
    }
  }

  /// Check if Health Connect (Android) or HealthKit (iOS) is available.
  static Future<String> _checkAvailability() async {
    await _ensureConfigured();

    if (Platform.isAndroid) {
      final status = await _health.getHealthConnectSdkStatus();
      final available =
          status == HealthConnectSdkStatus.sdkAvailable;
      return jsonEncode({
        'available': available,
        'status': status?.name ?? 'unknown',
        'platform': 'android',
        'message': available
            ? 'Health Connect is available'
            : 'Health Connect is not installed. The user needs to install it from the Play Store.',
      });
    }

    // iOS — HealthKit is always available on supported devices
    return jsonEncode({
      'available': true,
      'platform': 'ios',
      'message': 'HealthKit is available',
    });
  }

  /// Read step count for a date range.
  static Future<String> _readSteps(Map<String, dynamic> params) async {
    await _ensureConfigured();

    final now = DateTime.now();
    final startTime = params['start_date'] != null
        ? DateTime.parse(params['start_date'] as String)
        : DateTime(now.year, now.month, now.day); // default: today midnight
    final endTime = params['end_date'] != null
        ? DateTime.parse(params['end_date'] as String)
        : now;

    // Check if permissions already granted before trying the launcher
    final hasPerms = await _health.hasPermissions(
      [HealthDataType.STEPS],
      permissions: [HealthDataAccess.READ],
    );

    if (hasPerms != true) {
      try {
        final authorized = await _health.requestAuthorization(
          [HealthDataType.STEPS],
          permissions: [HealthDataAccess.READ],
        );
        if (!authorized) {
          return jsonEncode({
            'success': false,
            'error': 'Health data access not authorized. Grant Ferri access in Health Connect settings.',
          });
        }
      } catch (e) {
        return jsonEncode({
          'success': false,
          'error': 'Health permission request failed: $e. Grant Ferri access in Health Connect settings.',
        });
      }
    }

    final steps = await _health.getTotalStepsInInterval(
      startTime,
      endTime,
      includeManualEntry: true,
    );

    return jsonEncode({
      'success': true,
      'steps': steps ?? 0,
      'start_date': startTime.toIso8601String(),
      'end_date': endTime.toIso8601String(),
    });
  }

  /// Read heart rate data for a date range.
  static Future<String> _readHeartRate(Map<String, dynamic> params) async {
    await _ensureConfigured();

    final now = DateTime.now();
    final startTime = params['start_date'] != null
        ? DateTime.parse(params['start_date'] as String)
        : now.subtract(const Duration(hours: 24));
    final endTime = params['end_date'] != null
        ? DateTime.parse(params['end_date'] as String)
        : now;

    final hasPerms = await _health.hasPermissions(
      [HealthDataType.HEART_RATE],
      permissions: [HealthDataAccess.READ],
    );

    if (hasPerms != true) {
      try {
        final authorized = await _health.requestAuthorization(
          [HealthDataType.HEART_RATE],
          permissions: [HealthDataAccess.READ],
        );
        if (!authorized) {
          return jsonEncode({
            'success': false,
            'error': 'Health data access not authorized. Grant Ferri access in Health Connect settings.',
          });
        }
      } catch (e) {
        return jsonEncode({
          'success': false,
          'error': 'Health permission request failed: $e. Grant Ferri access in Health Connect settings.',
        });
      }
    }

    List<HealthDataPoint> data = await _health.getHealthDataFromTypes(
      types: [HealthDataType.HEART_RATE],
      startTime: startTime,
      endTime: endTime,
      recordingMethodsToFilter: [],
    );

    data = _health.removeDuplicates(data);
    data.sort((a, b) => b.dateTo.compareTo(a.dateTo));

    final readings = data.map((dp) {
      final value = dp.value;
      return {
        'bpm': value is NumericHealthValue ? value.numericValue : null,
        'time': dp.dateFrom.toIso8601String(),
        'source': dp.sourceName,
      };
    }).toList();

    return jsonEncode({
      'success': true,
      'readings': readings,
      'count': readings.length,
      'start_date': startTime.toIso8601String(),
      'end_date': endTime.toIso8601String(),
    });
  }

  /// Read arbitrary health data types.
  static Future<String> _readData(Map<String, dynamic> params) async {
    await _ensureConfigured();

    final typeStr = params['data_type'] as String;
    final healthType = _parseDataType(typeStr);
    if (healthType == null) {
      return jsonEncode({
        'success': false,
        'error': 'Unknown health data type: $typeStr. '
            'Valid types: steps, heart_rate, weight, blood_glucose, '
            'blood_pressure_systolic, blood_pressure_diastolic, '
            'body_temperature, blood_oxygen, sleep_session, workout.',
      });
    }

    final now = DateTime.now();
    final startTime = params['start_date'] != null
        ? DateTime.parse(params['start_date'] as String)
        : now.subtract(const Duration(hours: 24));
    final endTime = params['end_date'] != null
        ? DateTime.parse(params['end_date'] as String)
        : now;
    final limit = params['limit'] as int? ?? 50;

    final hasPerms = await _health.hasPermissions(
      [healthType],
      permissions: [HealthDataAccess.READ],
    );

    if (hasPerms != true) {
      try {
        final authorized = await _health.requestAuthorization(
          [healthType],
          permissions: [HealthDataAccess.READ],
        );
        if (!authorized) {
          return jsonEncode({
            'success': false,
            'error': 'Health data access not authorized. Grant Ferri access in Health Connect settings.',
          });
        }
      } catch (e) {
        return jsonEncode({
          'success': false,
          'error': 'Health permission request failed: $e. Grant Ferri access in Health Connect settings.',
        });
      }
    }

    List<HealthDataPoint> data = await _health.getHealthDataFromTypes(
      types: [healthType],
      startTime: startTime,
      endTime: endTime,
      recordingMethodsToFilter: [],
    );

    data = _health.removeDuplicates(data);
    data.sort((a, b) => b.dateTo.compareTo(a.dateTo));
    if (data.length > limit) data = data.sublist(0, limit);

    final points = data.map((dp) {
      final value = dp.value;
      return {
        'value': value is NumericHealthValue ? value.numericValue : value.toString(),
        'unit': dp.unit.name,
        'from': dp.dateFrom.toIso8601String(),
        'to': dp.dateTo.toIso8601String(),
        'source': dp.sourceName,
      };
    }).toList();

    return jsonEncode({
      'success': true,
      'data_type': typeStr,
      'points': points,
      'count': points.length,
    });
  }

  /// Parse user-friendly data type string to HealthDataType.
  static HealthDataType? _parseDataType(String type) {
    switch (type.toLowerCase()) {
      case 'steps':
        return HealthDataType.STEPS;
      case 'heart_rate':
        return HealthDataType.HEART_RATE;
      case 'weight':
        return HealthDataType.WEIGHT;
      case 'blood_glucose':
        return HealthDataType.BLOOD_GLUCOSE;
      case 'blood_pressure_systolic':
        return HealthDataType.BLOOD_PRESSURE_SYSTOLIC;
      case 'blood_pressure_diastolic':
        return HealthDataType.BLOOD_PRESSURE_DIASTOLIC;
      case 'body_temperature':
        return HealthDataType.BODY_TEMPERATURE;
      case 'blood_oxygen':
        return HealthDataType.BLOOD_OXYGEN;
      case 'sleep_session':
        return HealthDataType.SLEEP_SESSION;
      case 'workout':
        return HealthDataType.WORKOUT;
      default:
        return null;
    }
  }
}
