import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/services/admin_service.dart';

void main() {
  group('Super Admin Authority & Identity Verification', () {
    test('isSuperAdmin returns true for exact super admin email', () {
      expect(AdminService.isSuperAdmin('arunbsssbars@gmail.com'), isTrue);
    });

    test('isSuperAdmin is case-insensitive and trims whitespace', () {
      expect(AdminService.isSuperAdmin('  ARUNBSSSBARS@GMAIL.COM  '), isTrue);
      expect(AdminService.isSuperAdmin('ArunBsssbars@Gmail.com'), isTrue);
    });

    test('isSuperAdmin returns false for unauthorized emails and empty/null values', () {
      expect(AdminService.isSuperAdmin(null), isFalse);
      expect(AdminService.isSuperAdmin(''), isFalse);
      expect(AdminService.isSuperAdmin('   '), isFalse);
      expect(AdminService.isSuperAdmin('arun@gmail.com'), isFalse);
      expect(AdminService.isSuperAdmin('arunbsssbars@yahoo.com'), isFalse);
      expect(AdminService.isSuperAdmin('pankaj@gmail.com'), isFalse);
    });
  });

  group('Free-Tier Quota Metrics & Limit Calculations', () {
    test('Calculates percentages accurately against Spark plan caps', () {
      final metrics = FreeTierQuotaMetrics(
        firestoreDocCount: 150,
        firestoreTripsCount: 20,
        firestoreRoomsCount: 15,
        firestoreUsersCount: 10,
        firestoreTombstonesCount: 5,
        firestoreInvitationsCount: 100,
        firestoreEstimatedReads: 5000, // 5,000 / 50,000 = 10%
        firestoreEstimatedWrites: 2000, // 2,000 / 20,000 = 10%
        firestoreStorageMb: 50.0, // 50 / 1024 = ~4.88%
        rtdbActiveConnections: 5, // 5 / 100 = 5%
        rtdbStorageMb: 2.0,
        rtdbBandwidthMb: 20.0,
        storageFileCount: 10,
        storageUsedMb: 100.0,
        authTotalUsers: 15,
        timestamp: DateTime.now(),
      );

      expect(metrics.firestoreReadsPercent, closeTo(10.0, 0.01));
      expect(metrics.firestoreWritesPercent, closeTo(10.0, 0.01));
      expect(metrics.rtdbConnectionsPercent, closeTo(5.0, 0.01));
      expect(metrics.isAnyQuotaWarning, isFalse);
      expect(metrics.isAnyQuotaCritical, isFalse);
    });

    test('Detects warning and critical threshold boundaries', () {
      final warningMetrics = FreeTierQuotaMetrics(
        firestoreDocCount: 500,
        firestoreTripsCount: 50,
        firestoreRoomsCount: 50,
        firestoreUsersCount: 50,
        firestoreTombstonesCount: 50,
        firestoreInvitationsCount: 300,
        firestoreEstimatedReads: 40000, // 80% (>= 75% warning)
        firestoreEstimatedWrites: 5000,
        firestoreStorageMb: 100.0,
        rtdbActiveConnections: 10,
        rtdbStorageMb: 1.0,
        rtdbBandwidthMb: 10.0,
        storageFileCount: 0,
        storageUsedMb: 0.0,
        authTotalUsers: 50,
        timestamp: DateTime.now(),
      );

      expect(warningMetrics.isAnyQuotaWarning, isTrue);
      expect(warningMetrics.isAnyQuotaCritical, isFalse);

      final criticalMetrics = FreeTierQuotaMetrics(
        firestoreDocCount: 500,
        firestoreTripsCount: 50,
        firestoreRoomsCount: 50,
        firestoreUsersCount: 50,
        firestoreTombstonesCount: 50,
        firestoreInvitationsCount: 300,
        firestoreEstimatedReads: 48000, // 96% (>= 90% critical)
        firestoreEstimatedWrites: 5000,
        firestoreStorageMb: 100.0,
        rtdbActiveConnections: 10,
        rtdbStorageMb: 1.0,
        rtdbBandwidthMb: 10.0,
        storageFileCount: 0,
        storageUsedMb: 0.0,
        authTotalUsers: 50,
        timestamp: DateTime.now(),
      );

      expect(criticalMetrics.isAnyQuotaCritical, isTrue);
    });

    test('generateSystemDiagnosticReport generates structured valid JSON snapshot', () {
      final metrics = FreeTierQuotaMetrics(
        firestoreDocCount: 200,
        firestoreTripsCount: 25,
        firestoreRoomsCount: 20,
        firestoreUsersCount: 15,
        firestoreTombstonesCount: 10,
        firestoreInvitationsCount: 130,
        firestoreEstimatedReads: 1200,
        firestoreEstimatedWrites: 400,
        firestoreStorageMb: 1.5,
        rtdbActiveConnections: 2,
        rtdbStorageMb: 0.1,
        rtdbBandwidthMb: 0.5,
        storageFileCount: 0,
        storageUsedMb: 0.0,
        authTotalUsers: 15,
        firestoreLatencyMs: 95,
        rtdbLatencyMs: 65,
        timestamp: DateTime.now(),
      );

      final report = AdminService.generateSystemDiagnosticReport(metrics);
      expect(report['superAdmin'], 'arunbsssbars@gmail.com');
      expect(report['freeTierMetrics'], isA<Map<String, dynamic>>());
      final fsMetrics = report['freeTierMetrics']['firestore'] as Map<String, dynamic>;
      expect(fsMetrics['totalDocuments'], 200);
      expect(fsMetrics['latencyMs'], 95);
    });
  });
}
