import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/models/expense.dart';
import 'package:trackmytrip/models/expense_split.dart';
import 'package:trackmytrip/models/memory.dart';
import 'package:trackmytrip/models/proximity_alert.dart';
import 'package:trackmytrip/models/stoppage.dart';
import 'package:trackmytrip/models/trip.dart';
import 'package:trackmytrip/models/trip_audit_log.dart';
import 'package:trackmytrip/models/trip_member.dart';
import 'package:trackmytrip/models/settlement.dart';

void main() {
  const member1 = TripMember(id: 'm1', name: 'Arun Kumar', email: 'arun@example.com', phoneNumber: '+91 98765 43210');
  const member2 = TripMember(id: 'm2', name: 'Priya Sharma', email: 'priya@example.com', phoneNumber: '9876501234');
  const member3 = TripMember(id: 'm3', name: 'Vikram Singh', email: 'vikram@example.com');

  final testTrip = Trip(
    id: 'trip_700',
    title: 'Rajasthan Desert Trail',
    startDate: DateTime(2026, 10, 1),
    endDate: DateTime(2026, 10, 8),
    createdAt: DateTime(2026, 9, 30),
    members: [member1, member2, member3],
    defaultCurrency: 'INR',
    createdByMemberId: 'm1',
  );

  group('Loop 61: Active Stoppage Real-Time Highlighting Banner Logic', () {
    test('identifies ongoing stoppage when departedAt is null', () {
      final now = DateTime.now();
      final stoppages = [
        Stoppage(
          id: 's1',
          tripId: testTrip.id,
          name: 'Amber Fort Viewpoint',
          latitude: 26.9855,
          longitude: 75.8513,
          arrivedAt: now.subtract(const Duration(hours: 3)),
          departedAt: now.subtract(const Duration(hours: 1)),
          category: 'sightseeing',
          createdBy: 'm1',
        ),
        Stoppage(
          id: 's2',
          tripId: testTrip.id,
          name: 'Jaipur Heritage Haveli',
          latitude: 26.9124,
          longitude: 75.7873,
          arrivedAt: now.subtract(const Duration(minutes: 45)),
          departedAt: null, // Ongoing!
          category: 'stay',
          createdBy: 'm1',
        ),
      ];

      final ongoingStoppage = stoppages.where((s) => s.isOngoing).firstOrNull;
      expect(ongoingStoppage, isNotNull);
      expect(ongoingStoppage!.id, equals('s2'));
      expect(ongoingStoppage.name, equals('Jaipur Heritage Haveli'));

      // Check duration calculation
      final duration = now.difference(ongoingStoppage.arrivedAt);
      expect(duration.inMinutes, greaterThanOrEqualTo(45));
    });

    test('returns null when all stoppages have completed departure', () {
      final now = DateTime.now();
      final stoppages = [
        Stoppage(
          id: 's1',
          tripId: testTrip.id,
          name: 'Past Fort',
          latitude: 26.9855,
          longitude: 75.8513,
          arrivedAt: now.subtract(const Duration(days: 2)),
          departedAt: now.subtract(const Duration(days: 2, hours: -2)),
          category: 'sightseeing',
          createdBy: 'm1',
        ),
      ];

      final ongoing = stoppages.where((s) => s.isOngoing).firstOrNull;
      expect(ongoing, isNull);
    });
  });

  group('Loop 62: Category Spending Distribution Mini-Bar Logic', () {
    test('computes proportional percentages and category shares accurately', () {
      final expenses = [
        Expense(
          id: 'e1',
          tripId: testTrip.id,
          title: 'Desert Camp Stay',
          totalAmount: 6000.0,
          currency: 'INR',
          category: 'stay',
          paidByMemberId: 'm1',
          splitType: SplitType.equal,
          splits: const [
            ExpenseSplit(memberId: 'm1', allocatedAmount: 2000.0),
            ExpenseSplit(memberId: 'm2', allocatedAmount: 2000.0),
            ExpenseSplit(memberId: 'm3', allocatedAmount: 2000.0),
          ],
          createdAt: DateTime(2026, 10, 1),
        ),
        Expense(
          id: 'e2',
          tripId: testTrip.id,
          title: 'Camel Safari & Dune Dinner',
          totalAmount: 3000.0,
          currency: 'INR',
          category: 'food',
          paidByMemberId: 'm2',
          splitType: SplitType.equal,
          splits: const [
            ExpenseSplit(memberId: 'm1', allocatedAmount: 1000.0),
            ExpenseSplit(memberId: 'm2', allocatedAmount: 1000.0),
            ExpenseSplit(memberId: 'm3', allocatedAmount: 1000.0),
          ],
          createdAt: DateTime(2026, 10, 2),
        ),
        Expense(
          id: 'e3',
          tripId: testTrip.id,
          title: 'Highway Toll & Fuel',
          totalAmount: 1000.0,
          currency: 'INR',
          category: 'transport',
          paidByMemberId: 'm1',
          splitType: SplitType.equal,
          splits: const [
            ExpenseSplit(memberId: 'm1', allocatedAmount: 333.34),
            ExpenseSplit(memberId: 'm2', allocatedAmount: 333.33),
            ExpenseSplit(memberId: 'm3', allocatedAmount: 333.33),
          ],
          createdAt: DateTime(2026, 10, 3),
        ),
      ];

      final totalSpent = expenses.fold<double>(0.0, (sum, e) => sum + e.totalAmount);
      expect(totalSpent, equals(10000.0));

      final Map<String, double> categorySpending = {};
      for (final exp in expenses) {
        categorySpending[exp.category] = (categorySpending[exp.category] ?? 0.0) + exp.totalAmount;
      }

      expect(categorySpending['stay'], equals(6000.0));
      expect(categorySpending['food'], equals(3000.0));
      expect(categorySpending['transport'], equals(1000.0));

      final stayRatio = categorySpending['stay']! / totalSpent;
      final foodRatio = categorySpending['food']! / totalSpent;
      final transportRatio = categorySpending['transport']! / totalSpent;

      expect(stayRatio, closeTo(0.60, 0.001));
      expect(foodRatio, closeTo(0.30, 0.001));
      expect(transportRatio, closeTo(0.10, 0.001));
      expect(stayRatio + foodRatio + transportRatio, closeTo(1.0, 0.001));
    });

    test('handles zero spending without division by zero', () {
      final List<Expense> noExpenses = [];
      final totalSpent = noExpenses.fold<double>(0.0, (sum, e) => sum + e.totalAmount);
      expect(totalSpent, equals(0.0));
      final Map<String, double> map = {};
      expect(map.isEmpty, isTrue);
    });
  });

  group('Loop 63: Settlement Tab Payment Method Quick Filter Chips', () {
    final s1 = Settlement(
      id: 'set1',
      tripId: testTrip.id,
      payerMemberId: 'm2',
      receiverMemberId: 'm1',
      amount: 1500.0,
      currency: 'INR',
      settledAt: DateTime(2026, 10, 3),
      paymentMethod: 'UPI / Online Transfer',
    );
    final s2 = Settlement(
      id: 'set2',
      tripId: testTrip.id,
      payerMemberId: 'm3',
      receiverMemberId: 'm1',
      amount: 800.0,
      currency: 'INR',
      settledAt: DateTime(2026, 10, 4),
      paymentMethod: 'Cash / Direct',
    );
    final s3 = Settlement(
      id: 'set3',
      tripId: testTrip.id,
      payerMemberId: 'm3',
      receiverMemberId: 'm2',
      amount: 600.0,
      currency: 'INR',
      settledAt: DateTime(2026, 10, 5),
      paymentMethod: 'UPI / Online Transfer',
    );

    final allSettlements = [s1, s2, s3];

    test('extracts unique payment methods properly', () {
      final methods = allSettlements
          .map((s) => s.paymentMethod.trim())
          .where((m) => m.isNotEmpty)
          .toSet()
          .toList();

      expect(methods, containsAll(['UPI / Online Transfer', 'Cash / Direct']));
      expect(methods.length, equals(2));
    });

    test('filters settlements dynamically by selected method', () {
      const selectedFilter = 'UPI / Online Transfer';
      final filtered = allSettlements.where((s) => s.paymentMethod == selectedFilter).toList();
      expect(filtered.length, equals(2));
      expect(filtered, containsAll([s1, s3]));

      const cashFilter = 'Cash / Direct';
      final cashFiltered = allSettlements.where((s) => s.paymentMethod == cashFilter).toList();
      expect(cashFiltered.length, equals(1));
      expect(cashFiltered.first, equals(s2));
    });
  });

  group('Loop 64: Map Tab Zoom Level Clamping Bounds', () {
    test('clamps zoom levels strictly within accessible boundaries [3.0, 18.0]', () {
      double zoom = 17.5;
      zoom = (zoom + 1.0).clamp(3.0, 18.0);
      expect(zoom, equals(18.0));

      // Attempting zoom in past max
      zoom = (zoom + 1.0).clamp(3.0, 18.0);
      expect(zoom, equals(18.0));

      // Zooming out
      zoom = 3.5;
      zoom = (zoom - 1.0).clamp(3.0, 18.0);
      expect(zoom, equals(3.0));

      // Attempting zoom out past min
      zoom = (zoom - 1.0).clamp(3.0, 18.0);
      expect(zoom, equals(3.0));
    });
  });

  group('Loop 65: Members Tab Companion Search & Phone Number Validation', () {
    test('cleans raw phone numbers safely for tel: URL scheme', () {
      const rawWithSpaces = '+91 98765 43210';
      final clean1 = rawWithSpaces.replaceAll(RegExp(r'[^\d+]'), '');
      expect(clean1, equals('+919876543210'));

      const rawWithDashes = '022-2456-7890';
      final clean2 = rawWithDashes.replaceAll(RegExp(r'[^\d+]'), '');
      expect(clean2, equals('02224567890'));

      const rawEmpty = '   ';
      final clean3 = rawEmpty.replaceAll(RegExp(r'[^\d+]'), '');
      expect(clean3, isEmpty);
    });

    test('filters members by name, email, or phone query', () {
      final members = testTrip.members;

      // Query by name
      final byName = members.where((m) => m.name.toLowerCase().contains('priya')).toList();
      expect(byName.length, equals(1));
      expect(byName.first.id, equals('m2'));

      // Query by email domain
      final byEmail = members.where((m) => m.email?.toLowerCase().contains('example.com') ?? false).toList();
      expect(byEmail.length, equals(3));

      // Query by phone
      final byPhone = members.where((m) => m.phoneNumber?.contains('43210') ?? false).toList();
      expect(byPhone.length, equals(1));
      expect(byPhone.first.id, equals('m1'));
    });
  });

  group('Loop 66: Audit Log Sheet Date / Time Range Quick Filter Logic', () {
    final now = DateTime.now();
    final todayLog = TripAuditLog(
      id: 'log1',
      tripId: testTrip.id,
      actionType: 'create_expense',
      itemTitle: 'Today Dhaba Chai',
      performedByMemberId: 'm1',
      performedByName: 'Arun',
      timestamp: now,
    );
    final fiveDaysAgoLog = TripAuditLog(
      id: 'log2',
      tripId: testTrip.id,
      actionType: 'add_stoppage',
      itemTitle: 'Fort Stop',
      performedByMemberId: 'm2',
      performedByName: 'Priya',
      timestamp: now.subtract(const Duration(days: 5)),
    );
    final twoWeeksAgoLog = TripAuditLog(
      id: 'log3',
      tripId: testTrip.id,
      actionType: 'create_trip',
      itemTitle: 'Trip Initialized',
      performedByMemberId: 'm1',
      performedByName: 'Arun',
      timestamp: now.subtract(const Duration(days: 14)),
    );

    final allLogs = [todayLog, fiveDaysAgoLog, twoWeeksAgoLog];

    test('filters logs for "today" range correctly', () {
      final todayResults = allLogs.where((l) {
        return l.timestamp.year == now.year &&
            l.timestamp.month == now.month &&
            l.timestamp.day == now.day;
      }).toList();

      expect(todayResults.length, equals(1));
      expect(todayResults.first.id, equals('log1'));
    });

    test('filters logs for "7days" range correctly', () {
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      final last7DaysResults = allLogs.where((l) => !l.timestamp.isBefore(sevenDaysAgo)).toList();

      expect(last7DaysResults.length, equals(2));
      expect(last7DaysResults, containsAll([todayLog, fiveDaysAgoLog]));
      expect(last7DaysResults, isNot(contains(twoWeeksAgoLog)));
    });

    test('returns all logs for "all" range', () {
      expect(allLogs.length, equals(3));
    });
  });

  group('Loop 67: Activity Hub ProximityAlert Date Matching Logic', () {
    test('matches and marks alerts for specific day correctly', () {
      final now = DateTime.now();
      final a1 = ProximityAlert(
        id: 'al1',
        tripId: testTrip.id,
        type: AlertType.billAdded,
        title: 'Today Bill',
        message: 'Bill logged',
        senderMemberId: 'm1',
        senderName: 'Arun',
        timestamp: now,
        isRead: false,
      );
      final a2 = ProximityAlert(
        id: 'al2',
        tripId: testTrip.id,
        type: AlertType.stoppageAdded,
        title: 'Yesterday Stop',
        message: 'Stop logged',
        senderMemberId: 'm2',
        senderName: 'Priya',
        timestamp: now.subtract(const Duration(days: 1)),
        isRead: false,
      );

      final alerts = [a1, a2];
      final targetDay = DateTime(now.year, now.month, now.day);

      // Simulate markAlertsAsReadForDate
      final updated = alerts.map((a) {
        final alertDay = DateTime(a.timestamp.year, a.timestamp.month, a.timestamp.day);
        if (alertDay == targetDay) {
          return a.copyWith(isRead: true);
        }
        return a;
      }).toList();

      expect(updated[0].isRead, isTrue);
      expect(updated[1].isRead, isFalse);
    });
  });

  group('Loop 68: Memories Tab Double-Tap Like & Favorites Filtering', () {
    test('toggles like state correctly for currentUser', () {
      final mem = Memory(
        id: 'mem1',
        tripId: testTrip.id,
        stoppageId: 's1',
        uploadedByMemberId: 'm2',
        mediaPath: 'path/to/sunset.jpg',
        createdAt: DateTime.now(),
        likedByMemberIds: const ['m3'],
      );

      // Current user is m1
      const currentUserId = 'm1';
      final likesList1 = List<String>.from(mem.likedByMemberIds);
      if (likesList1.contains(currentUserId)) {
        likesList1.remove(currentUserId);
      } else {
        likesList1.add(currentUserId);
      }

      final likedMem = mem.copyWith(likedByMemberIds: likesList1);
      expect(likedMem.likedByMemberIds, containsAll(['m3', 'm1']));
      expect(likedMem.likedByMemberIds.contains(currentUserId), isTrue);

      // Toggle again (unlike)
      final likesList2 = List<String>.from(likedMem.likedByMemberIds);
      if (likesList2.contains(currentUserId)) {
        likesList2.remove(currentUserId);
      } else {
        likesList2.add(currentUserId);
      }
      final unlikedMem = likedMem.copyWith(likedByMemberIds: likesList2);
      expect(unlikedMem.likedByMemberIds.contains(currentUserId), isFalse);
      expect(unlikedMem.likedByMemberIds, equals(['m3']));
    });
  });
}
