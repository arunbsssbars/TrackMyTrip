import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/services/packing_service.dart';
import 'package:trackmytrip/screens/trip_detail/packing_checklist_sheet.dart';

void main() {
  group('PackingService Unit Tests', () {
    const tripId = 'test_trip_pack_01';

    setUp(() {
      PackingService.setItemsForTrip(tripId, []);
    });

    test('Pre-seeds default expedition items when empty', () {
      final items = PackingService.getItemsForTrip(tripId);
      expect(items.length, greaterThanOrEqualTo(6));
      expect(items.any((i) => i.category == 'Documents'), isTrue);
      expect(items.any((i) => i.category == 'Medical'), isTrue);
    });

    test('Adds custom packing item and calculates stats accurately', () {
      final initialStats = PackingService.getStats(tripId);
      final initialCount = initialStats.totalCount;

      final newItem = PackingService.addItem(
        tripId,
        title: 'High Altitude Sleeping Bag',
        category: 'Gear',
        quantity: 2,
      );

      expect(newItem.title, equals('High Altitude Sleeping Bag'));
      expect(newItem.isPacked, isFalse);

      final updatedStats = PackingService.getStats(tripId);
      expect(updatedStats.totalCount, equals(initialCount + 1));

      // Toggle packed state
      final toggled = PackingService.togglePacked(tripId, newItem.id);
      expect(toggled?.isPacked, isTrue);

      final packedStats = PackingService.getStats(tripId);
      expect(packedStats.packedCount, greaterThan(initialStats.packedCount));

      // Delete item
      final deleted = PackingService.deleteItem(tripId, newItem.id);
      expect(deleted, isTrue);
    });
  });

  group('AQIL Multi-Viewport & Accessibility Tests: PackingChecklistSheet', () {
    const viewports = [
      Size(320, 600),  // Compact Mobile
      Size(393, 852),  // Standard Mobile
      Size(412, 915),  // Large Mobile
      Size(800, 1200), // Tablet Portrait
      Size(1280, 800), // Landscape Desktop
    ];

    for (final viewport in viewports) {
      testWidgets('Renders zero overflow at ${viewport.width}x${viewport.height} with 1.5x font scale', (tester) async {
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: viewport,
                textScaler: const TextScaler.linear(1.5),
              ),
              child: const Scaffold(
                body: PackingChecklistSheet(
                  tripId: 'test_aqil_trip',
                  tripTitle: 'Leh Ladakh Expedition',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Packing Checklist'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsWidgets);

        // Tap first checkbox to test interaction
        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  });
}
