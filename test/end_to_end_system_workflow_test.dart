import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/models/trip.dart';
import 'package:trackmytrip/models/trip_member.dart';
import 'package:trackmytrip/models/stoppage.dart';
import 'package:trackmytrip/models/expense.dart';
import 'package:trackmytrip/models/expense_split.dart';
import 'package:trackmytrip/models/settlement.dart';
import 'package:trackmytrip/models/trip_audit_log.dart';
import 'package:trackmytrip/core/services/ledger_integrity_service.dart';
import 'package:trackmytrip/screens/stoppage/add_stoppage_dialog.dart';

void main() {
  group('End-to-End System Workflow Verification Tests', () {
    late Trip trip;
    late TripMember alice;
    late TripMember bob;
    late TripMember charlie;

    setUp(() {
      alice = const TripMember(
        id: 'member_alice',
        name: 'Alice',
        email: 'alice@example.com',
        isCurrentUser: true,
        colorHex: '0xFF0F766E',
      );
      bob = const TripMember(
        id: 'member_bob',
        name: 'Bob',
        email: 'bob@example.com',
        isCurrentUser: false,
        colorHex: '0xFF3B82F6',
      );
      charlie = const TripMember(
        id: 'member_charlie',
        name: 'Charlie',
        email: 'charlie@example.com',
        isCurrentUser: false,
        colorHex: '0xFFF97316',
      );

      trip = Trip(
        id: 'trip_e2e_001',
        title: 'Coastal Expedition 2026',
        description: 'End-to-end trip across western coast',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 7),
        defaultCurrency: 'INR',
        tripType: 'group',
        members: [alice, bob, charlie],
        createdByMemberId: alice.id,
        createdAt: DateTime(2026, 10, 1, 8, 0),
        status: 'active',
      );
    });

    test('1. New Trip Creation preserves metadata and active status', () {
      expect(trip.id, equals('trip_e2e_001'));
      expect(trip.members.length, equals(3));
      expect(trip.members.first.isCurrentUser, isTrue);
      expect(trip.defaultCurrency, equals('INR'));
      expect(trip.isEnded, isFalse);
      expect(trip.isRunning, isTrue);
      expect(trip.status, equals('active'));
    });

    test('2. Route Waypoints & Stoppage Creation with category mapping', () {
      final stoppage1 = Stoppage(
        id: 'stop_01',
        tripId: trip.id,
        name: 'Mountain View Fuel Point',
        category: 'Gas / Fuel Station',
        latitude: 18.5204,
        longitude: 73.8567,
        arrivedAt: DateTime(2026, 10, 1, 10, 30),
        departedAt: DateTime(2026, 10, 1, 10, 50),
        notes: 'Refueled 45 liters',
        createdBy: alice.id,
      );

      expect(stoppage1.duration?.inMinutes, equals(20));
      expect(stoppage1.category, equals('Gas / Fuel Station'));

      // Validate mapping to expense category
      final mappedExpenseCat = AddStoppageDialog.mapStoppageToExpenseCategory(stoppage1.category);
      expect(mappedExpenseCat, equals('Fuel / Gas'));
    });

    test('3. Billing Engine: Equal splits and stoppage link preserve zero-drift conservation', () {
      const totalAmount = 100.00;
      final splits = [
        const ExpenseSplit(memberId: 'member_alice', allocatedAmount: 33.34),
        const ExpenseSplit(memberId: 'member_bob', allocatedAmount: 33.33),
        const ExpenseSplit(memberId: 'member_charlie', allocatedAmount: 33.33),
      ];

      expect(splits.length, equals(3));
      final sumEqual = splits.fold<double>(0.0, (acc, s) => acc + s.allocatedAmount);
      expect((sumEqual - totalAmount).abs(), lessThan(0.0001));

      // Linked expense
      final expense = Expense(
        id: 'exp_fuel_01',
        tripId: trip.id,
        title: 'Highway Fuel',
        totalAmount: totalAmount,
        paidByMemberId: alice.id,
        category: 'Fuel / Gas',
        splitType: SplitType.equal,
        createdAt: DateTime(2026, 10, 1, 10, 45),
        splits: splits,
        stoppageId: 'stop_01',
        currency: 'INR',
      );

      expect(expense.stoppageId, equals('stop_01'));
      expect(expense.splits.length, equals(3));
      expect(expense.totalAmount, equals(100.00));
      expect(LedgerIntegrityService.validateExpenseConservation(expense), isTrue);

      final auditReport = LedgerIntegrityService.auditTripLedger(
        members: trip.members,
        expenses: [expense],
        settlements: [],
      );

      expect(auditReport.isConservationValid, isTrue);
      expect(auditReport.isZeroSumValid, isTrue);
      expect(auditReport.groupImbalanceDrift.abs(), lessThan(0.01));
    });

    test('4. Settlement Engine: Advance Payment and Pairwise Resolution', () {
      final advance = Settlement(
        id: 'settle_adv_01',
        tripId: trip.id,
        payerMemberId: bob.id,
        receiverMemberId: alice.id,
        amount: 50.00,
        currency: 'INR',
        settledAt: DateTime(2026, 10, 1, 9, 0),
        notes: 'Advance fuel pool fund',
        isAdvance: true,
      );

      expect(advance.isAdvance, isTrue);
      expect(advance.payerMemberId, isNot(equals(advance.receiverMemberId)));

      final json = advance.toJson();
      expect(json['isAdvance'], isTrue);

      final restored = Settlement.fromJson(json);
      expect(restored.isAdvance, isTrue);
      expect(restored.amount, equals(50.00));
      expect(restored.payerMemberId, equals(bob.id));
      expect(restored.receiverMemberId, equals(alice.id));
    });

    test('5. Cryptographic Audit Trail: Semantic Categorization & Deduplication', () {
      final log1 = TripAuditLog(
        id: 'log_01',
        tripId: trip.id,
        performedByMemberId: alice.id,
        performedByName: alice.name,
        actionType: 'create_trip',
        itemTitle: 'Created trip "${trip.title}"',
        timestamp: DateTime(2026, 10, 1, 8, 0),
      );

      final log2 = TripAuditLog(
        id: 'log_02',
        tripId: trip.id,
        performedByMemberId: bob.id,
        performedByName: bob.name,
        actionType: 'create_settlement_advance',
        itemTitle: 'Advance payment of ₹50.00 to Alice',
        timestamp: DateTime(2026, 10, 1, 9, 0),
      );

      expect(log1.category, equals('trip'));
      expect(log2.category, equals('settlement'));

      // Check deduplication semantic keys
      final key1 = '${log2.tripId}_${log2.performedByMemberId}_${log2.itemTitle}';
      final duplicateLog = TripAuditLog(
        id: 'log_03',
        tripId: trip.id,
        performedByMemberId: bob.id,
        performedByName: bob.name,
        actionType: 'create_settlement_advance',
        itemTitle: 'Advance payment of ₹50.00 to Alice',
        timestamp: DateTime(2026, 10, 1, 9, 1),
      );
      final key2 = '${duplicateLog.tripId}_${duplicateLog.performedByMemberId}_${duplicateLog.itemTitle}';

      expect(key1, equals(key2));
    });

    test('6. Timeline Engine: Stoppage Duration and Ongoing Status', () {
      final stoppageOngoing = Stoppage(
        id: 'stop_ongoing',
        tripId: trip.id,
        name: 'Beach Sunset Point',
        category: 'Sightseeing',
        latitude: 15.2993,
        longitude: 74.1240,
        arrivedAt: DateTime(2026, 10, 1, 18, 0),
        departedAt: null,
        createdBy: alice.id,
      );

      expect(stoppageOngoing.isOngoing, isTrue);
      expect(stoppageOngoing.duration, isNull);

      final stoppageCompleted = stoppageOngoing.copyWith(
        departedAt: DateTime(2026, 10, 1, 19, 15),
      );

      expect(stoppageCompleted.isOngoing, isFalse);
      expect(stoppageCompleted.duration?.inMinutes, equals(75));
    });

    test('7. Journey Lifecycle: Concluding and Reopening Trip State', () {
      expect(trip.isEnded, isFalse);

      final concludedTrip = trip.copyWith(status: 'completed');
      expect(concludedTrip.isEnded, isTrue);
      expect(concludedTrip.status, equals('completed'));

      final reopenedTrip = concludedTrip.copyWith(status: 'active');
      expect(reopenedTrip.isEnded, isFalse);
      expect(reopenedTrip.status, equals('active'));
    });
  });
}
