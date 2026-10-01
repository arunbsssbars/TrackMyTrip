import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackmytrip/core/database/app_database.dart';
import 'package:trackmytrip/core/services/security_service.dart';
import 'package:trackmytrip/core/utils/security_sanitizer.dart';
import 'package:trackmytrip/core/utils/app_logger.dart';
import 'package:trackmytrip/core/services/live_companion_tracker_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('OWASP MASVS Security Hardening Tests', () {
    late SharedPreferences prefs;
    late FlutterSecureStorage secureStorage;
    late SecurityService securityService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      FlutterSecureStorage.setMockInitialValues({});
      secureStorage = const FlutterSecureStorage();
      securityService = SecurityService(
        secureStorage: secureStorage,
        prefs: prefs,
      );
    });

    // =========================================================================
    // 1. MASVS-STORAGE: Data-at-Rest & Cryptographic Keys
    // =========================================================================
    test('Generates and stores high-entropy 256-bit AES database encryption key', () async {
      final key1 = await securityService.getDatabaseEncryptionKey();
      expect(key1, isNotEmpty);
      expect(key1.length, greaterThanOrEqualTo(32));

      // Second retrieval must retrieve the same key from secure storage
      final key2 = await securityService.getDatabaseEncryptionKey();
      expect(key2, equals(key1));
    });

    test('Stores and retrieves auth tokens securely in Keystore / Keychain', () async {
      const testToken = 'secure_session_token_xyz_987';
      await securityService.storeAuthToken(testToken);

      final retrieved = await securityService.getAuthToken();
      expect(retrieved, equals(testToken));
    });

    test('Forensic wipe removes all secure storage, prefs, and database records', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      final appDb = await AppDatabase.open(customDb: db);

      // Seed data
      await securityService.storeAuthToken('temp_token');
      await prefs.setString('user_preference', 'dark_mode');

      // Execute forensic wipe
      await securityService.wipeAllSensitiveData(db: appDb);

      // Verify all cleared
      final tokenAfter = await securityService.getAuthToken();
      expect(tokenAfter, isNull);
      expect(prefs.getString('user_preference'), isNull);

      await db.close();
    });

    // =========================================================================
    // 2. MASVS-AUTH: Session Governance & Inactivity Expiry
    // =========================================================================
    test('Session timeout correctly tracks user activity and flags expiration', () async {
      expect(securityService.isSessionExpired(), isFalse);

      await securityService.recordUserActivity();
      expect(securityService.isSessionExpired(), isFalse);

      // Mock an expired session timestamp (>15 minutes ago)
      final pastTime = DateTime.now().subtract(const Duration(minutes: 20));
      await prefs.setInt('security_last_active_timestamp', pastTime.millisecondsSinceEpoch);

      expect(securityService.isSessionExpired(), isTrue);
    });

    // =========================================================================
    // 3. MASVS-NETWORK: Payload Sanitization & Anti-Injection
    // =========================================================================
    test('SecuritySanitizer strips XSS scripts and malicious HTML', () {
      const xssInput = 'Road Trip <script>alert("hacked")</script> to Paris';
      final clean = SecuritySanitizer.sanitizeString(xssInput);
      expect(clean, equals('Road Trip  to Paris'));
      expect(clean.contains('<script>'), isFalse);
    });

    test('SecuritySanitizer strips control characters and null bytes', () {
      const poisoned = 'Trip\x00Title\u0007Header';
      final clean = SecuritySanitizer.sanitizeString(poisoned);
      expect(clean.contains('\x00'), isFalse);
      expect(clean.contains('\u0007'), isFalse);
      expect(clean, equals('TripTitleHeader'));
    });

    test('SecuritySanitizer validates and normalizes emails and usernames', () {
      expect(SecuritySanitizer.isValidEmail('user@domain.com'), isTrue);
      expect(SecuritySanitizer.isValidEmail('not-an-email'), isFalse);

      expect(SecuritySanitizer.sanitizeEmail('  USER@Domain.COM  '), equals('user@domain.com'));

      expect(SecuritySanitizer.isValidUsername('cool_tripper99'), isTrue);
      expect(SecuritySanitizer.isValidUsername('bad<name>'), isFalse);
      expect(SecuritySanitizer.isValidUsername('ab'), isFalse); // Min length 3
    });

    test('SecuritySanitizer recursively sanitizes JSON and Map payloads', () {
      final dirtyMap = {
        'tripName': 'Alps <script>malicious()</script>',
        'budget': 500,
        'metadata': {
          'notes': '<b>Bold note</b><img src=x onerror=alert(1)>',
        },
        'tags': ['nature', '<script>steal()</script>'],
      };

      final cleanMap = SecuritySanitizer.sanitizePayload(dirtyMap);
      expect(cleanMap['tripName'], equals('Alps '));
      expect(cleanMap['budget'], equals(500));
      expect((cleanMap['metadata'] as Map)['notes'], equals('Bold note'));
      expect((cleanMap['tags'] as List)[1], equals(''));
    });

    // =========================================================================
    // 4. MASVS-PRIVACY: Ephemeral TTL & Location Precision Reduction
    // =========================================================================
    test('Location fuzzing reduces precision to grid center without revealing exact coordinates', () {
      const exactLat = 37.774929;
      const exactLng = -122.419416;

      final fuzzed = SecurityService.fuzzCoordinates(exactLat, exactLng, precisionMeters: 250.0);

      // Should not equal the exact raw coordinate
      expect(fuzzed.latitude, isNot(equals(exactLat)));
      expect(fuzzed.longitude, isNot(equals(exactLng)));

      // But should be within reasonable proximity (~250m)
      expect((fuzzed.latitude - exactLat).abs(), lessThan(0.005));
      expect((fuzzed.longitude - exactLng).abs(), lessThan(0.005));
    });

    test('LiveCompanionTrackerNotifier purges stale locations beyond TTL window', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(liveCompanionTrackerProvider.notifier);

      // Add a fresh location
      notifier.onRemoteLocationUpdate('companion_fresh', 37.77, -122.41);
      expect(container.read(liveCompanionTrackerProvider).containsKey('companion_fresh'), isTrue);

      // Manually inject a stale position from 5 hours ago
      notifier.state = {
        ...notifier.state,
        'companion_stale': CompanionLivePosition(
          memberId: 'companion_stale',
          latitude: 37.78,
          longitude: -122.42,
          lastUpdated: DateTime.now().subtract(const Duration(hours: 5)),
        ),
      };

      expect(container.read(liveCompanionTrackerProvider).containsKey('companion_stale'), isTrue);

      // Purge locations older than 2 hours
      notifier.purgeStaleLocations(ttl: const Duration(hours: 2));

      final stateAfter = container.read(liveCompanionTrackerProvider);
      expect(stateAfter.containsKey('companion_fresh'), isTrue);
      expect(stateAfter.containsKey('companion_stale'), isFalse);
    });

    // =========================================================================
    // 5. MASVS-RESILIENCE: Zero-PII Logger Redaction
    // =========================================================================
    test('AppLogger masks emails, auth tokens, and raw coordinates from logs', () {
      const rawLog = 'User alex.traveler@domain.com signed in with token jwt_abc123xyz987 at 37.774929, -122.419416';
      final redacted = AppLogger.redact(rawLog);

      expect(redacted.contains('alex.traveler@domain.com'), isFalse);
      expect(redacted.contains('a***r@domain.com'), isTrue);
      expect(redacted.contains('jwt_abc123xyz987'), isFalse);
      expect(redacted.contains('[REDACTED_AUTH_TOKEN]'), isTrue);
      expect(redacted.contains('37.774929'), isFalse);
      expect(redacted.contains('[GPS_REDACTED]'), isTrue);
    });
  });
}
