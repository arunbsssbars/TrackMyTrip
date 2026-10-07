import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/services/trip_archive_service.dart';
import 'package:trackmytrip/screens/trip_detail/trip_archive_dialog.dart';

void main() {
  group('TripArchiveService Cryptographic & Integrity Tests', () {
    final service = TripArchiveService();

    test('Creates valid archive bundle with non-empty SHA-256 hash', () {
      final bundle = service.createArchive(
        tripId: 'trip_ladakh_2026',
        tripTitle: 'Ladakh High Passes Expedition',
        tripData: {'destination': 'Leh', 'totalBudget': 45000},
        stoppages: [
          {'name': 'Khardung La', 'altitude': 5359},
          {'name': 'Pangong Tso', 'altitude': 4250},
        ],
        expenses: [
          {'category': 'Fuel', 'amount': 4500},
          {'category': 'Permits', 'amount': 1200},
        ],
        packingItems: [
          {'title': 'Oxygen Canister', 'isPacked': true},
        ],
      );

      expect(bundle.tripId, 'trip_ladakh_2026');
      expect(bundle.checksumSha256, isNotEmpty);
      expect(bundle.checksumSha256.length, 64); // Standard SHA-256 hex string length
    });

    test('Verifies valid archive successfully', () {
      final bundle = service.createArchive(
        tripId: 'trip_goa_01',
        tripTitle: 'Goa Coastal Drive',
        tripData: {'budget': 15000},
      );

      final exportedStr = service.exportToArchiveString(bundle);
      final result = service.verifyAndParseArchive(exportedStr);

      expect(result.isValid, true);
      expect(result.bundle, isNotNull);
      expect(result.bundle!.tripId, 'trip_goa_01');
      expect(result.errorMessage, isNull);
    });

    test('Detects malicious tampering and rejects modified payload', () {
      final bundle = service.createArchive(
        tripId: 'trip_secure_01',
        tripTitle: 'Secret Expedition',
        tripData: {'budget': 10000},
        expenses: [
          {'title': 'Dinner', 'amount': 500},
        ],
      );

      final exportedStr = service.exportToArchiveString(bundle);
      // Malicious actor modifies the expense amount from 500 to 50000
      final tamperedStr = exportedStr.replaceAll('500', '50000');

      final result = service.verifyAndParseArchive(tamperedStr);

      expect(result.isValid, false);
      expect(result.bundle, isNull);
      expect(result.errorMessage, contains('Security Alert'));
      expect(result.errorMessage, contains('tampering'));
    });
  });

  group('AQIL Multi-Viewport & Accessibility Tests for TripArchiveDialog', () {
    final bundle = TripArchiveService().createArchive(
      tripId: 'trip_spiti_4x4',
      tripTitle: 'Spiti Valley Winter Expedition',
      tripData: {'vehicle': 'Thar 4x4', 'totalDays': 8},
      stoppages: [
        {'name': 'Kaza'},
        {'name': 'Chicham Bridge'},
      ],
      expenses: [
        {'category': 'Diesel', 'amount': 6800},
      ],
      packingItems: [
        {'title': 'Snow chains', 'isPacked': true},
        {'title': 'Tow strap', 'isPacked': true},
      ],
    );

    final viewports = <String, Size>{
      'Compact Mobile (320px)': const Size(320, 568),
      'Standard Mobile (393px)': const Size(393, 852),
      'Large Mobile (412px)': const Size(412, 915),
      'Tablet Portrait (800px)': const Size(800, 1280),
      'Desktop Landscape (1280px)': const Size(1280, 800),
    };

    for (final entry in viewports.entries) {
      testWidgets('Renders zero overflow on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: TripArchiveDialog(bundle: bundle),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Offline Trip Archive (.tmt)'), findsOneWidget);
        expect(find.byType(TripArchiveDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Renders with 1.5x font scale without overflow and triggers export', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool exportTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              textScaler: const TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: Center(
                child: TripArchiveDialog(
                  bundle: bundle,
                  onShareOrSave: () => exportTapped = true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Offline Trip Archive (.tmt)'), findsOneWidget);

      final exportBtn = find.text('Export & Share');
      await tester.ensureVisible(exportBtn);
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      expect(exportTapped, true);
      expect(tester.takeException(), isNull);
    });
  });
}
