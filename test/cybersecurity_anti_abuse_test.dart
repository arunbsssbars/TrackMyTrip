import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/services/anti_abuse_rate_limiter_service.dart';
import 'package:trackmytrip/core/services/cloudinary_service.dart';
import 'package:trackmytrip/core/services/live_location_tracker_service.dart';

void main() {
  group('Cybersecurity & Anti-Abuse Test Suite', () {
    setUp(() {
      AntiAbuseRateLimiterService.resetForTesting();
    });

    group('AntiAbuseRateLimiterService - Room Join Brute Force Defense', () {
      test('permits up to 5 join attempts in a 60-second window', () {
        final start = DateTime(2026, 10, 10, 12, 0, 0);

        for (int i = 0; i < 5; i++) {
          final res = AntiAbuseRateLimiterService.checkRoomJoinAllowed(
            now: start.add(Duration(seconds: i * 2)),
          );
          expect(res.isAllowed, isTrue);
          AntiAbuseRateLimiterService.recordRoomJoinAttempt(
            success: true,
            now: start.add(Duration(seconds: i * 2)),
          );
        }

        // 6th attempt should be blocked
        final blockedRes = AntiAbuseRateLimiterService.checkRoomJoinAllowed(
          now: start.add(const Duration(seconds: 15)),
        );
        expect(blockedRes.isAllowed, isFalse);
        expect(blockedRes.retryAfterSeconds, greaterThan(0));
      });

      test('triggers penalty lockout after 3 consecutive failed attempts', () {
        final start = DateTime(2026, 10, 10, 12, 0, 0);

        // Attempt 1 fails
        AntiAbuseRateLimiterService.recordRoomJoinAttempt(success: false, now: start);
        expect(AntiAbuseRateLimiterService.checkRoomJoinAllowed(now: start).isAllowed, isTrue);

        // Attempt 2 fails
        AntiAbuseRateLimiterService.recordRoomJoinAttempt(
          success: false,
          now: start.add(const Duration(seconds: 2)),
        );
        expect(
          AntiAbuseRateLimiterService.checkRoomJoinAllowed(
            now: start.add(const Duration(seconds: 3)),
          ).isAllowed,
          isTrue,
        );

        // Attempt 3 fails -> triggers lockout
        AntiAbuseRateLimiterService.recordRoomJoinAttempt(
          success: false,
          now: start.add(const Duration(seconds: 4)),
        );
        final lockoutRes = AntiAbuseRateLimiterService.checkRoomJoinAllowed(
          now: start.add(const Duration(seconds: 5)),
        );
        expect(lockoutRes.isAllowed, isFalse);
        expect(lockoutRes.message, contains('Security cooldown active'));
        expect(lockoutRes.retryAfterSeconds, greaterThanOrEqualTo(25));

        // After 31 seconds, lockout expires
        final unblockedRes = AntiAbuseRateLimiterService.checkRoomJoinAllowed(
          now: start.add(const Duration(seconds: 36)),
        );
        expect(unblockedRes.isAllowed, isTrue);
      });

      test('successful room join resets consecutive failure counter', () {
        final start = DateTime(2026, 10, 10, 12, 0, 0);

        // 2 failures
        AntiAbuseRateLimiterService.recordRoomJoinAttempt(success: false, now: start);
        AntiAbuseRateLimiterService.recordRoomJoinAttempt(
          success: false,
          now: start.add(const Duration(seconds: 2)),
        );

        // 1 success resets counter
        AntiAbuseRateLimiterService.recordRoomJoinAttempt(
          success: true,
          now: start.add(const Duration(seconds: 4)),
        );

        // Subsequent failure should not trigger lockout
        AntiAbuseRateLimiterService.recordRoomJoinAttempt(
          success: false,
          now: start.add(const Duration(seconds: 6)),
        );
        final check = AntiAbuseRateLimiterService.checkRoomJoinAllowed(
          now: start.add(const Duration(seconds: 7)),
        );
        expect(check.isAllowed, isTrue);
      });
    });

    group('AntiAbuseRateLimiterService - Media Upload & Alert Limits', () {
      test('enforces max 10 media uploads per minute', () {
        final start = DateTime(2026, 10, 10, 12, 0, 0);

        for (int i = 0; i < 10; i++) {
          final res = AntiAbuseRateLimiterService.checkMediaUploadAllowed(
            now: start.add(Duration(seconds: i)),
          );
          expect(res.isAllowed, isTrue);
          AntiAbuseRateLimiterService.recordMediaUpload(now: start.add(Duration(seconds: i)));
        }

        // 11th upload should be blocked
        final blocked = AntiAbuseRateLimiterService.checkMediaUploadAllowed(
          now: start.add(const Duration(seconds: 15)),
        );
        expect(blocked.isAllowed, isFalse);
        expect(blocked.message, contains('Upload burst limit'));
      });

      test('enforces max 3 emergency SOS alerts per 30 seconds', () {
        final start = DateTime(2026, 10, 10, 12, 0, 0);

        for (int i = 0; i < 3; i++) {
          final res = AntiAbuseRateLimiterService.checkEmergencyAlertAllowed(
            now: start.add(Duration(seconds: i * 2)),
          );
          expect(res.isAllowed, isTrue);
          AntiAbuseRateLimiterService.recordEmergencyAlert(
            now: start.add(Duration(seconds: i * 2)),
          );
        }

        // 4th alert blocked
        final blocked = AntiAbuseRateLimiterService.checkEmergencyAlertAllowed(
          now: start.add(const Duration(seconds: 10)),
        );
        expect(blocked.isAllowed, isFalse);
        expect(blocked.message, contains('Emergency alert limit reached'));
      });
    });

    group('CloudinaryService - Magic Byte Inspection', () {
      test('accepts valid JPEG magic bytes (FF D8 FF)', () {
        final jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]);
        expect(CloudinaryService.isValidImageBytes(jpegBytes), isTrue);
      });

      test('accepts valid PNG magic bytes (89 50 4E 47 0D 0A 1A 0A)', () {
        final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]);
        expect(CloudinaryService.isValidImageBytes(pngBytes), isTrue);
      });

      test('accepts valid WebP magic bytes (RIFF....WEBP)', () {
        final webpBytes = Uint8List.fromList([
          0x52, 0x49, 0x46, 0x46, // RIFF
          0x20, 0x00, 0x00, 0x00, // Size
          0x57, 0x45, 0x42, 0x50, // WEBP
        ]);
        expect(CloudinaryService.isValidImageBytes(webpBytes), isTrue);
      });

      test('accepts valid GIF magic bytes (GIF89a)', () {
        final gifBytes = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00]);
        expect(CloudinaryService.isValidImageBytes(gifBytes), isTrue);
      });

      test('rejects malicious shell scripts disguised as images', () {
        final scriptBytes = Uint8List.fromList('#!/bin/bash\nrm -rf /'.codeUnits);
        expect(CloudinaryService.isValidImageBytes(scriptBytes), isFalse);
      });

      test('rejects HTML/XSS payloads disguised as images', () {
        final htmlBytes = Uint8List.fromList('<html><script>alert(1)</script></html>'.codeUnits);
        expect(CloudinaryService.isValidImageBytes(htmlBytes), isFalse);
      });

      test('rejects Windows PE executable headers (MZ)', () {
        final exeBytes = Uint8List.fromList([0x4D, 0x5A, 0x90, 0x00, 0x03, 0x00, 0x00, 0x00]);
        expect(CloudinaryService.isValidImageBytes(exeBytes), isFalse);
      });

      test('rejects truncated/empty byte lists', () {
        expect(CloudinaryService.isValidImageBytes([]), isFalse);
        expect(CloudinaryService.isValidImageBytes([0xFF, 0xD8]), isFalse);
      });
    });

    group('LiveLocationTrackerNotifier - Coordinate & Flood Defense', () {
      test('validates coordinate boundaries accurately', () {
        expect(LiveLocationTrackerNotifier.isValidCoordinate(28.6139, 77.2090), isTrue);
        expect(LiveLocationTrackerNotifier.isValidCoordinate(-33.8688, 151.2093), isTrue);
        expect(LiveLocationTrackerNotifier.isValidCoordinate(0.0, 0.0), isTrue);

        // Out of bounds latitude
        expect(LiveLocationTrackerNotifier.isValidCoordinate(90.1, 77.0), isFalse);
        expect(LiveLocationTrackerNotifier.isValidCoordinate(-90.1, 77.0), isFalse);

        // Out of bounds longitude
        expect(LiveLocationTrackerNotifier.isValidCoordinate(28.0, 180.1), isFalse);
        expect(LiveLocationTrackerNotifier.isValidCoordinate(28.0, -180.1), isFalse);
      });

      test('enforces minimum 2.0s throttle interval between RTDB broadcasts', () {
        expect(
          LiveLocationTrackerNotifier.minRtdbBroadcastInterval,
          const Duration(milliseconds: 2000),
        );
      });
    });
  });
}
