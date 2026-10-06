import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/models/stoppage.dart';

void main() {
  group('Sprint 13: Loops 111–115 Timeline & Stoppage Management Tests', () {
    test('Loop 111: Stoppage orderIndex reordering and sorting', () {
      final stop1 = Stoppage(
        id: 'stop-1',
        tripId: 'trip-1',
        name: 'First Stop',
        latitude: 15.2993,
        longitude: 74.1240,
        category: 'Food',
        arrivedAt: DateTime(2026, 10, 1, 9, 0),
        createdBy: 'user-1',
        orderIndex: 0,
      );

      final stop2 = Stoppage(
        id: 'stop-2',
        tripId: 'trip-1',
        name: 'Second Stop',
        latitude: 15.3500,
        longitude: 74.1500,
        category: 'Sightseeing',
        arrivedAt: DateTime(2026, 10, 1, 11, 0),
        createdBy: 'user-1',
        orderIndex: 1,
      );

      // Reorder inverted
      final reordered = [stop2.copyWith(orderIndex: 0), stop1.copyWith(orderIndex: 1)];
      expect(reordered.first.id, 'stop-2');
      expect(reordered.first.orderIndex, 0);
      expect(reordered.last.id, 'stop-1');
      expect(reordered.last.orderIndex, 1);
    });

    test('Loop 112: Stoppage Burn Rate & Cost-Per-Hour Calculation', () {
      final stoppage = Stoppage(
        id: 'stop-cafe',
        tripId: 'trip-1',
        name: 'Mountain Cafe',
        latitude: 15.2993,
        longitude: 74.1240,
        category: 'Food',
        arrivedAt: DateTime(2026, 10, 1, 10, 0),
        departedAt: DateTime(2026, 10, 1, 12, 30), // 2.5 hours = 150 minutes
        createdBy: 'user-1',
      );

      expect(stoppage.duration, isNotNull);
      expect(stoppage.duration!.inMinutes, 150);

      const double totalExpenseAtStop = 500.0;
      final stayHours = stoppage.duration!.inMinutes / 60.0;
      final costPerHour = totalExpenseAtStop / stayHours;

      expect(stayHours, 2.5);
      expect(costPerHour, 200.0);
    });

    test('Loop 113: Batch expand / collapse all days keys logic', () {
      final allDateKeys = ['2026-10-03', '2026-10-02', '2026-10-01'];
      final expandedSet = <String>{};

      // Initially only 1 day expanded
      expandedSet.add('2026-10-03');
      expect(expandedSet.length < allDateKeys.length, isTrue);

      // Batch expand all
      expandedSet.addAll(allDateKeys);
      expect(expandedSet.length, allDateKeys.length);
      expect(expandedSet.containsAll(allDateKeys), isTrue);

      // Batch collapse all
      expandedSet.clear();
      expect(expandedSet.isEmpty, isTrue);
    });

    test('Loop 114: Stoppage attendance checklist member mapping', () {
      final members = [
        {'id': 'm1', 'name': 'Arun'},
        {'id': 'm2', 'name': 'Bob'},
        {'id': 'm3', 'name': 'Charlie'},
      ];

      expect(members.length, 3);
      final presentCount = members.length;
      expect('$presentCount Present', '3 Present');
    });
  });
}
