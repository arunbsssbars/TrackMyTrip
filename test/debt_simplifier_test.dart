import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/utils/debt_simplifier.dart';

void main() {
  group('DebtSimplifier Tests', () {
    test('Simplifies 2-person debt correctly', () {
      final netBalances = {
        'Alice': 50.0, // Alice is owed 50
        'Bob': -50.0, // Bob owes 50
      };

      final transfers = DebtSimplifier.simplifyDebts(netBalances);

      expect(transfers.length, 1);
      expect(transfers.first.fromMemberId, 'Bob');
      expect(transfers.first.toMemberId, 'Alice');
      expect(transfers.first.amount, 50.0);
    });

    test('Simplifies 3-person chain (Bob owes Alice, Alice owes Charlie -> Bob pays Charlie directly)', () {
      // Net: Bob = -30, Alice = 0 (+30 from Bob, -30 to Charlie), Charlie = +30
      final netBalances = {
        'Bob': -30.0,
        'Alice': 0.0,
        'Charlie': 30.0,
      };

      final transfers = DebtSimplifier.simplifyDebts(netBalances);

      expect(transfers.length, 1);
      expect(transfers.first.fromMemberId, 'Bob');
      expect(transfers.first.toMemberId, 'Charlie');
      expect(transfers.first.amount, 30.0);
    });

    test('Complex 4-person group balances resolve to zero', () {
      final netBalances = {
        'Alice': 60.0,
        'Bob': -20.0,
        'Charlie': -30.0,
        'David': -10.0,
      };

      final transfers = DebtSimplifier.simplifyDebts(netBalances);

      // Total transferred should equal total positive balance (60.0)
      final totalTransferred = transfers.fold<double>(0, (sum, t) => sum + t.amount);
      expect(totalTransferred, closeTo(60.0, 0.01));

      // All payments should go to Alice
      for (final t in transfers) {
        expect(t.toMemberId, 'Alice');
      }
    });

    test('Zero balances produce empty transfers list', () {
      final netBalances = {
        'Alice': 0.0,
        'Bob': 0.0,
        'Charlie': 0.0,
      };

      final transfers = DebtSimplifier.simplifyDebts(netBalances);
      expect(transfers.isEmpty, true);
    });
  });
}
