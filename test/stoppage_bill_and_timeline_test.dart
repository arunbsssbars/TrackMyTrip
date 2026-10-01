import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/models/stoppage.dart';
import 'package:trackmytrip/models/expense.dart';
import 'package:trackmytrip/models/expense_split.dart';
import 'package:trackmytrip/models/trip_member.dart';
import 'package:trackmytrip/screens/stoppage/add_stoppage_dialog.dart';

void main() {
  group('Stoppage Bill Integration & Category Mapping', () {
    test('maps stoppage categories to appropriate expense categories', () {
      expect(
        AddStoppageDialog.mapStoppageToExpenseCategory('Fuel Pump'),
        equals('Fuel / Gas'),
      );
      expect(
        AddStoppageDialog.mapStoppageToExpenseCategory('Gas Station'),
        equals('Fuel / Gas'),
      );
      expect(
        AddStoppageDialog.mapStoppageToExpenseCategory('Gas / Fuel Station'),
        equals('Fuel / Gas'),
      );
      expect(
        AddStoppageDialog.mapStoppageToExpenseCategory('Petrol Pump'),
        equals('Fuel / Gas'),
      );
      expect(
        AddStoppageDialog.mapStoppageToExpenseCategory('Food & Cafe'),
        equals('Food & Drinks'),
      );
      expect(
        AddStoppageDialog.mapStoppageToExpenseCategory('Restaurant'),
        equals('Food & Drinks'),
      );
      expect(
        AddStoppageDialog.mapStoppageToExpenseCategory('Hotel & Stay'),
        equals('Accommodation'),
      );
      expect(
        AddStoppageDialog.mapStoppageToExpenseCategory('Lodge'),
        equals('Accommodation'),
      );
      expect(
        AddStoppageDialog.mapStoppageToExpenseCategory('Toll & Transit'),
        equals('Transport & Toll'),
      );
      expect(
        AddStoppageDialog.mapStoppageToExpenseCategory('Toll Plaza'),
        equals('Transport & Toll'),
      );
      expect(
        AddStoppageDialog.mapStoppageToExpenseCategory('Sightseeing'),
        equals('Activities & Tickets'),
      );
      expect(
        AddStoppageDialog.mapStoppageToExpenseCategory('Shopping'),
        equals('Shopping & Souvenirs'),
      );
      expect(
        AddStoppageDialog.mapStoppageToExpenseCategory('Rest Stop'),
        equals('Snacks & Refreshment'),
      );
      expect(
        AddStoppageDialog.mapStoppageToExpenseCategory('Hospital / Clinic'),
        equals('Emergency & Misc'),
      );
      expect(
        AddStoppageDialog.mapStoppageToExpenseCategory('Other'),
        equals('Emergency & Misc'),
      );
    });

    test('creates linked Expense with valid stoppageId and member splits', () {
      final now = DateTime.now();
      final stoppage = Stoppage(
        id: 'stop-fuel-101',
        tripId: 'trip-1',
        name: 'HP Petrol Pump',
        latitude: 28.6139,
        longitude: 77.2090,
        address: 'Connaught Place, New Delhi',
        category: 'Gas / Fuel Station',
        arrivedAt: now,
        createdBy: 'user-1',
        notes: 'Full tank refuel',
      );

      final members = [
        const TripMember(id: 'user-1', name: 'Alice', email: 'alice@example.com'),
        const TripMember(id: 'user-2', name: 'Bob', email: 'bob@example.com'),
        const TripMember(id: 'user-3', name: 'Charlie', email: 'charlie@example.com'),
      ];

      const totalAmount = 3000.0;
      final perPersonAmount = totalAmount / members.length; // 1000.0 each
      final splits = members.map((m) => ExpenseSplit(
        memberId: m.id,
        allocatedAmount: double.parse(perPersonAmount.toStringAsFixed(2)),
        isIncluded: true,
      )).toList();

      final expense = Expense(
        id: 'exp-101',
        tripId: 'trip-1',
        stoppageId: stoppage.id,
        title: 'HP Petrol Pump Bill',
        totalAmount: totalAmount,
        currency: 'INR',
        paidByMemberId: 'user-1',
        splitType: SplitType.equal,
        category: AddStoppageDialog.mapStoppageToExpenseCategory(stoppage.category),
        createdAt: now,
        splits: splits,
        receiptImagePath: '/mock/path/receipt.jpg',
      );

      // Verify linkages and calculations
      expect(expense.stoppageId, equals(stoppage.id));
      expect(expense.category, equals('Fuel / Gas'));
      expect(expense.splits.length, equals(3));
      expect(expense.splits.map((s) => s.allocatedAmount).reduce((a, b) => a + b), equals(3000.0));
      expect(expense.paidByMemberId, equals('user-1'));
      expect(expense.receiptImagePath, equals('/mock/path/receipt.jpg'));

      // Verify JSON serialization round-trip retains stoppageId
      final json = expense.toJson();
      expect(json['stoppageId'], equals('stop-fuel-101'));
      final restoredExpense = Expense.fromJson(json);
      expect(restoredExpense.stoppageId, equals('stop-fuel-101'));
      expect(restoredExpense.totalAmount, equals(3000.0));
      expect(restoredExpense.category, equals('Fuel / Gas'));
    });
  });
}
