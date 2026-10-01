import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/models/expense.dart';
import 'package:trackmytrip/models/expense_split.dart';
import 'package:trackmytrip/models/stoppage.dart';

void main() {
  group('Expense Model & Split Tests', () {
    test('Expense JSON serialization and deserialization works correctly', () {
      final expense = Expense(
        id: 'exp_123',
        tripId: 'trip_456',
        stoppageId: 'stop_789',
        title: 'Highway Fuel Stop',
        totalAmount: 60.0,
        currency: 'USD',
        category: 'Fuel / Gas',
        paidByMemberId: 'member_1',
        splitType: SplitType.equal,
        splits: [
          const ExpenseSplit(memberId: 'member_1', allocatedAmount: 20.0),
          const ExpenseSplit(memberId: 'member_2', allocatedAmount: 20.0),
          const ExpenseSplit(memberId: 'member_3', allocatedAmount: 20.0),
        ],
        createdAt: DateTime(2026, 8, 28, 10, 0),
      );

      final json = expense.toJson();
      final fromJson = Expense.fromJson(json);

      expect(fromJson.id, 'exp_123');
      expect(fromJson.totalAmount, 60.0);
      expect(fromJson.splits.length, 3);
      expect(fromJson.splits.first.allocatedAmount, 20.0);
      expect(fromJson.splitType, SplitType.equal);
      expect(fromJson.stoppageId, 'stop_789');
    });

    test('Stoppage duration and ongoing status calculate properly', () {
      final arrival = DateTime(2026, 8, 28, 12, 0);
      final departure = DateTime(2026, 8, 28, 13, 30);

      final completedStoppage = Stoppage(
        id: 'stop_1',
        tripId: 'trip_1',
        name: 'Cafe Stop',
        latitude: 37.0,
        longitude: -122.0,
        category: 'Food & Cafe',
        arrivedAt: arrival,
        departedAt: departure,
        createdBy: 'user_1',
      );

      expect(completedStoppage.isOngoing, false);
      expect(completedStoppage.duration, const Duration(hours: 1, minutes: 30));

      final activeStoppage = completedStoppage.copyWith(clearDepartedAt: true);
      expect(activeStoppage.isOngoing, true);
      expect(activeStoppage.duration, null);
    });
  });
}
