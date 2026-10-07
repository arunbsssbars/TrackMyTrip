import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/models/eco_footprint_telemetry.dart';
import 'package:trackmytrip/core/services/eco_telemetry_service.dart';
import 'package:trackmytrip/screens/trip_detail/eco_footprint_card.dart';

void main() {
  group('EcoTelemetryService Mathematical Logic Tests', () {
    final service = EcoTelemetryService();

    test('Calculates Diesel SUV emissions and fuel accurately for 600km trip', () {
      final telemetry = service.calculateTelemetry(
        distanceKm: 600.0,
        vehicleType: 'Diesel SUV',
      );

      // 600km / 12 km/L = 50 Litres burned
      expect(telemetry.fuelBurnedLitres, 50.0);
      // 50L * 2.68 = 134 kg CO2
      expect(telemetry.co2EmittedKg, 134.0);
      // 134 / 22 = ceil(6.09) = 7 trees
      expect(telemetry.treesRequiredToOffset, 7);
      expect(telemetry.estimatedFuelCost, greaterThan(4000));
    });

    test('Calculates Electric EV emissions for clean roadtrip', () {
      final evTelemetry = service.calculateTelemetry(
        distanceKm: 400.0,
        vehicleType: 'Electric EV',
      );

      // 400 * 0.16 = 64 kWh
      expect(evTelemetry.fuelBurnedLitres, 64.0);
      // 400 * 0.05 = 20 kg CO2
      expect(evTelemetry.co2EmittedKg, 20.0);
      // 20 / 22 = 1 tree
      expect(evTelemetry.treesRequiredToOffset, 1);
    });

    test('Handles zero distance defensively', () {
      final zeroTelemetry = service.calculateTelemetry(
        distanceKm: 0.0,
        vehicleType: 'Petrol Car',
      );
      expect(zeroTelemetry.fuelBurnedLitres, 0.0);
      expect(zeroTelemetry.co2EmittedKg, 0.0);
      expect(zeroTelemetry.treesRequiredToOffset, 0);
    });

    test('Json serialization and deserialization retains accuracy', () {
      const original = EcoFootprintTelemetry(
        totalDistanceKm: 750.0,
        vehicleType: 'Motorcycle',
        fuelBurnedLitres: 21.4,
        co2EmittedKg: 49.4,
        treesRequiredToOffset: 3,
        estimatedFuelCost: 2140.0,
        currencyCode: 'INR',
      );

      final json = original.toJson();
      final restored = EcoFootprintTelemetry.fromJson(json);

      expect(restored.totalDistanceKm, 750.0);
      expect(restored.vehicleType, 'Motorcycle');
      expect(restored.treesRequiredToOffset, 3);
      expect(restored.currencyCode, 'INR');
    });
  });

  group('AQIL Multi-Viewport & Accessibility Tests for EcoFootprintCard', () {
    const distanceKm = 850.0;

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
          const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: EcoFootprintCard(
                  distanceKm: distanceKm,
                  initialVehicleType: 'Diesel SUV',
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Carbon Footprint & Fuel'), findsOneWidget);
        expect(find.byType(EcoFootprintCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Renders with 1.5x font scale without overflow and switches vehicle', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              textScaler: const TextScaler.linear(1.5),
            ),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: EcoFootprintCard(
                  distanceKm: distanceKm,
                  initialVehicleType: 'Diesel SUV',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Carbon Footprint & Fuel'), findsOneWidget);

      // Verify dropdown tap to select Electric EV
      await tester.tap(find.text('Diesel SUV'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Electric EV').last);
      await tester.pumpAndSettle();

      expect(find.text('Energy Used'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
