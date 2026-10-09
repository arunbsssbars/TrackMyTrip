import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trackmytrip/core/services/admin_service.dart';
import 'package:trackmytrip/core/services/build_info_service.dart';
import 'package:trackmytrip/core/services/canary_health_service.dart';
import 'package:trackmytrip/core/services/secret_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Loop 1: BuildInfoService & Metadata Matrix Tests', () {
    test('BuildInfoService returns valid version and formatted commit string', () {
      expect(BuildInfoService.appVersion, equals('1.0.0'));
      expect(BuildInfoService.buildNumber, isNotEmpty);
      expect(BuildInfoService.commitHash, isNotEmpty);
      expect(BuildInfoService.formattedVersion, contains('v1.0.0+'));

      final diag = BuildInfoService.getDiagnosticMap();
      expect(diag['appVersion'], equals('1.0.0'));
      expect(diag['formattedVersion'], isA<String>());
      expect(diag.containsKey('environment'), isTrue);
    });

    test('BuildInfoService respects compile-time / env overrides', () {
      SecretConfigService.setMockVariables({
        BuildInfoService.keyBuildNumber: '42',
        BuildInfoService.keyCommitHash: 'abcdef123456789',
        BuildInfoService.keyGitBranch: 'feature/ci-cd',
      });

      expect(BuildInfoService.buildNumber, equals('42'));
      expect(BuildInfoService.commitHash, equals('abcdef123456789'));
      expect(BuildInfoService.gitBranch, equals('feature/ci-cd'));
      expect(BuildInfoService.formattedVersion, equals('v1.0.0+42 (abcdef1)'));
    });
  });

  group('Loop 2 & 3: Bundle Size Budget & Diagnostic Reporting Tests', () {
    test('AdminService returns valid bundle size budget report', () {
      final report = AdminService.getBundleSizeBudgetReport();
      expect(report['androidApkBudgetMb'], equals(50.0));
      expect(report['iosIpaBudgetMb'], equals(60.0));
      expect(report['enforcedInCi'], isTrue);
    });

    test('generateSystemDiagnosticReport includes buildInfo payload', () {
      final metrics = FreeTierQuotaMetrics(
        firestoreDocCount: 100,
        firestoreTripsCount: 10,
        firestoreRoomsCount: 5,
        firestoreUsersCount: 20,
        firestoreTombstonesCount: 2,
        firestoreInvitationsCount: 3,
        firestoreEstimatedReads: 500,
        firestoreEstimatedWrites: 50,
        firestoreStorageMb: 1.2,
        rtdbActiveConnections: 1,
        rtdbStorageMb: 0.5,
        rtdbBandwidthMb: 0.2,
        storageFileCount: 10,
        storageUsedMb: 2.5,
        authTotalUsers: 15,
        timestamp: DateTime(2026, 10, 9),
      );

      final report = AdminService.generateSystemDiagnosticReport(metrics);
      expect(report.containsKey('buildInfo'), isTrue);
      expect(report['buildInfo']['appVersion'], equals('1.0.0'));
    });
  });

  group('Loop 4: CI/CD Pipeline Efficiency Metrics Tests', () {
    test('AdminService declares concurrency cancellation and cache optimization', () {
      final metrics = AdminService.getPipelineEfficiencyMetrics();
      expect(metrics['concurrencyCancelInProgress'], isTrue);
      expect(metrics['gradleCachingEnabled'], isTrue);
      expect(metrics['flutterPubCachingEnabled'], isTrue);
      expect(metrics['averageBuildDurationEstimateMinutes'], lessThan(10.0));
    });
  });

  group('Loop 5: CanaryHealthService & Automated Rollback Probe Tests', () {
    test('runCanaryHealthProbe returns healthy verdict when endpoints respond with 200', () async {
      final mockClient = MockClient((request) async {
        return http.Response('OK', 200);
      });

      final result = await CanaryHealthService.runCanaryHealthProbe(client: mockClient);
      expect(result.isHealthy, isTrue);
      expect(result.shouldRollback, isFalse);
      expect(result.healthScore, greaterThanOrEqualTo(66));
      expect(result.serviceStatuses.containsKey('osmTileCdn'), isTrue);
      expect(result.serviceStatuses.containsKey('fxApi'), isTrue);
    });

    test('runCanaryHealthProbe triggers rollback recommendation when all endpoints fail', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Network unreachable');
      });

      final result = await CanaryHealthService.runCanaryHealthProbe(client: mockClient);
      expect(result.shouldRollback, isTrue);
      expect(result.healthScore, lessThan(35));
      expect(result.serviceStatuses['osmTileCdn'], equals('Unreachable'));
      expect(result.serviceStatuses['fxApi'], equals('Unreachable'));
    });
  });
}
