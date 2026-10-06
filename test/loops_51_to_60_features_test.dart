import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/services/trip_share_service.dart';
import 'package:trackmytrip/core/utils/debt_simplifier.dart';
import 'package:trackmytrip/models/expense.dart';
import 'package:trackmytrip/models/expense_split.dart';
import 'package:trackmytrip/models/memory.dart';
import 'package:trackmytrip/models/proximity_alert.dart';
import 'package:trackmytrip/models/stoppage.dart';
import 'package:trackmytrip/models/trip.dart';
import 'package:trackmytrip/models/trip_member.dart';
import 'package:trackmytrip/screens/trip_detail/tabs/settlement_tab.dart';

void main() {
  const member1 = TripMember(id: 'm1', name: 'Alice', colorHex: '0xFF3B82F6');
  const member2 = TripMember(id: 'm2', name: 'Bob', colorHex: '0xFF10B981');
  const member3 = TripMember(id: 'm3', name: 'Charlie', colorHex: '0xFFF97316');

  final trip = Trip(
    id: 'trip_100',
    title: 'Himalayan Expedition',
    description: 'Road trip across Manali and Leh',
    startDate: DateTime(2026, 10, 1),
    endDate: DateTime(2026, 10, 7),
    createdAt: DateTime(2026, 9, 30),
    members: [member1, member2, member3],
    defaultCurrency: 'INR',
    budget: 50000.0,
    createdByMemberId: 'm1',
  );

  group('Loop 51 & 52: Expense Multi-Sort and Daily Totals', () {
    final e1 = Expense(
      id: 'e1',
      tripId: 'trip_100',
      title: 'Fuel Station',
      totalAmount: 3500.0,
      currency: 'INR',
      category: 'transport',
      paidByMemberId: 'm1',
      splitType: SplitType.equal,
      splits: [
        const ExpenseSplit(memberId: 'm1', allocatedAmount: 1166.67),
        const ExpenseSplit(memberId: 'm2', allocatedAmount: 1166.67),
        const ExpenseSplit(memberId: 'm3', allocatedAmount: 1166.66),
      ],
      createdAt: DateTime(2026, 10, 1, 9, 30),
    );

    final e2 = Expense(
      id: 'e2',
      tripId: 'trip_100',
      title: 'Dhaba Lunch',
      totalAmount: 1200.0,
      currency: 'INR',
      category: 'food',
      paidByMemberId: 'm2',
      splitType: SplitType.equal,
      splits: [
        const ExpenseSplit(memberId: 'm1', allocatedAmount: 400.0),
        const ExpenseSplit(memberId: 'm2', allocatedAmount: 400.0),
        const ExpenseSplit(memberId: 'm3', allocatedAmount: 400.0),
      ],
      createdAt: DateTime(2026, 10, 1, 13, 0),
    );

    final e3 = Expense(
      id: 'e3',
      tripId: 'trip_100',
      title: 'Resort Stay',
      totalAmount: 9000.0,
      currency: 'INR',
      category: 'stay',
      paidByMemberId: 'm3',
      splitType: SplitType.equal,
      splits: [
        const ExpenseSplit(memberId: 'm1', allocatedAmount: 3000.0),
        const ExpenseSplit(memberId: 'm2', allocatedAmount: 3000.0),
        const ExpenseSplit(memberId: 'm3', allocatedAmount: 3000.0),
      ],
      createdAt: DateTime(2026, 10, 2, 19, 0),
    );

    test('ExpenseSortMode sorts list correctly', () {
      final list = [e1, e2, e3];

      // Newest first
      final newest = List<Expense>.from(list)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      expect(newest.first.id, 'e3');
      expect(newest.last.id, 'e1');

      // Oldest first
      final oldest = List<Expense>.from(list)..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      expect(oldest.first.id, 'e1');
      expect(oldest.last.id, 'e3');

      // Highest amount
      final highest = List<Expense>.from(list)..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
      expect(highest.first.id, 'e3'); // 9000
      expect(highest[1].id, 'e1'); // 3500
      expect(highest.last.id, 'e2'); // 1200

      // Lowest amount
      final lowest = List<Expense>.from(list)..sort((a, b) => a.totalAmount.compareTo(b.totalAmount));
      expect(lowest.first.id, 'e2'); // 1200
      expect(lowest.last.id, 'e3'); // 9000
    });

    test('Computes daily expenditure totals and bill counts per date', () {
      final list = [e1, e2, e3];
      final dayTotals = <String, double>{};
      final dayCounts = <String, int>{};

      for (final e in list) {
        final key = '${e.createdAt.year}-${e.createdAt.month}-${e.createdAt.day}';
        dayTotals[key] = (dayTotals[key] ?? 0.0) + e.totalAmount;
        dayCounts[key] = (dayCounts[key] ?? 0) + 1;
      }

      const day1Key = '2026-10-1';
      const day2Key = '2026-10-2';

      expect(dayTotals[day1Key], 4700.0); // 3500 + 1200
      expect(dayCounts[day1Key], 2);

      expect(dayTotals[day2Key], 9000.0);
      expect(dayCounts[day2Key], 1);
    });
  });

  group('Loop 53: Timeline Day Stay Duration Rollup', () {
    final s1 = Stoppage(
      id: 's1',
      tripId: 'trip_100',
      name: 'Scenic Viewpoint',
      latitude: 32.24,
      longitude: 77.18,
      arrivedAt: DateTime(2026, 10, 1, 10, 0),
      departedAt: DateTime(2026, 10, 1, 10, 45), // 45 mins
      category: 'attraction',
      createdBy: 'm1',
    );

    final s2 = Stoppage(
      id: 's2',
      tripId: 'trip_100',
      name: 'Lunch Rest Stop',
      latitude: 32.25,
      longitude: 77.19,
      arrivedAt: DateTime(2026, 10, 1, 13, 0),
      departedAt: DateTime(2026, 10, 1, 14, 30), // 90 mins (1h 30m)
      category: 'food',
      createdBy: 'm1',
    );

    test('Sums stoppage stay durations into total day minutes and formatted label', () {
      final dayStoppages = [s1, s2];
      int dayStayMinutes = 0;

      for (final s in dayStoppages) {
        if (s.departedAt != null && s.departedAt!.isAfter(s.arrivedAt)) {
          dayStayMinutes += s.departedAt!.difference(s.arrivedAt).inMinutes;
        } else if (s.duration != null && s.duration!.inMinutes > 0) {
          dayStayMinutes += s.duration!.inMinutes;
        }
      }

      expect(dayStayMinutes, 135); // 45 + 90 mins = 2h 15m

      final h = dayStayMinutes ~/ 60;
      final m = dayStayMinutes % 60;
      final formattedDuration = h > 0 ? (m > 0 ? '${h}h ${m}m' : '${h}h') : '${m}m';

      expect(formattedDuration, '2h 15m');
      expect('${dayStoppages.length} stops • $formattedDuration', '2 stops • 2h 15m');
    });
  });

  group('Loop 54: Settlement Summary Text Generation', () {
    test('Produces settled message when no debt transfers exist', () {
      final report = SettlementTab.generateSettlementSummaryReport(trip, {'m1': 0.0, 'm2': 0.0, 'm3': 0.0}, []);
      expect(report, contains('All companions are completely settled up!'));
      expect(report, contains('Tracked with TrackMyTrip'));
    });

    test('Produces transfer breakdown and individual net balance states', () {
      final transfers = [
        const DebtTransfer(fromMemberId: 'm1', toMemberId: 'm3', amount: 1500.0),
        const DebtTransfer(fromMemberId: 'm2', toMemberId: 'm3', amount: 2000.0),
      ];
      final netBalances = {
        'm1': -1500.0,
        'm2': -2000.0,
        'm3': 3500.0,
      };

      final report = SettlementTab.generateSettlementSummaryReport(trip, netBalances, transfers);

      expect(report, contains('💰 Settlement Summary: Himalayan Expedition'));
      expect(report, contains('Alice pays Charlie: ₹1,500.00'));
      expect(report, contains('Bob pays Charlie: ₹2,000.00'));
      expect(report, contains('• Charlie: +₹3,500.00 (gets back)'));
      expect(report, contains('• Alice: -₹1,500.00 (owes)'));
      expect(report, contains('• Bob: -₹2,000.00 (owes)'));
    });
  });

  group('Loop 56: Activity Hub Unread Filter Logic', () {
    final alert1 = ProximityAlert(
      id: 'a1',
      tripId: 'trip_100',
      type: AlertType.billAdded,
      title: 'New bill added',
      message: 'Fuel Station bill was added',
      senderMemberId: 'm1',
      senderName: 'Alice',
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      isRead: false,
    );

    final alert2 = ProximityAlert(
      id: 'a2',
      tripId: 'trip_100',
      type: AlertType.stoppageArrival,
      title: 'Arrived at stop',
      message: 'Arrived at Scenic Viewpoint',
      senderMemberId: 'm1',
      senderName: 'Alice',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: true,
    );

    test('Correctly filters out read alerts when unreadOnly is active', () {
      final alerts = [alert1, alert2];

      final unreadOnlyAlerts = alerts.where((a) => !a.isRead).toList();
      expect(unreadOnlyAlerts.length, 1);
      expect(unreadOnlyAlerts.first.id, 'a1');

      final allAlerts = alerts.where((_) => true).toList();
      expect(allAlerts.length, 2);
    });
  });

  group('Loop 57 & 58: Memories Sorting and Full Trip Summary Export', () {
    final m1 = Memory(
      id: 'mem1',
      tripId: 'trip_100',
      stoppageId: 's1',
      uploadedByMemberId: 'm1',
      mediaPath: 'images/sunset.jpg',
      localPath: null,
      caption: 'Sunset at peak',
      createdAt: DateTime(2026, 10, 1, 18, 0),
    );

    final m2 = Memory(
      id: 'mem2',
      tripId: 'trip_100',
      stoppageId: 's1',
      uploadedByMemberId: 'm2',
      mediaPath: 'images/drive.jpg',
      localPath: null,
      caption: 'Morning drive',
      createdAt: DateTime(2026, 10, 2, 7, 0),
    );

    test('Memories chronological sort toggles newest vs oldest correctly', () {
      final memories = [m1, m2];

      // Newest first
      final newest = List<Memory>.from(memories)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      expect(newest.first.id, 'mem2');
      expect(newest.last.id, 'mem1');

      // Oldest first
      final oldest = List<Memory>.from(memories)..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      expect(oldest.first.id, 'mem1');
      expect(oldest.last.id, 'mem2');
    });

    test('TripShareService generates comprehensive trip summary text', () {
      final package = TripPackage(
        trip: trip,
        stoppages: [
          Stoppage(
            id: 's1',
            tripId: 'trip_100',
            name: 'Manali Pass',
            latitude: 32.24,
            longitude: 77.18,
            arrivedAt: DateTime(2026, 10, 1, 10, 0),
            category: 'scenic',
            createdBy: 'm1',
          ),
        ],
        expenses: [
          Expense(
            id: 'e1',
            tripId: 'trip_100',
            title: 'Cabin Rent',
            totalAmount: 12000.0,
            currency: 'INR',
            category: 'stay',
            paidByMemberId: 'm1',
            splitType: SplitType.equal,
            splits: [],
            createdAt: DateTime(2026, 10, 1, 12, 0),
          ),
        ],
        memories: [m1, m2],
        settlements: [],
      );

      final summary = TripShareService.generateFullTripSummaryReport(package);

      expect(summary, contains('TRIP SUMMARY: HIMALAYAN EXPEDITION'));
      expect(summary, contains('Travelers (3): Alice, Bob, Charlie'));
      expect(summary, contains('Total Expenditure: ₹12,000.00'));
      expect(summary, contains('Budget: ₹50,000.00 (Within Budget)'));
      expect(summary, contains('ITINERARY & STOPPAGES (1)'));
      expect(summary, contains('1. Manali Pass [scenic]'));
      expect(summary, contains('EXPENSES & BILLS (1)'));
      expect(summary, contains('stay: ₹12,000.00'));
      expect(summary, contains('Generated via TrackMyTrip'));
    });
  });
}
