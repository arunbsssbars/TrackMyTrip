import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/utils/debt_simplifier.dart';

void main() {
  group('DebtSimplifier Resilience & Precision Tests', () {
    test('Simplifies 3-party circular debt to minimal direct transfers', () {
      // Alice is owed 20, Bob owes 10, Charlie owes 10
      final netBalances = {
        'alice': 20.0,
        'bob': -10.0,
        'charlie': -10.0,
      };

      final transfers = DebtSimplifier.simplifyDebts(netBalances);

      expect(transfers.length, equals(2));
      final totalTransferred = transfers.fold<double>(0.0, (acc, t) => acc + t.amount);
      expect(totalTransferred, closeTo(20.0, 0.01));
      expect(transfers.every((t) => t.toMemberId == 'alice'), isTrue);
    });

    test('Handles uneven 3-way split penny rounding without infinite looping', () {
      // 100 / 3 = 33.34, 33.33, 33.33 -> Net: payer +66.67, debtor1 -33.34, debtor2 -33.33
      final netBalances = {
        'alice': 66.67,
        'bob': -33.34,
        'charlie': -33.33,
      };

      final transfers = DebtSimplifier.simplifyDebts(netBalances);

      expect(transfers.length, equals(2));
      final totalTransferred = transfers.fold<double>(0.0, (acc, t) => acc + t.amount);
      expect(totalTransferred, closeTo(66.67, 0.01));
    });

    test('Ignores sub-cent floating point dust (< 0.01)', () {
      final netBalances = {
        'alice': 0.004,
        'bob': -0.004,
      };

      final transfers = DebtSimplifier.simplifyDebts(netBalances);
      expect(transfers.isEmpty, isTrue);
    });
  });
}
