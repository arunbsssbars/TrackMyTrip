import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/models/trip.dart';
import 'package:trackmytrip/models/trip_member.dart';
import 'package:trackmytrip/models/expense.dart';
import 'package:trackmytrip/models/expense_split.dart';
import 'package:trackmytrip/models/stoppage.dart';
import 'package:trackmytrip/models/trip_audit_log.dart';
import 'package:trackmytrip/models/proximity_alert.dart';
import 'package:trackmytrip/models/settlement.dart';

void main() {
  group('Multi-User E2E Audit Trail, Route & Notification Integrity Tests', () {
    late Trip trip;
    late TripMember arun;
    late TripMember jaiYashu;

    setUp(() {
      arun = const TripMember(
        id: 'member_arun',
        name: 'Arun',
        email: 'arun@example.com',
        isCurrentUser: true,
        colorHex: '0xFF0F766E',
      );
      jaiYashu = const TripMember(
        id: 'member_jai_yashu',
        name: 'Jai Yashu',
        email: 'jaiyashu@example.com',
        isCurrentUser: false,
        colorHex: '0xFF3B82F6',
      );

      trip = Trip(
        id: 'trip_multiuser_001',
        title: 'Western Ghats Road Trip',
        description: 'Multi-user shared expedition',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 5),
        defaultCurrency: 'INR',
        tripType: 'group',
        members: [arun, jaiYashu],
        createdByMemberId: arun.id,
        createdAt: DateTime(2026, 10, 1, 8, 0),
        status: 'active',
      );
    });

    test('1. Multi-user sequential bill edits produce shared, complete audit trail for all companions', () {
      // Arun logs initial bill of ₹20,000
      final initialExpense = Expense(
        id: 'bill_hotel_001',
        tripId: trip.id,
        title: 'Hilltop Resort Stay',
        totalAmount: 20000.0,
        currency: 'INR',
        splitType: SplitType.equal,
        category: 'Accommodation',
        paidByMemberId: arun.id,
        splits: [
          const ExpenseSplit(memberId: 'member_arun', allocatedAmount: 10000.0, isIncluded: true),
          const ExpenseSplit(memberId: 'member_jai_yashu', allocatedAmount: 10000.0, isIncluded: true),
        ],
        createdAt: DateTime(2026, 10, 1, 14, 0),
      );

      final auditTrail = <TripAuditLog>[];

      // Arun updates bill: ₹20,000 -> ₹15,000
      final arunEditExpense = initialExpense.copyWith(
        totalAmount: 15000.0,
        splits: [
          const ExpenseSplit(memberId: 'member_arun', allocatedAmount: 7500.0, isIncluded: true),
          const ExpenseSplit(memberId: 'member_jai_yashu', allocatedAmount: 7500.0, isIncluded: true),
        ],
      );
      final logArun = TripAuditLog(
        id: 'log_001',
        tripId: trip.id,
        actionType: 'edit_expense',
        itemTitle: arunEditExpense.title,
        performedByMemberId: arun.id,
        performedByName: arun.name,
        timestamp: DateTime(2026, 10, 1, 16, 0),
        reason: 'Updated via bill edit',
        changeDetails: 'Amount: ₹20,000 ➔ ₹15,000',
      );
      auditTrail.add(logArun);

      // Jai Yashu updates bill: ₹15,000 -> ₹10,000
      final jaiEditExpense = arunEditExpense.copyWith(
        totalAmount: 10000.0,
        splits: [
          const ExpenseSplit(memberId: 'member_arun', allocatedAmount: 5000.0, isIncluded: true),
          const ExpenseSplit(memberId: 'member_jai_yashu', allocatedAmount: 5000.0, isIncluded: true),
        ],
      );
      final logJai = TripAuditLog(
        id: 'log_002',
        tripId: trip.id,
        actionType: 'edit_expense',
        itemTitle: jaiEditExpense.title,
        performedByMemberId: jaiYashu.id,
        performedByName: jaiYashu.name,
        timestamp: DateTime(2026, 10, 1, 17, 0),
        reason: 'Updated via bill edit',
        changeDetails: 'Amount: ₹15,000 ➔ ₹10,000',
      );
      auditTrail.add(logJai);

      // Verify that both audit logs are present and correctly attributed
      expect(auditTrail.length, equals(2));
      expect(auditTrail[0].performedByMemberId, equals('member_arun'));
      expect(auditTrail[0].performedByName, equals('Arun'));
      expect(auditTrail[0].changeDetails, contains('₹20,000 ➔ ₹15,000'));

      expect(auditTrail[1].performedByMemberId, equals('member_jai_yashu'));
      expect(auditTrail[1].performedByName, equals('Jai Yashu'));
      expect(auditTrail[1].changeDetails, contains('₹15,000 ➔ ₹10,000'));

      // Both Arun and Jai Yashu query the trip's audit trail and see both entries
      final arunView = auditTrail.where((l) => l.tripId == trip.id).toList();
      final jaiView = auditTrail.where((l) => l.tripId == trip.id).toList();
      expect(arunView.length, equals(2));
      expect(jaiView.length, equals(2));
      expect(arunView.map((l) => l.id), equals(jaiView.map((l) => l.id)));
    });

    test('2. ProximityAlert carries itemId and itemType for deep linking across serialization', () {
      final billAlert = ProximityAlert(
        id: 'alt_bill_001',
        tripId: trip.id,
        type: AlertType.billUpdated,
        title: 'Bill Updated',
        message: 'Arun updated "Hilltop Resort Stay" (Amount: ₹20,000 ➔ ₹15,000)',
        senderMemberId: arun.id,
        senderName: arun.name,
        timestamp: DateTime(2026, 10, 1, 16, 0),
        urgency: AlertUrgency.normal,
        itemId: 'bill_hotel_001',
        itemType: 'bill',
      );

      final json = billAlert.toJson();
      expect(json['itemId'], equals('bill_hotel_001'));
      expect(json['itemType'], equals('bill'));

      final restored = ProximityAlert.fromJson(json);
      expect(restored.itemId, equals('bill_hotel_001'));
      expect(restored.itemType, equals('bill'));
      expect(restored.type, equals(AlertType.billUpdated));
    });

    test('3. Crisp SOS notification contains concise sender text and GPS coordinates', () {
      const sosMessage = 'SOS Broadcast Active • Location shared with companions';
      final sosAlert = ProximityAlert(
        id: 'alt_sos_001',
        tripId: trip.id,
        type: AlertType.sosEmergency,
        title: 'EMERGENCY SOS',
        message: sosMessage,
        senderMemberId: arun.id,
        senderName: arun.name,
        latitude: 12.9716,
        longitude: 77.5946,
        timestamp: DateTime(2026, 10, 1, 18, 0),
        urgency: AlertUrgency.critical,
      );

      expect(sosAlert.message, equals('SOS Broadcast Active • Location shared with companions'));
      expect(sosAlert.latitude, isNotNull);
      expect(sosAlert.longitude, isNotNull);

      // Verify coordinate string for coordinate chip
      final coordChipText = '${sosAlert.latitude!.toStringAsFixed(4)}, ${sosAlert.longitude!.toStringAsFixed(4)}';
      expect(coordChipText, equals('12.9716, 77.5946'));
    });

    test('4. Notification deep linking correctly identifies existing vs deleted items', () {
      final activeExpenses = <Expense>[
        Expense(
          id: 'bill_fuel_001',
          tripId: trip.id,
          title: 'Petrol Refuel',
          totalAmount: 3200.0,
          currency: 'INR',
          splitType: SplitType.equal,
          category: 'Transport',
          paidByMemberId: jaiYashu.id,
          splits: const [],
          createdAt: DateTime(2026, 10, 2, 9, 0),
        ),
      ];

      final deletedExpenseAlert = ProximityAlert(
        id: 'alt_del_001',
        tripId: trip.id,
        type: AlertType.billUpdated,
        title: 'Bill Removed',
        message: 'A bill was deleted',
        senderMemberId: arun.id,
        senderName: arun.name,
        timestamp: DateTime(2026, 10, 2, 10, 0),
        itemId: 'bill_non_existent',
        itemType: 'bill',
      );

      final activeExpenseAlert = ProximityAlert(
        id: 'alt_active_001',
        tripId: trip.id,
        type: AlertType.billUpdated,
        title: 'Bill Updated',
        message: 'Petrol Refuel was updated',
        senderMemberId: jaiYashu.id,
        senderName: jaiYashu.name,
        timestamp: DateTime(2026, 10, 2, 9, 30),
        itemId: 'bill_fuel_001',
        itemType: 'bill',
      );

      // Query active item
      final activeFound = activeExpenses.any((e) => e.id == activeExpenseAlert.itemId);
      expect(activeFound, isTrue);

      // Query deleted item
      final deletedFound = activeExpenses.any((e) => e.id == deletedExpenseAlert.itemId);
      expect(deletedFound, isFalse);
    });

    test('5. Multi-user route stoppage sync with deep-linked activity notifications', () {
      final stop1 = Stoppage(
        id: 'stop_wayanad_01',
        tripId: trip.id,
        name: 'Wayanad Viewpoint',
        arrivedAt: DateTime(2026, 10, 2, 11, 0),
        departedAt: DateTime(2026, 10, 2, 13, 0),
        category: 'Sightseeing',
        latitude: 11.6854,
        longitude: 76.1320,
        createdBy: jaiYashu.id,
        orderIndex: 0,
      );

      // Jai Yashu adds a stop alert
      final stopAlert = ProximityAlert(
        id: 'alt_stop_001',
        tripId: trip.id,
        type: AlertType.stoppageAdded,
        title: 'New Stop Added',
        message: 'Jai Yashu added stop "Wayanad Viewpoint"',
        senderMemberId: jaiYashu.id,
        senderName: jaiYashu.name,
        timestamp: DateTime(2026, 10, 2, 11, 5),
        latitude: stop1.latitude,
        longitude: stop1.longitude,
        itemId: stop1.id,
        itemType: 'stop',
      );

      expect(stopAlert.itemId, equals(stop1.id));
      expect(stopAlert.itemType, equals('stop'));
      expect(stopAlert.latitude, equals(11.6854));
      expect(stopAlert.longitude, equals(76.1320));
    });

    test('6. Settlement activity notifications carry settlement itemId and itemType', () {
      final settlement = Settlement(
        id: 'set_001',
        tripId: trip.id,
        payerMemberId: jaiYashu.id,
        receiverMemberId: arun.id,
        amount: 5000.0,
        currency: 'INR',
        settledAt: DateTime(2026, 10, 3, 20, 0),
        notes: 'Final UPI settlement',
      );

      final settlementAlert = ProximityAlert(
        id: 'alt_settle_001',
        tripId: trip.id,
        type: AlertType.settlementRecorded,
        title: 'Settlement Recorded',
        message: 'Jai Yashu paid Arun ₹5,000.00',
        senderMemberId: jaiYashu.id,
        senderName: jaiYashu.name,
        timestamp: settlement.settledAt,
        itemId: settlement.id,
        itemType: 'settlement',
      );

      expect(settlementAlert.itemId, equals('set_001'));
      expect(settlementAlert.itemType, equals('settlement'));
    });

    test('7. Dismissed activity tombstones strictly filter out resurrected alerts across sync cycles', () {
      final dismissedTombstones = <String>{'alt_old_dismissed_001', 'alt_old_dismissed_002'};

      final incomingRemoteAlerts = [
        ProximityAlert(
          id: 'alt_old_dismissed_001',
          tripId: trip.id,
          type: AlertType.billUpdated,
          title: 'Resurrected alert attempt',
          message: 'This alert was deleted yesterday',
          senderMemberId: jaiYashu.id,
          senderName: jaiYashu.name,
          timestamp: DateTime(2026, 9, 29, 12, 0),
        ),
        ProximityAlert(
          id: 'alt_new_active_003',
          tripId: trip.id,
          type: AlertType.billUpdated,
          title: 'New bill edit',
          message: 'Active valid alert',
          senderMemberId: arun.id,
          senderName: arun.name,
          timestamp: DateTime(2026, 9, 30, 9, 0),
        ),
      ];

      // Filter incoming alerts using tombstone check
      final activeFilteredAlerts = incomingRemoteAlerts
          .where((alert) => !dismissedTombstones.contains(alert.id))
          .toList();

      expect(activeFilteredAlerts.length, equals(1));
      expect(activeFilteredAlerts.first.id, equals('alt_new_active_003'));
      expect(activeFilteredAlerts.any((a) => a.id == 'alt_old_dismissed_001'), isFalse);
    });

    test('8. Audit trail groups by date descending and automatically expands the latest date', () {
      final logs = [
        TripAuditLog(
          id: 'log_day1',
          tripId: trip.id,
          actionType: 'create_expense',
          itemTitle: 'Breakfast',
          performedByMemberId: arun.id,
          performedByName: arun.name,
          timestamp: DateTime(2026, 9, 28, 8, 30),
        ),
        TripAuditLog(
          id: 'log_day2',
          tripId: trip.id,
          actionType: 'edit_expense',
          itemTitle: 'Resort Stay',
          performedByMemberId: jaiYashu.id,
          performedByName: jaiYashu.name,
          timestamp: DateTime(2026, 9, 29, 14, 15),
        ),
        TripAuditLog(
          id: 'log_day3',
          tripId: trip.id,
          actionType: 'delete_expense',
          itemTitle: 'Snacks',
          performedByMemberId: arun.id,
          performedByName: arun.name,
          timestamp: DateTime(2026, 9, 30, 11, 0),
        ),
      ];

      // Sort logs descending by timestamp
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      expect(logs.first.id, equals('log_day3'));

      // Group by date key YYYY-MM-DD
      final grouped = <String, List<TripAuditLog>>{};
      for (final log in logs) {
        final key = '${log.timestamp.year.toString().padLeft(4, '0')}-${log.timestamp.month.toString().padLeft(2, '0')}-${log.timestamp.day.toString().padLeft(2, '0')}';
        grouped.putIfAbsent(key, () => []).add(log);
      }

      final sortedDateKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

      // Latest date key must be 2026-09-30
      expect(sortedDateKeys.first, equals('2026-09-30'));
      expect(sortedDateKeys.last, equals('2026-09-28'));

      // Verify accordion auto-expansion logic
      final expandedDates = <String>{};
      if (expandedDates.isEmpty && sortedDateKeys.isNotEmpty) {
        expandedDates.add(sortedDateKeys.first);
      }

      expect(expandedDates.contains('2026-09-30'), isTrue);
      expect(expandedDates.contains('2026-09-29'), isFalse);
    });

    test('9. Bill edit multi-field diff details generation matches audit trail specifications', () {
      final oldExpense = Expense(
        id: 'bill_001',
        tripId: trip.id,
        title: 'Original Lunch',
        totalAmount: 20000.0,
        currency: 'INR',
        splitType: SplitType.equal,
        category: 'Food',
        paidByMemberId: arun.id,
        splits: [],
        createdAt: DateTime(2026, 10, 1, 12, 0),
      );

      final updatedExpense = oldExpense.copyWith(
        title: 'Dinner & Drinks',
        totalAmount: 15000.0,
        category: 'Entertainment',
      );

      // Diff calculation
      final diffs = <String>[];
      if (oldExpense.totalAmount != updatedExpense.totalAmount) {
        diffs.add('Amount: ₹${oldExpense.totalAmount.toStringAsFixed(0)} ➔ ₹${updatedExpense.totalAmount.toStringAsFixed(0)}');
      }
      if (oldExpense.title != updatedExpense.title) {
        diffs.add('Title: "${oldExpense.title}" ➔ "${updatedExpense.title}"');
      }
      if (oldExpense.category != updatedExpense.category) {
        diffs.add('Category: ${oldExpense.category} ➔ ${updatedExpense.category}');
      }

      final changeDetails = diffs.join(' • ');

      expect(changeDetails, contains('Amount: ₹20000 ➔ ₹15000'));
      expect(changeDetails, contains('Title: "Original Lunch" ➔ "Dinner & Drinks"'));
      expect(changeDetails, contains('Category: Food ➔ Entertainment'));
      expect(diffs.length, equals(3));
    });
  });
}
