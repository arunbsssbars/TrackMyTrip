import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_tracker_app/core/database/app_database.dart';
import 'package:trip_tracker_app/core/services/ledger_integrity_service.dart';
import 'package:trip_tracker_app/core/services/tombstone_service.dart';
import 'package:trip_tracker_app/models/expense.dart';
import 'package:trip_tracker_app/models/expense_split.dart';
import 'package:trip_tracker_app/models/settlement.dart';
import 'package:trip_tracker_app/models/trip_member.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('TombstoneService Anti-Resurrection Tests', () {
    late SharedPreferences prefs;
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      final inMemoryDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      db = await AppDatabase.open(customDb: inMemoryDb);
      await TombstoneService.init(prefs, db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Trip is not tombstoned initially', () {
      expect(TombstoneService.isTombstoned('trip-999'), isFalse);
    });

    test('Marking trip tombstoned records in memory, prefs, and SQLite', () async {
      const tripId = 'trip-to-delete-123';
      await TombstoneService.markTombstoned(tripId);

      expect(TombstoneService.isTombstoned(tripId), isTrue);

      // Verify SharedPreferences has the tombstone
      final prefsList = prefs.getStringList('tombstoned_trip_ids_v1') ?? [];
      expect(prefsList.contains(tripId), isTrue);

      // Verify SQLite has the tombstone
      final dbSet = await db.getTombstonedTripIds();
      expect(dbSet.contains(tripId), isTrue);
    });

    test('Reloading TombstoneService preserves tombstones across app restarts', () async {
      const tripId = 'trip-preserved-456';
      await TombstoneService.markTombstoned(tripId);

      // Simulate re-init on cold start
      await TombstoneService.init(prefs, db);
      expect(TombstoneService.isTombstoned(tripId), isTrue);
    });
  });

  group('LedgerIntegrityService Financial Engine Tests', () {
    const memberA = TripMember(id: 'memA', name: 'Alice', colorHex: '0xFF10B981');
    const memberB = TripMember(id: 'memB', name: 'Bob', colorHex: '0xFF3B82F6');
    const memberC = TripMember(id: 'memC', name: 'Charlie', colorHex: '0xFFF59E0B');
    final members = [memberA, memberB, memberC];

    test('Equal split with integer cents remainder distribution preserves conservation', () {
      const totalAmount = 100.0;
      final totalCents = (totalAmount * 100).round();
      final baseCents = totalCents ~/ members.length; // 3333
      final remainderCents = totalCents % members.length; // 1

      final splits = <ExpenseSplit>[];
      int distributedRemainder = 0;
      for (final m in members) {
        final allocatedCents = baseCents + (distributedRemainder < remainderCents ? 1 : 0);
        distributedRemainder++;
        splits.add(
          ExpenseSplit(
            memberId: m.id,
            allocatedAmount: allocatedCents / 100.0,
            isIncluded: true,
          ),
        );
      }

      // Member 0: 33.34, Member 1: 33.33, Member 2: 33.33 -> Sum: 100.00
      expect(splits[0].allocatedAmount, 33.34);
      expect(splits[1].allocatedAmount, 33.33);
      expect(splits[2].allocatedAmount, 33.33);

      final sumSplits = splits.fold<double>(0.0, (acc, s) => acc + s.allocatedAmount);
      expect(sumSplits, 100.0);

      final exp = Expense(
        id: 'exp1',
        tripId: 'trip1',
        title: 'Dinner Bill',
        totalAmount: totalAmount,
        currency: 'USD',
        category: 'Food',
        paidByMemberId: memberA.id,
        splitType: SplitType.equal,
        splits: splits,
        createdAt: DateTime.now(),
      );

      expect(LedgerIntegrityService.validateExpenseConservation(exp), isTrue);
    });

    test('Percentage split with remainder cent allocation preserves conservation', () {
      const totalAmount = 100.0; // 33.3%, 33.3%, 33.4%
      final splits = [
        const ExpenseSplit(memberId: 'memA', allocatedAmount: 33.33, percentage: 33.3),
        const ExpenseSplit(memberId: 'memB', allocatedAmount: 33.33, percentage: 33.3),
        const ExpenseSplit(memberId: 'memC', allocatedAmount: 33.34, percentage: 33.4),
      ];

      final exp = Expense(
        id: 'exp2',
        tripId: 'trip1',
        title: 'Fuel Bill',
        totalAmount: totalAmount,
        currency: 'USD',
        category: 'Transport',
        paidByMemberId: memberB.id,
        splitType: SplitType.percentage,
        splits: splits,
        createdAt: DateTime.now(),
      );

      expect(LedgerIntegrityService.validateExpenseConservation(exp), isTrue);
    });

    test('Audit trip ledger confirms zero-sum balance and zero drift', () {
      // Expense: Alice pays 100 for Dinner (split 33.34, 33.33, 33.33)
      final exp1 = Expense(
        id: 'exp1',
        tripId: 'trip1',
        title: 'Dinner',
        totalAmount: 100.0,
        currency: 'USD',
        category: 'Food',
        paidByMemberId: memberA.id,
        splitType: SplitType.equal,
        splits: const [
          ExpenseSplit(memberId: 'memA', allocatedAmount: 33.34),
          ExpenseSplit(memberId: 'memB', allocatedAmount: 33.33),
          ExpenseSplit(memberId: 'memC', allocatedAmount: 33.33),
        ],
        createdAt: DateTime.now(),
      );

      // Bob settles 33.33 to Alice
      final settlement = Settlement(
        id: 'set1',
        tripId: 'trip1',
        payerMemberId: memberB.id,
        receiverMemberId: memberA.id,
        amount: 33.33,
        currency: 'USD',
        settledAt: DateTime.now(),
      );

      final report = LedgerIntegrityService.auditTripLedger(
        members: members,
        expenses: [exp1],
        settlements: [settlement],
      );

      expect(report.isConservationValid, isTrue);
      expect(report.isZeroSumValid, isTrue);
      expect(report.groupImbalanceDrift, 0.0);
      expect(report.isClean, isTrue);

      // Verify individual balances:
      // Alice: paid 100 - consumed 33.34 - received 33.33 = +33.33
      // Bob: paid 0 - consumed 33.33 + paid 33.33 = 0.00 (settled!)
      // Charlie: paid 0 - consumed 33.33 = -33.33
      final balances = LedgerIntegrityService.computeIntegerCentsBalances(
        members: members,
        expenses: [exp1],
        settlements: [settlement],
      );

      expect(balances['memA'], 33.33);
      expect(balances['memB'], 0.00);
      expect(balances['memC'], -33.33);
    });

    test('Settlement serialization and mutation actions roundtrip properly', () {
      final settlement = Settlement(
        id: 'set_test_1',
        tripId: 'trip_100',
        payerMemberId: 'memA',
        receiverMemberId: 'memB',
        amount: 45.50,
        currency: 'USD',
        settledAt: DateTime(2026, 9, 27, 14, 0),
        paymentMethod: 'UPI',
        notes: 'Dinner split',
        isAdvance: false,
      );

      final json = settlement.toJson();
      final revived = Settlement.fromJson(json);

      expect(revived.id, 'set_test_1');
      expect(revived.tripId, 'trip_100');
      expect(revived.payerMemberId, 'memA');
      expect(revived.receiverMemberId, 'memB');
      expect(revived.amount, 45.50);
      expect(revived.paymentMethod, 'UPI');
    });
  });
}
