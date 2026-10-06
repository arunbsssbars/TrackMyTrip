import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/utils/debt_simplifier.dart';
import 'package:trackmytrip/models/settlement.dart';
import 'package:trackmytrip/providers/settlement_provider.dart';

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

  group('Advance Contributions & Trip Kitty Pool Tests', () {
    test('Calculates total advance pooled and member breakdowns correctly', () {
      final s1 = Settlement(
        id: 's1',
        tripId: 'trip_1',
        payerMemberId: 'm1',
        receiverMemberId: 'admin',
        amount: 500.0,
        currency: 'INR',
        settledAt: DateTime.now(),
        paymentMethod: 'UPI',
        isAdvance: true,
      );
      final s2 = Settlement(
        id: 's2',
        tripId: 'trip_1',
        payerMemberId: 'm2',
        receiverMemberId: 'admin',
        amount: 750.0,
        currency: 'INR',
        settledAt: DateTime.now(),
        paymentMethod: 'Cash',
        isAdvance: true,
      );
      final s3 = Settlement(
        id: 's3',
        tripId: 'trip_1',
        payerMemberId: 'm1',
        receiverMemberId: 'm2',
        amount: 200.0,
        currency: 'INR',
        settledAt: DateTime.now(),
        paymentMethod: 'Cash',
        isAdvance: false, // regular debt settlement
      );

      final settlements = [s1, s2, s3];
      final advances = settlements.where((s) => s.isAdvance).toList();
      double total = 0.0;
      final Map<String, double> byMember = {};
      for (final s in advances) {
        total += s.amount;
        byMember[s.payerMemberId] = (byMember[s.payerMemberId] ?? 0.0) + s.amount;
      }

      final summary = TripAdvancePoolSummary(
        totalAdvanceCollected: total,
        memberContributions: byMember,
        contributorCount: byMember.keys.length,
      );

      expect(summary.totalAdvanceCollected, equals(1250.0));
      expect(summary.contributorCount, equals(2));
      expect(summary.memberContributions['m1'], equals(500.0));
      expect(summary.memberContributions['m2'], equals(750.0));
    });
  });
}
