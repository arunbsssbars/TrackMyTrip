import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Result of an anti-abuse rate limit evaluation.
class RateLimitResult {
  final bool isAllowed;
  final int retryAfterSeconds;
  final String? message;

  const RateLimitResult({
    required this.isAllowed,
    this.retryAfterSeconds = 0,
    this.message,
  });

  static const allowed = RateLimitResult(isAllowed: true);

  factory RateLimitResult.blocked({
    required int retryAfterSeconds,
    required String message,
  }) {
    return RateLimitResult(
      isAllowed: false,
      retryAfterSeconds: retryAfterSeconds,
      message: message,
    );
  }
}

/// Centralized Anti-Abuse & Resource Protection Service
///
/// Defends against:
/// 1. Room code brute-forcing and scraping (max 5/min, 30s penalty on 3 consecutive failures).
/// 2. Cloudinary / cloud media storage drain (max 10/min, max 100/day per device).
/// 3. SOS / Proximity alert floods (max 3 per 30s).
/// 4. Rapid GPS broadcast spam.
class AntiAbuseRateLimiterService {
  // --- Room Join Anti-Brute-Force Tracker ---
  static const int maxRoomJoinAttemptsPerMinute = 5;
  static const int consecutiveFailuresThreshold = 3;
  static const int penaltyLockoutSeconds = 30;

  static final Queue<DateTime> _roomJoinAttempts = Queue<DateTime>();
  static int _consecutiveFailedRoomJoins = 0;
  static DateTime? _roomJoinLockoutUntil;

  // --- Media Upload Anti-Exhaustion Tracker ---
  static const int maxMediaUploadsPerMinute = 10;
  static const int maxMediaUploadsPerDay = 100;

  static final Queue<DateTime> _mediaUploadsMinute = Queue<DateTime>();
  static final Queue<DateTime> _mediaUploadsDay = Queue<DateTime>();

  // --- SOS / Proximity Alert Flood Tracker ---
  static const int maxEmergencyAlertsPerWindow = 3;
  static final Queue<DateTime> _emergencyAlerts = Queue<DateTime>();

  // =================================================================
  // 1. Room Code Brute-Force Defense
  // =================================================================

  /// Checks if a room join attempt is permitted.
  static RateLimitResult checkRoomJoinAllowed({DateTime? now}) {
    final current = now ?? DateTime.now();

    // Check active penalty lockout
    if (_roomJoinLockoutUntil != null) {
      if (current.isBefore(_roomJoinLockoutUntil!)) {
        final remaining = _roomJoinLockoutUntil!.difference(current).inSeconds;
        final seconds = remaining > 0 ? remaining : 1;
        return RateLimitResult.blocked(
          retryAfterSeconds: seconds,
          message: 'Too many failed attempts. Security cooldown active for $seconds seconds.',
        );
      } else {
        // Lockout expired
        _roomJoinLockoutUntil = null;
        _consecutiveFailedRoomJoins = 0;
      }
    }

    _pruneQueue(_roomJoinAttempts, const Duration(minutes: 1), current);

    if (_roomJoinAttempts.length >= maxRoomJoinAttemptsPerMinute) {
      final oldest = _roomJoinAttempts.first;
      final retryIn = 60 - current.difference(oldest).inSeconds;
      final seconds = retryIn > 0 ? retryIn : 1;
      return RateLimitResult.blocked(
        retryAfterSeconds: seconds,
        message: 'Join rate limit reached. Please wait $seconds seconds before trying again.',
      );
    }

    return RateLimitResult.allowed;
  }

  /// Records the outcome of a room join attempt.
  static void recordRoomJoinAttempt({required bool success, DateTime? now}) {
    final current = now ?? DateTime.now();
    _roomJoinAttempts.add(current);

    if (success) {
      _consecutiveFailedRoomJoins = 0;
      _roomJoinLockoutUntil = null;
    } else {
      _consecutiveFailedRoomJoins++;
      if (_consecutiveFailedRoomJoins >= consecutiveFailuresThreshold) {
        _roomJoinLockoutUntil = current.add(const Duration(seconds: penaltyLockoutSeconds));
        if (kDebugMode) {
          debugPrint(
            '[AntiAbuse] Room join locked out for $penaltyLockoutSeconds seconds '
            'after $_consecutiveFailedRoomJoins consecutive failures.',
          );
        }
      }
    }
  }

  // =================================================================
  // 2. Media Upload Quota Protection
  // =================================================================

  /// Checks if a media upload is permitted under anti-abuse limits.
  static RateLimitResult checkMediaUploadAllowed({DateTime? now}) {
    final current = now ?? DateTime.now();

    // 1. Check 1-minute burst limit
    _pruneQueue(_mediaUploadsMinute, const Duration(minutes: 1), current);
    if (_mediaUploadsMinute.length >= maxMediaUploadsPerMinute) {
      final oldest = _mediaUploadsMinute.first;
      final retryIn = 60 - current.difference(oldest).inSeconds;
      final seconds = retryIn > 0 ? retryIn : 1;
      return RateLimitResult.blocked(
        retryAfterSeconds: seconds,
        message: 'Upload burst limit reached (max $maxMediaUploadsPerMinute/min). Wait $seconds seconds.',
      );
    }

    // 2. Check 24-hour volume cap
    _pruneQueue(_mediaUploadsDay, const Duration(hours: 24), current);
    if (_mediaUploadsDay.length >= maxMediaUploadsPerDay) {
      final oldest = _mediaUploadsDay.first;
      final retryInHours = 24 - current.difference(oldest).inHours;
      final hours = retryInHours > 0 ? retryInHours : 1;
      return RateLimitResult.blocked(
        retryAfterSeconds: hours * 3600,
        message: 'Daily upload limit reached ($maxMediaUploadsPerDay/day). Resets in ~$hours hours.',
      );
    }

    return RateLimitResult.allowed;
  }

  /// Records a successful media upload to track device consumption.
  static void recordMediaUpload({DateTime? now}) {
    final current = now ?? DateTime.now();
    _mediaUploadsMinute.add(current);
    _mediaUploadsDay.add(current);
  }

  // =================================================================
  // 3. SOS / Emergency Alert Flood Protection
  // =================================================================

  /// Checks if an SOS or proximity broadcast is allowed.
  static RateLimitResult checkEmergencyAlertAllowed({DateTime? now}) {
    final current = now ?? DateTime.now();
    _pruneQueue(_emergencyAlerts, const Duration(seconds: 30), current);

    if (_emergencyAlerts.length >= maxEmergencyAlertsPerWindow) {
      final oldest = _emergencyAlerts.first;
      final retryIn = 30 - current.difference(oldest).inSeconds;
      final seconds = retryIn > 0 ? retryIn : 1;
      return RateLimitResult.blocked(
        retryAfterSeconds: seconds,
        message: 'Emergency alert limit reached. Please wait $seconds seconds.',
      );
    }

    return RateLimitResult.allowed;
  }

  /// Records an emergency alert broadcast.
  static void recordEmergencyAlert({DateTime? now}) {
    _emergencyAlerts.add(now ?? DateTime.now());
  }

  // =================================================================
  // Internal Utilities & Testing
  // =================================================================

  static void _pruneQueue(Queue<DateTime> queue, Duration window, DateTime now) {
    while (queue.isNotEmpty && now.difference(queue.first) > window) {
      queue.removeFirst();
    }
  }

  /// Resets all in-memory trackers (primarily for unit tests).
  @visibleForTesting
  static void resetForTesting() {
    _roomJoinAttempts.clear();
    _consecutiveFailedRoomJoins = 0;
    _roomJoinLockoutUntil = null;
    _mediaUploadsMinute.clear();
    _mediaUploadsDay.clear();
    _emergencyAlerts.clear();
  }
}
