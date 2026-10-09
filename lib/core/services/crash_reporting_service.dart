import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

/// Models a structured in-app crash or unhandled error report
class CrashReport {
  final String id;
  final String message;
  final String stackTrace;
  final String environment;
  final DateTime timestamp;
  final bool isFatal;
  final Map<String, dynamic> customKeys;

  const CrashReport({
    required this.id,
    required this.message,
    required this.stackTrace,
    required this.environment,
    required this.timestamp,
    this.isFatal = false,
    this.customKeys = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'message': message,
    'stackTrace': stackTrace,
    'environment': environment,
    'timestamp': timestamp.toIso8601String(),
    'isFatal': isFatal,
    'customKeys': customKeys,
  };

  factory CrashReport.fromJson(Map<String, dynamic> json) => CrashReport(
    id: json['id'] as String? ?? 'unknown',
    message: json['message'] as String? ?? 'Unknown error',
    stackTrace: json['stackTrace'] as String? ?? '',
    environment: json['environment'] as String? ?? 'development',
    timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    isFatal: json['isFatal'] as bool? ?? false,
    customKeys: (json['customKeys'] as Map<String, dynamic>?) ?? {},
  );
}

/// Global Crash Reporting & Error Telemetry Service
class CrashReportingService {
  static const String _prefsKeyCrashes = 'telemetry_crash_reports_v1';
  static const int _maxStoredCrashes = 50;

  static final List<CrashReport> _inMemoryCrashes = [];
  static final Map<String, dynamic> _customTags = {};

  /// Sets a custom contextual tag (e.g. currentUserId, activeTripId)
  static void setCustomKey(String key, dynamic value) {
    _customTags[key] = value;
  }

  /// Initializes crash persistence and loads cached crash telemetry
  static Future<void> initialize({SharedPreferences? prefs}) async {
    try {
      final sp = prefs ?? await SharedPreferences.getInstance();
      final rawList = sp.getStringList(_prefsKeyCrashes) ?? [];
      _inMemoryCrashes.clear();
      for (final jsonStr in rawList) {
        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          _inMemoryCrashes.add(CrashReport.fromJson(map));
        } catch (_) {}
      }
    } catch (e) {
      AppLogger.debug('Crash service init notice: $e');
    }
  }

  /// Records an exception or crash into telemetry and persistent log
  static Future<void> recordError(
    dynamic error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    final errorMsg = error?.toString() ?? 'Unknown Error';
    final stackStr = stack?.toString() ?? StackTrace.current.toString();

    AppLogger.error('Captured Crash Telemetry: $errorMsg ${reason != null ? "($reason)" : ""}', error, stack);

    final report = CrashReport(
      id: 'crash_${DateTime.now().millisecondsSinceEpoch}',
      message: reason != null ? '$reason: $errorMsg' : errorMsg,
      stackTrace: stackStr.length > 2000 ? stackStr.substring(0, 2000) : stackStr,
      environment: kReleaseMode ? 'production' : 'development',
      timestamp: DateTime.now(),
      isFatal: fatal,
      customKeys: Map<String, dynamic>.from(_customTags),
    );

    _inMemoryCrashes.insert(0, report);
    if (_inMemoryCrashes.length > _maxStoredCrashes) {
      _inMemoryCrashes.removeRange(_maxStoredCrashes, _inMemoryCrashes.length);
    }

    try {
      final sp = await SharedPreferences.getInstance();
      final encodedList = _inMemoryCrashes.map((r) => jsonEncode(r.toJson())).toList();
      await sp.setStringList(_prefsKeyCrashes, encodedList);
    } catch (_) {}
  }

  /// Retrieves all recorded crash reports for operational triage
  static List<CrashReport> getCrashReports() => List.unmodifiable(_inMemoryCrashes);

  /// Clears stored crash reports
  static Future<void> clearCrashReports() async {
    _inMemoryCrashes.clear();
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_prefsKeyCrashes);
    } catch (_) {}
  }
}
