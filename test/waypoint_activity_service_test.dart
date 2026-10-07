import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/models/waypoint_activity_item.dart';
import 'package:trackmytrip/core/services/waypoint_activity_service.dart';
import 'package:trackmytrip/screens/timeline/waypoint_activity_sheet.dart';

void main() {
  group('WaypointActivityService Logic Tests', () {
    final service = WaypointActivityService();

    test('Generates stoppage-tailored activity suggestions', () {
      final fuelActivities = service.generateSuggestedActivities(
        stoppageId: 'stop_101',
        tagOrCategory: 'Fuel Station',
      );
      expect(fuelActivities.length, 3);
      expect(fuelActivities.any((a) => a.title.contains('tyre pressure')), true);

      final foodActivities = service.generateSuggestedActivities(
        stoppageId: 'stop_102',
        tagOrCategory: 'Lunch Dhaba',
      );
      expect(foodActivities.length, 3);
      expect(foodActivities.any((a) => a.title.contains('receipt')), true);
    });

    test('Computes progress ratio accurately and toggles state', () {
      final item1 = WaypointActivityItem(
        id: '1',
        stoppageId: 'stop_1',
        title: 'Task 1',
        createdAt: DateTime.now(),
      );
      final item2 = WaypointActivityItem(
        id: '2',
        stoppageId: 'stop_1',
        title: 'Task 2',
        createdAt: DateTime.now(),
      );

      final list = [item1, item2];
      expect(service.calculateProgressRatio(list), 0.0);

      final toggled1 = service.toggleItemCompletion(item1);
      expect(toggled1.isCompleted, true);
      expect(toggled1.completedAt, isNotNull);

      expect(service.calculateProgressRatio([toggled1, item2]), 0.5);

      final untoggled1 = service.toggleItemCompletion(toggled1);
      expect(untoggled1.isCompleted, false);
      expect(untoggled1.completedAt, isNull);
    });

    test('Json serialization and deserialization retains accuracy', () {
      final item = WaypointActivityItem(
        id: 'act_99',
        stoppageId: 'stop_99',
        title: 'Collect drone footage',
        assignedMemberName: 'Rahul',
        isCompleted: true,
        createdAt: DateTime.utc(2026, 10, 8, 8, 30),
        completedAt: DateTime.utc(2026, 10, 8, 8, 45),
        note: '4K video captured at pass',
      );

      final json = item.toJson();
      final restored = WaypointActivityItem.fromJson(json);

      expect(restored.id, 'act_99');
      expect(restored.title, 'Collect drone footage');
      expect(restored.assignedMemberName, 'Rahul');
      expect(restored.isCompleted, true);
      expect(restored.note, '4K video captured at pass');
    });
  });

  group('AQIL Multi-Viewport & Accessibility Tests for WaypointActivitySheet', () {
    final service = WaypointActivityService();
    final sampleItems = service.generateSuggestedActivities(
      stoppageId: 'stop_pass_1',
      tagOrCategory: 'Mountain Pass',
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
              body: WaypointActivitySheet(
                stoppageName: 'Rohtang Pass',
                initialItems: sampleItems,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.textContaining('Rohtang Pass'), findsOneWidget);
        expect(find.byType(WaypointActivitySheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Renders with 1.5x font scale without overflow and adds item', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: WaypointActivitySheet(
                stoppageName: 'Rohtang Pass',
                initialItems: sampleItems,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('Rohtang Pass'), findsOneWidget);

      // Add a new activity
      final inputFinder = find.byType(TextField);
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, 'Check oil level');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('Check oil level'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
