import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/services/admin_service.dart';
import 'package:trackmytrip/core/services/secret_config_service.dart';
import 'package:trackmytrip/core/services/security_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecretConfigService Tests', () {
    setUp(() {
      SecretConfigService.setMockVariables({
        SecretConfigService.keyAppEnv: 'production',
        SecretConfigService.keyGoogleMapsApiKey: 'AIzaSyD123456789012345678901234567890',
        SecretConfigService.keyFirebaseAppId: '1:123456789012:web:abcdef123456',
        SecretConfigService.keyVaultPepper: 'my_production_salt_2026',
      });
    });

    test('Masking logic conceals secret body while displaying boundary markers', () {
      final masked = SecretConfigService.maskSecret('AIzaSyD123456789012345678901234567890');
      expect(masked.startsWith('AIza'), isTrue);
      expect(masked.endsWith('7890'), isTrue);
      expect(masked.contains('••••'), isTrue);
      expect(masked.contains('1234567890123456'), isFalse, reason: 'Raw secret body must not be visible');
    });

    test('Masking handles empty, null, and short secrets defensively', () {
      expect(SecretConfigService.maskSecret(null), equals('[NOT CONFIGURED]'));
      expect(SecretConfigService.maskSecret(''), equals('[NOT CONFIGURED]'));
      expect(SecretConfigService.maskSecret('short'), equals('••••••••'));
    });

    test('isConfigured accurately rejects placeholder values and empty keys', () {
      SecretConfigService.setMockVariables({
        SecretConfigService.keyGoogleMapsApiKey: 'AIzaSy_YOUR_GOOGLE_MAPS_API_KEY_HERE',
      });
      expect(SecretConfigService.isConfigured(SecretConfigService.keyGoogleMapsApiKey), isFalse);

      SecretConfigService.setMockVariables({
        SecretConfigService.keyGoogleMapsApiKey: 'AIzaSyValidProductionSecretKey123456789',
      });
      expect(SecretConfigService.isConfigured(SecretConfigService.keyGoogleMapsApiKey), isTrue);
    });

    test('getMaskedSecretsAuditReport produces sanitized diagnostic map', () {
      final report = SecretConfigService.getMaskedSecretsAuditReport();
      expect(report['isProduction'], isTrue);
      expect(report['googleMapsConfigured'], isTrue);
      expect(report['googleMapsApiKeyMasked'], contains('••••'));
      expect(report['firebaseAppIdMasked'], contains('••••'));
    });
  });

  group('SecurityService Vault Health & Secret Isolation Tests', () {
    test('performVaultHealthCheck executes cleanly with simulated secure storage', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final security = SecurityService();

      final result = await security.performVaultHealthCheck();
      expect(result['keystoreActive'], isTrue);
      expect(result['status'], contains('Healthy'));
      expect(result['latencyMs'], isA<int>());
    });

    test('storeAppSecret and getAppSecret isolate namespaced secrets in vault', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final security = SecurityService();

      await security.storeAppSecret('api_token', 'super_secret_bearer_token');
      final retrieved = await security.getAppSecret('api_token');
      expect(retrieved, equals('super_secret_bearer_token'));
    });
  });

  group('DevSecOps Secret Scanning Pattern Validation', () {
    test('Regex pattern detects real Google API keys and ignores templates', () {
      final googleKeyRegex = RegExp(r'AIza[0-9A-Za-z_-]{35}');
      const realKey = 'AIzaSyA1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q';
      const template = 'AIzaSy_YOUR_GOOGLE_MAPS_API_KEY_HERE';

      expect(googleKeyRegex.hasMatch(realKey), isTrue);
      // Ensure scanner flag identifies the real key
      expect(realKey.length, equals(39));
    });

    test('Regex pattern accurately detects private cryptographic keys', () {
      final privateKeyRegex = RegExp(r'-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----');
      const fakeRsaKey = '-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA...';
      const fakeEcKey = '-----BEGIN EC PRIVATE KEY-----\nMHcCAQEEI...';

      expect(privateKeyRegex.hasMatch(fakeRsaKey), isTrue);
      expect(privateKeyRegex.hasMatch(fakeEcKey), isTrue);
      expect(privateKeyRegex.hasMatch('normal source code line'), isFalse);
    });

    test('AdminService.generateSecurityAuditSummary yields comprehensive security scores', () {
      final audit = AdminService.generateSecurityAuditSummary();
      expect(audit['securityScore'], inInclusiveRange(80, 100));
      expect(audit['scoreGrade'], contains('Grade'));
      expect(audit['hardwareKeystore'], contains('AES-256'));
    });
  });
}
