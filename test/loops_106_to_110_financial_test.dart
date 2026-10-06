import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/utils/currency_formatter.dart';
import 'package:trackmytrip/core/utils/debt_simplifier.dart';
import 'package:trackmytrip/models/settlement.dart';
import 'package:trackmytrip/models/trip.dart';
import 'package:trackmytrip/models/trip_member.dart';
import 'package:trackmytrip/screens/trip_detail/tabs/settlement_tab.dart';

void main() {
  group('Sprint 12: Loops 106–110 Financial Ledger & Currency Upgrades Tests', () {
    test('Loop 107: CurrencyFormatter rate estimates and conversions', () {
      final inrRateUsd = CurrencyFormatter.getEstimatedRateToInr('USD');
      expect(inrRateUsd, 86.50);

      final inrRateEur = CurrencyFormatter.getEstimatedRateToInr('EUR');
      expect(inrRateEur, 93.80);

      // Same currency conversion
      expect(CurrencyFormatter.convertEstimated(100.0, 'USD', 'USD'), 100.0);

      // USD to INR conversion: 100 USD * 86.50 = 8650 INR
      final inrConverted = CurrencyFormatter.convertEstimated(100.0, 'USD', 'INR');
      expect(inrConverted, closeTo(8650.0, 0.01));

      // INR to USD conversion: 8650 INR / 86.50 = 100 USD
      final usdConverted = CurrencyFormatter.convertEstimated(8650.0, 'INR', 'USD');
      expect(usdConverted, closeTo(100.0, 0.01));

      // Cross currency: 100 EUR to USD: (100 * 93.80) / 86.50 = 108.439...
      final eurToUsd = CurrencyFormatter.convertEstimated(100.0, 'EUR', 'USD');
      expect(eurToUsd, closeTo(108.44, 0.05));
    });

    test('Loop 109: SettlementTab generateSettlementCsv produces valid RFC CSV output', () {
      final trip = Trip(
        id: 'trip-csv-1',
        title: 'Goa Holiday',
        createdByMemberId: 'm1',
        createdAt: DateTime(2026, 10, 1),
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 5),
        defaultCurrency: 'INR',
        members: const [
          TripMember(id: 'm1', name: 'Alice, Wonder', email: 'alice@example.com'),
          TripMember(id: 'm2', name: 'Bob "The Builder"', email: 'bob@example.com'),
        ],
      );

      final netBalances = {'m1': 500.0, 'm2': -500.0};
      const transfers = [
        DebtTransfer(fromMemberId: 'm2', toMemberId: 'm1', amount: 500.0),
      ];
      final settlements = [
        Settlement(
          id: 'settle-1',
          tripId: 'trip-csv-1',
          payerMemberId: 'm2',
          receiverMemberId: 'm1',
          amount: 250.0,
          currency: 'INR',
          paymentMethod: 'UPI',
          settledAt: DateTime(2026, 10, 3, 14, 30),
          notes: 'Half payment "advance"',
        ),
      ];

      final csv = SettlementTab.generateSettlementCsv(trip, netBalances, transfers, settlements);
      expect(csv, isNotEmpty);
      expect(csv, contains('Type,Member Name,Member ID,Amount,Currency,Status'));
      expect(csv, contains('"Alice, Wonder"'));
      expect(csv, contains('Bob ""The Builder""'));
      expect(csv, contains('Gets Back'));
      expect(csv, contains('Owes'));
      expect(csv, contains('Recommended Transfer'));
      expect(csv, contains('UPI'));
      expect(csv, contains('Half payment ""advance""'));
    });

    test('Loop 106 & 109: Edge cases in empty transfers and balance formatting', () {
      final trip = Trip(
        id: 'trip-csv-2',
        title: 'Settled Trip',
        createdByMemberId: 'u1',
        createdAt: DateTime(2026, 10, 1),
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 2),
        defaultCurrency: 'USD',
        members: const [
          TripMember(id: 'u1', name: 'User 1', email: 'u1@test.com'),
        ],
      );

      final csv = SettlementTab.generateSettlementCsv(trip, {'u1': 0.0}, [], []);
      expect(csv, contains('Settled'));
      expect(csv, contains('USD'));
    });
  });
}
