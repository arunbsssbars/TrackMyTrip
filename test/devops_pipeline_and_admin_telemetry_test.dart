import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/services/admin_service.dart';

void main() {
  group('DevOps Metadata & Admin Service Telemetry', () {
    test('AdminService declares valid version and GitHub repository URLs', () {
      expect(AdminService.appVersion, matches(r'^\d+\.\d+\.\d+(\+\d+)?$'));
      expect(AdminService.gitRepoUrl, equals('https://github.com/arunbsssbars/TrackMyTrip'));
      expect(AdminService.ciActionsUrl, equals('https://github.com/arunbsssbars/TrackMyTrip/actions'));
      expect(AdminService.gitReleasesUrl, equals('https://github.com/arunbsssbars/TrackMyTrip/releases'));
    });

    test('AdminService.runtimeEnvironment returns valid build flavor description', () {
      final env = AdminService.runtimeEnvironment;
      expect(env, isNotEmpty);
      expect(
        env.contains('Development') || env.contains('Production') || env.contains('Profile'),
        isTrue,
      );
    });

    test('AdminService.generateSystemDiagnosticReport includes required DevOps keys', () {
      final dummyMetrics = FreeTierQuotaMetrics(
        firestoreDocCount: 250,
        firestoreTripsCount: 40,
        firestoreRoomsCount: 15,
        firestoreUsersCount: 120,
        firestoreTombstonesCount: 5,
        firestoreInvitationsCount: 70,
        firestoreEstimatedReads: 1120,
        firestoreEstimatedWrites: 65,
        firestoreStorageMb: 0.85,
        rtdbActiveConnections: 8,
        rtdbStorageMb: 0.25,
        rtdbBandwidthMb: 1.1,
        storageFileCount: 30,
        storageUsedMb: 12.5,
        authTotalUsers: 120,
        firestoreLatencyMs: 142,
        rtdbLatencyMs: 85,
        timestamp: DateTime(2026, 10, 9),
      );

      final report = AdminService.generateSystemDiagnosticReport(dummyMetrics);

      expect(report['superAdmin'], equals('arunbsssbars@gmail.com'));
      expect(report['appVersion'], equals(AdminService.appVersion));
      expect(report['gitRepository'], equals(AdminService.gitRepoUrl));
      expect(report['ciActionsUrl'], equals(AdminService.ciActionsUrl));
      expect(report['environment'], equals(AdminService.runtimeEnvironment));
      expect(report['freeTierMetrics'], isA<Map<String, dynamic>>());

      // Validates JSON serializability
      final jsonOutput = jsonEncode(report);
      expect(jsonOutput, isNotEmpty);
      final decoded = jsonDecode(jsonOutput) as Map<String, dynamic>;
      expect(decoded['appVersion'], equals(AdminService.appVersion));
    });
  });

  group('DevOps Workflows & Infrastructure as Code Verification', () {
    test('All GitHub Actions workflow files exist and have valid structure', () {
      final workflowsDir = Directory('.github/workflows');
      expect(workflowsDir.existsSync(), isTrue, reason: '.github/workflows directory must exist');

      final expectedWorkflows = [
        'ci.yml',
        'build_android.yml',
        'build_ios.yml',
        'release.yml',
        'security_scan.yml',
        'firebase_deploy.yml',
      ];

      for (final wf in expectedWorkflows) {
        final file = File('${workflowsDir.path}/$wf');
        expect(file.existsSync(), isTrue, reason: '$wf must exist in .github/workflows');
        final content = file.readAsStringSync();
        expect(content, isNotEmpty);
        expect(content.contains('name:'), isTrue, reason: '$wf must define a workflow name');
      }
    });

    test('Firebase configuration files exist and are valid JSON', () {
      final firebaseJson = File('firebase.json');
      expect(firebaseJson.existsSync(), isTrue);
      final parsedFirebase = jsonDecode(firebaseJson.readAsStringSync()) as Map<String, dynamic>;
      expect(parsedFirebase.containsKey('firestore'), isTrue);
      expect(parsedFirebase.containsKey('storage'), isTrue);

      final indexesJson = File('firestore.indexes.json');
      expect(indexesJson.existsSync(), isTrue);
      final parsedIndexes = jsonDecode(indexesJson.readAsStringSync()) as Map<String, dynamic>;
      expect(parsedIndexes.containsKey('indexes'), isTrue);

      final rulesFile = File('firestore.rules');
      expect(rulesFile.existsSync(), isTrue);
      expect(rulesFile.readAsStringSync().contains('rules_version'), isTrue);
    });
  });
}
