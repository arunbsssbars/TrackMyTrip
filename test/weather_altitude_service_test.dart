import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/models/weather_altitude_telemetry.dart';
import 'package:trackmytrip/core/services/weather_altitude_service.dart';
import 'package:trackmytrip/screens/timeline/timeline_weather_card.dart';

void main() {
  group('WeatherAltitudeService Logic Tests', () {
    final service = WeatherAltitudeService();

    test('Computes realistic telemetry for given coordinates', () {
      final telemetry = service.getTelemetry(
        latitude: 32.2432,
        longitude: 77.1892,
        rawAltitudeMeters: 2050.0,
      );

      expect(telemetry.altitudeMeters, 2050.0);
      expect(telemetry.altitudeFeet, closeTo(6725.7, 0.5));
      expect(telemetry.condition, 'Cloudy');
      expect(telemetry.isHighAltitudeRisk, false);
      expect(telemetry.temperatureFahrenheit, closeTo((telemetry.temperatureCelsius * 9 / 5) + 32, 0.1));
    });

    test('Detects high altitude AMS risk at or above 2500m', () {
      final telemetry = service.getTelemetry(
        latitude: 34.1526,
        longitude: 77.5771,
        rawAltitudeMeters: 3524.0, // Leh Ladakh
      );

      expect(telemetry.isHighAltitudeRisk, true);
      expect(telemetry.isExtremeAltitudeRisk, true);
      expect(telemetry.condition, 'Snowy');
      expect(telemetry.altitudeRiskAdvice, contains('Acute Mountain Sickness'));
    });

    test('Detects rapid ascent danger alert', () {
      final warning = service.checkAscentDanger(
        previousAltitudeMeters: 2200.0,
        currentAltitudeMeters: 3200.0,
        timeDifference: const Duration(hours: 2), // 500m/hour gain
      );

      expect(warning, isNotNull);
      expect(warning, contains('Rapid Ascent Detected'));
    });

    test('Ignores safe ascent under 2500m or moderate gain rate', () {
      final safeWarning = service.checkAscentDanger(
        previousAltitudeMeters: 800.0,
        currentAltitudeMeters: 1400.0,
        timeDifference: const Duration(hours: 2),
      );
      expect(safeWarning, isNull);
    });

    test('Json serialization and deserialization retains accuracy', () {
      final original = WeatherAltitudeTelemetry(
        altitudeMeters: 2850.5,
        temperatureCelsius: 9.5,
        condition: 'Rainy',
        humidityPercent: 78,
        windSpeedKmh: 18.2,
        uvIndex: 4.5,
        recordedAt: DateTime.utc(2026, 10, 8, 10, 0),
      );

      final json = original.toJson();
      final restored = WeatherAltitudeTelemetry.fromJson(json);

      expect(restored.altitudeMeters, original.altitudeMeters);
      expect(restored.temperatureCelsius, original.temperatureCelsius);
      expect(restored.condition, original.condition);
      expect(restored.humidityPercent, original.humidityPercent);
      expect(restored.isHighAltitudeRisk, true);
    });
  });

  group('AQIL Multi-Viewport & Accessibility Tests for TimelineWeatherCard', () {
    final telemetry = WeatherAltitudeTelemetry(
      altitudeMeters: 3100.0,
      temperatureCelsius: 7.8,
      condition: 'Cloudy',
      humidityPercent: 65,
      windSpeedKmh: 24.5,
      uvIndex: 8.5,
      recordedAt: DateTime.now(),
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
              body: SingleChildScrollView(
                child: TimelineWeatherCard(
                  telemetry: telemetry,
                  ascentWarning: 'Rapid Ascent Warning: +600m in 1.5h',
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Cloudy'), findsOneWidget);
        expect(find.byType(TimelineWeatherCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Renders with 1.5x font scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: TimelineWeatherCard(
                  telemetry: telemetry,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Cloudy'), findsOneWidget);

      // Verify toggling between metric and imperial
      final unitButton = find.text('Metric');
      expect(unitButton, findsOneWidget);
      await tester.tap(unitButton);
      await tester.pumpAndSettle();

      expect(find.text('Imperial'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
