import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/models/dwell_detection_event.dart';
import 'package:trackmytrip/core/services/dwell_time_detector_service.dart';
import 'package:trackmytrip/screens/timeline/dwell_stoppage_prompt_dialog.dart';

void main() {
  group('DwellTimeDetectorService Logic Tests', () {
    late DwellTimeDetectorService service;

    setUp(() {
      service = DwellTimeDetectorService();
      service.reset();
    });

    test('Computes accurate Haversine distance between two points', () {
      // Distance between Connaught Place (28.6315, 77.2167) and India Gate (28.6129, 77.2295) is ~2.4 km
      final dist = DwellTimeDetectorService.calculateDistanceMeters(
        lat1: 28.6315,
        lon1: 77.2167,
        lat2: 28.6129,
        lon2: 77.2295,
      );

      expect(dist, greaterThan(2200));
      expect(dist, lessThan(2600));
    });

    test('Tracks stationary dwell and triggers prompt eligibility after 5 minutes', () {
      final t0 = DateTime(2026, 10, 8, 12, 0);

      // First ping (stationary at 0.5 km/h)
      final ping1 = service.processLocationPing(
        latitude: 28.6315,
        longitude: 77.2167,
        speedKmh: 0.5,
        timestamp: t0,
      );
      expect(ping1, isNotNull);
      expect(ping1!.isEligibleForPrompt, false);

      // Ping after 6 minutes within 20m
      final t1 = t0.add(const Duration(minutes: 6));
      final ping2 = service.processLocationPing(
        latitude: 28.6316,
        longitude: 77.2168,
        speedKmh: 1.0,
        timestamp: t1,
      );
      expect(ping2, isNotNull);
      expect(ping2!.dwellDurationMinutes, 6);
      expect(ping2.isEligibleForPrompt, true);
      expect(ping2.formattedDuration, '6 mins');
    });

    test('Clears dwell when user resumes speed', () {
      final t0 = DateTime(2026, 10, 8, 12, 0);
      service.processLocationPing(
        latitude: 28.6315,
        longitude: 77.2167,
        speedKmh: 0.0,
        timestamp: t0,
      );

      // Resumed highway driving at 65 km/h
      final movingPing = service.processLocationPing(
        latitude: 28.6350,
        longitude: 77.2200,
        speedKmh: 65.0,
        timestamp: t0.add(const Duration(minutes: 2)),
      );

      expect(movingPing, isNull);
      expect(service.activeDwell, isNull);
    });

    test('Json serialization and deserialization retains accuracy', () {
      final event = DwellDetectionEvent(
        latitude: 15.2993,
        longitude: 74.1240,
        startTime: DateTime.utc(2026, 10, 8, 14, 0),
        lastPingTime: DateTime.utc(2026, 10, 8, 14, 25),
        radiusMeters: 45.0,
      );

      final json = event.toJson();
      final restored = DwellDetectionEvent.fromJson(json);

      expect(restored.latitude, 15.2993);
      expect(restored.longitude, 74.1240);
      expect(restored.dwellDurationMinutes, 25);
      expect(restored.isEligibleForPrompt, true);
    });
  });

  group('AQIL Multi-Viewport & Accessibility Tests for DwellStoppagePromptDialog', () {
    final event = DwellDetectionEvent(
      latitude: 31.1048,
      longitude: 77.1734,
      startTime: DateTime.now().subtract(const Duration(minutes: 18)),
      lastPingTime: DateTime.now(),
      radiusMeters: 50.0,
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
                child: DwellStoppagePromptDialog(event: event),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Stoppage Detected?'), findsOneWidget);
        expect(find.byType(DwellStoppagePromptDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Renders with 1.5x font scale without overflow and selects tag', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? loggedTag;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              textScaler: const TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: Center(
                child: DwellStoppagePromptDialog(
                  event: event,
                  onConfirmStoppage: (tag) => loggedTag = tag,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Stoppage Detected?'), findsOneWidget);

      // Select 'Fuel Station'
      final chipFinder = find.text('Fuel Station');
      await tester.ensureVisible(chipFinder);
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      final logBtn = find.text('Log Stoppage');
      await tester.ensureVisible(logBtn);
      await tester.tap(logBtn);
      await tester.pumpAndSettle();

      expect(loggedTag, 'Fuel Station');
      expect(tester.takeException(), isNull);
    });
  });
}
