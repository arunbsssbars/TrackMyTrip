import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/models/vehicle_maintenance_milestone.dart';
import 'package:trackmytrip/core/services/vehicle_maintenance_service.dart';
import 'package:trackmytrip/screens/trip_detail/vehicle_maintenance_sheet.dart';

void main() {
  group('VehicleMaintenanceService Logic Tests', () {
    final service = VehicleMaintenanceService();
    final now = DateTime.now();

    final milestones = [
      VehicleMaintenanceMilestone(
        id: 'm1',
        tripId: 'trip_1',
        vehicleName: 'Thar 4x4',
        odometerKm: 12500.0,
        milestoneType: 'fuel_topup',
        cost: 4500.0,
        recordedAt: now,
      ),
      VehicleMaintenanceMilestone(
        id: 'm2',
        tripId: 'trip_1',
        vehicleName: 'Thar 4x4',
        odometerKm: 12850.0,
        milestoneType: 'toll',
        cost: 320.0,
        recordedAt: now,
      ),
      VehicleMaintenanceMilestone(
        id: 'm3',
        tripId: 'trip_1',
        vehicleName: 'Thar 4x4',
        odometerKm: 13200.0,
        milestoneType: 'tyre_check',
        cost: 150.0,
        recordedAt: now,
      ),
    ];

    test('Computes total odometer delta accurately', () {
      final distance = service.calculateOdometerDistance(milestones);
      expect(distance, 700.0); // 13200 - 12500
    });

    test('Aggregates total maintenance and toll expenditure', () {
      final total = service.calculateTotalCost(milestones);
      expect(total, 4970.0); // 4500 + 320 + 150
    });

    test('Json serialization and deserialization retains accuracy', () {
      final original = VehicleMaintenanceMilestone(
        id: 'm_special',
        tripId: 'trip_spiti',
        vehicleName: 'Fortuner',
        odometerKm: 45120.0,
        milestoneType: 'oil_service',
        cost: 6500.0,
        currency: 'INR',
        notes: 'Full synthetic 5W-30 topup',
        recordedAt: DateTime.utc(2026, 10, 8, 12, 0),
      );

      final json = original.toJson();
      final restored = VehicleMaintenanceMilestone.fromJson(json);

      expect(restored.id, 'm_special');
      expect(restored.odometerKm, 45120.0);
      expect(restored.cost, 6500.0);
      expect(restored.notes, 'Full synthetic 5W-30 topup');
    });
  });

  group('AQIL Multi-Viewport & Accessibility Tests for VehicleMaintenanceSheet', () {
    final now = DateTime.now();
    final sampleMilestones = [
      VehicleMaintenanceMilestone(
        id: 'm1',
        tripId: 'trip_ladakh',
        vehicleName: 'Himalayan 450',
        odometerKm: 8200.0,
        milestoneType: 'fuel_topup',
        cost: 1200.0,
        notes: 'IOCL Fuel Station',
        recordedAt: now,
      ),
      VehicleMaintenanceMilestone(
        id: 'm2',
        tripId: 'trip_ladakh',
        vehicleName: 'Himalayan 450',
        odometerKm: 8550.0,
        milestoneType: 'toll',
        cost: 85.0,
        notes: 'Tunnel Toll Plaza',
        recordedAt: now,
      ),
    ];

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
              body: VehicleMaintenanceSheet(
                tripId: 'trip_ladakh',
                vehicleName: 'Himalayan 450',
                initialMilestones: sampleMilestones,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.textContaining('Vehicle & Toll Log'), findsOneWidget);
        expect(find.byType(VehicleMaintenanceSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Renders with 1.5x font scale without overflow and adds milestone', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      List<VehicleMaintenanceMilestone>? updated;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              textScaler: const TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: VehicleMaintenanceSheet(
                tripId: 'trip_ladakh',
                vehicleName: 'Himalayan 450',
                initialMilestones: sampleMilestones,
                onMilestonesChanged: (list) => updated = list,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('Vehicle & Toll Log'), findsOneWidget);

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      await tester.enterText(textFields.first, 'Air pressure 32 psi');
      await tester.enterText(textFields.last, '50');

      final addBtn = find.byIcon(Icons.add);
      await tester.ensureVisible(addBtn);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.any((m) => m.notes.contains('Air pressure')), true);
      expect(tester.takeException(), isNull);
    });
  });
}
