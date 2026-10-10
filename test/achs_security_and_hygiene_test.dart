import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/services/secret_config_service.dart';
import 'package:trackmytrip/core/utils/currency_formatter.dart';
import 'package:trackmytrip/core/utils/date_formatter.dart';
import 'package:trackmytrip/models/memory.dart';
import 'package:trackmytrip/models/proximity_alert.dart';
import 'package:trackmytrip/models/trip.dart';

void main() {
  group('ACHS (Autonomous Code Hygiene, Deduplication & Security) Verification Suite', () {
    
    // =========================================================================
    // Pillar A & C: Secret Leak & Git Tracking Hygiene Scanner
    // =========================================================================
    test('ACHS Pillar C: Source code in lib/ must have ZERO hardcoded secrets or API secrets', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final forbiddenRegexes = [
        RegExp(r'''CLOUDINARY_API_SECRET\s*=\s*['"][a-zA-Z0-9_\-]{10,}['"]'''),
        RegExp(r'''ghp_[a-zA-Z0-9]{36}'''), // GitHub personal access token
        RegExp(r'''AKIA[0-9A-Z]{16}'''),    // AWS Access Key ID
        RegExp('-----' + 'BEGIN' + ' PRIVATE KEY' + '-----'),
        RegExp('-----' + 'BEGIN' + ' RSA PRIVATE KEY' + '-----'),
      ];

      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        for (final regex in forbiddenRegexes) {
          final match = regex.firstMatch(content);
          expect(
            match,
            isNull,
            reason: 'Found forbidden credential pattern (${regex.pattern}) in ${file.path}',
          );
        }
      }
    });

    test('ACHS Pillar A & C: .gitignore must protect .env, key.properties, and .jks/.keystore', () {
      final gitignoreFile = File('.gitignore');
      expect(gitignoreFile.existsSync(), isTrue);

      final content = gitignoreFile.readAsStringSync();
      expect(content.contains('.env'), isTrue, reason: '.gitignore must ignore .env');
      expect(content.contains('key.properties'), isTrue, reason: '.gitignore must ignore key.properties');
      expect(content.contains('.jks') || content.contains('*.jks') || content.contains('.keystore') || content.contains('*.keystore'), isTrue,
          reason: '.gitignore must ignore keystores');
    });

    // =========================================================================
    // Pillar B: DRY Deduplication & Centralized Formatter Integrity
    // =========================================================================
    test('ACHS Pillar B: CurrencyFormatter handles edge cases, negative amounts, and non-finite values safely', () {
      expect(CurrencyFormatter.format(0), '₹0.00');
      expect(CurrencyFormatter.format(1500), '₹1,500.00');
      expect(CurrencyFormatter.format(100000), '₹1,00,000.00');
      expect(CurrencyFormatter.format(-250.50), '-₹250.50');
      expect(CurrencyFormatter.format(double.nan), '₹0.00');
      expect(CurrencyFormatter.format(double.infinity), '₹0.00');
      expect(CurrencyFormatter.format(100, currency: 'USD'), r'$100.00');
      expect(CurrencyFormatter.format(100, currency: 'EUR'), '€100.00');
      expect(CurrencyFormatter.formatCompact(5000), '₹5K');
    });

    test('ACHS Pillar B: DateFormatter safely handles UTC, local time, and relative timestamps', () {
      final testDate = DateTime.utc(2026, 10, 10, 15, 30);
      final formattedShort = DateFormatter.formatShortDate(testDate);
      expect(formattedShort, contains('2026'));
      expect(formattedShort, contains('Oct'));

      final formattedMonth = DateFormatter.formatMonthYear(testDate);
      expect(formattedMonth, 'October 2026');

      final now = DateTime.now();
      expect(DateFormatter.formatRelativeOrTime(now), contains('Today at'));
      
      final yesterday = now.subtract(const Duration(days: 1));
      expect(DateFormatter.formatRelativeOrTime(yesterday), contains('Yesterday at'));
    });

    // =========================================================================
    // Pillar C: RBAC Boundary & Privilege Enforcement
    // =========================================================================
    test('ACHS Pillar C: SecretConfigService masks secrets and protects configuration keys', () {
      final masked = SecretConfigService.maskSecret('AIzaSyD12345678901234567890');
      expect(masked.startsWith('AIza'), isTrue);
      expect(masked.endsWith('7890'), isTrue);
      expect(masked.contains('••••'), isTrue);

      final shortMasked = SecretConfigService.maskSecret('short');
      expect(shortMasked, '••••••••');
    });

    // =========================================================================
    // Pillar C: Defensive Null-Safe Deserialization (Zero Crash Guarantee)
    // =========================================================================
    test('ACHS Pillar C: Memory model safely deserializes empty or partial maps without crashing', () {
      final memory = Memory.fromJson(const {});
      expect(memory.id, isEmpty);
      expect(memory.caption, isNull);
      expect(memory.mediaPath, isEmpty);
      expect(memory.localPath, isNull);
      expect(memory.remoteUrl, isNull);
      expect(memory.deleteToken, isNull);
      expect(memory.likedByMemberIds, isEmpty);

      // Verify toJson serialization produces complete valid map
      final json = memory.toJson();
      expect(json['id'], memory.id);
      expect(json['mediaPath'], isEmpty);
      expect(json['deleteToken'], isNull);
    });

    test('ACHS Pillar C: Trip model safely deserializes partial maps without crashing', () {
      final trip = Trip.fromJson(const {});
      expect(trip.id, isEmpty);
      expect(trip.title, 'Untitled Trip');
      expect(trip.members, isEmpty);
      expect(trip.isCreator('unknown_user'), isFalse);
    });

    test('ACHS Pillar C: ProximityAlert model safely deserializes partial maps without crashing', () {
      final alert = ProximityAlert.fromJson(const {});
      expect(alert.id, isEmpty);
      expect(alert.title, 'Alert');
      expect(alert.message, isEmpty);
      expect(alert.type, AlertType.general);
      expect(alert.isRead, isFalse);
    });
  });
}
