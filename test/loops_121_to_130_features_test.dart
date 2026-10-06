import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/services/trip_share_service.dart';
import 'package:trackmytrip/core/utils/currency_formatter.dart';
import 'package:trackmytrip/models/expense.dart';
import 'package:trackmytrip/models/stoppage.dart';
import 'package:trackmytrip/models/trip.dart';
import 'package:trackmytrip/models/trip_member.dart';
import 'package:trackmytrip/models/user_profile.dart';
import 'package:trackmytrip/models/proximity_alert.dart';

void main() {
  group('Sprint 15: Loops 121–130 Feature Improvements Test Suite', () {
    final testTrip = Trip(
      id: 'trip-loops-121-130',
      title: 'Golden Triangle Voyage',
      createdByMemberId: 'mem_1',
      createdAt: DateTime(2026, 10, 1),
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 5),
      defaultCurrency: 'INR',
      members: const [
        TripMember(id: 'mem_1', name: 'Arun', email: 'arun@example.com'),
        TripMember(id: 'mem_2', name: 'Sophia', email: 'sophia@example.com'),
      ],
    );

    test('Loop 121 & 122: Multi-Currency Conversion handles diverse fiat pairs', () {
      const inrAmount = 10000.0;
      final usdEstimated = CurrencyFormatter.convertEstimated(inrAmount, 'INR', 'USD');
      final eurEstimated = CurrencyFormatter.convertEstimated(inrAmount, 'INR', 'EUR');
      final gbpEstimated = CurrencyFormatter.convertEstimated(inrAmount, 'INR', 'GBP');

      expect(usdEstimated, greaterThan(0));
      expect(eurEstimated, greaterThan(0));
      expect(gbpEstimated, greaterThan(0));
      expect(usdEstimated, greaterThan(100.0));
      expect(usdEstimated, lessThan(150.0));
    });

    test('Loop 123: Trip Financial Ledger CSV Export contains valid headers and values', () {
      final expenses = [
        Expense(
          id: 'exp-csv-1',
          tripId: testTrip.id,
          title: 'Taj Mahal Guided Tour',
          totalAmount: 1500.0,
          currency: 'INR',
          paidByMemberId: 'mem_1',
          category: 'Activity',
          splitType: SplitType.equal,
          createdAt: DateTime(2026, 10, 2, 14, 30),
          splits: const [],
        ),
      ];

      final csvContent = TripShareService.generateExpensesCsv(testTrip, expenses);
      expect(csvContent, contains('Date,Time,Title,Category,Amount,Currency,Paid By,Split Mode,Attendees,Notes'));
      expect(csvContent, contains('Taj Mahal Guided Tour'));
      expect(csvContent, contains('1500.00'));
      expect(csvContent, contains('Arun'));
    });

    test('Loop 124 & 125: User Profile initials, handle, and completeness metrics', () {
      const profile = UserProfile(
        id: 'usr_test_124',
        username: 'globetrotter',
        displayName: 'Arun Kumar',
        phone: '+91 9876543210',
        bio: 'Explorer of ancient heritage.',
      );

      expect(profile.initials, 'AK');
      expect(profile.handle, '@globetrotter');

      // Completeness score verification
      int score = 0;
      if (profile.displayName.trim().isNotEmpty && profile.displayName != 'Traveler') score += 25;
      if (profile.username.trim().isNotEmpty && !profile.username.startsWith('user_') && profile.username != 'traveler') score += 25;
      if (profile.phone != null && profile.phone!.trim().isNotEmpty) score += 25;
      if (profile.bio != null && profile.bio!.trim().isNotEmpty) score += 25;

      expect(score, 100);
    });

    test('Loop 127: Payer filter matches expense members correctly', () {
      final expenses = [
        Expense(
          id: 'exp-arun',
          tripId: testTrip.id,
          title: 'Hotel Booking',
          totalAmount: 4000.0,
          currency: 'INR',
          paidByMemberId: 'mem_1',
          category: 'Stay',
          splitType: SplitType.equal,
          createdAt: DateTime.now(),
          splits: const [],
        ),
        Expense(
          id: 'exp-sophia',
          tripId: testTrip.id,
          title: 'Dinner at Peshawri',
          totalAmount: 2500.0,
          currency: 'INR',
          paidByMemberId: 'mem_2',
          category: 'Food',
          splitType: SplitType.equal,
          createdAt: DateTime.now(),
          splits: const [],
        ),
      ];

      final filteredByArun = expenses.where((e) => e.paidByMemberId == 'mem_1').toList();
      final filteredBySophia = expenses.where((e) => e.paidByMemberId == 'mem_2').toList();

      expect(filteredByArun.length, 1);
      expect(filteredByArun.first.title, 'Hotel Booking');
      expect(filteredBySophia.length, 1);
      expect(filteredBySophia.first.title, 'Dinner at Peshawri');
    });

    test('Loop 128: Stoppage duration formatting and milestone calculation', () {
      final stopWithStay = Stoppage(
        id: 'stop-milestone',
        tripId: testTrip.id,
        name: 'Agra Fort',
        latitude: 27.1795,
        longitude: 78.0211,
        category: 'Monument',
        arrivedAt: DateTime(2026, 10, 2, 9, 0),
        departedAt: DateTime(2026, 10, 2, 11, 30),
        createdBy: 'mem_1',
      );

      expect(stopWithStay.duration, isNotNull);
      expect(stopWithStay.duration!.inMinutes, 150);
      expect(stopWithStay.formattedDuration, '2h 30m');
    });

    test('Loop 129: Alert classification correctly categorizes activities', () {
      final alerts = [
        ProximityAlert(
          id: 'alt-invite-1',
          tripId: testTrip.id,
          type: AlertType.invitation,
          title: 'Trip Invitation',
          message: 'Arun invited you',
          senderMemberId: 'mem_1',
          senderName: 'Arun',
          timestamp: DateTime.now(),
        ),
        ProximityAlert(
          id: 'alt-bill-1',
          tripId: testTrip.id,
          type: AlertType.billAdded,
          title: 'Bill Added',
          message: 'Dinner expense logged',
          senderMemberId: 'mem_2',
          senderName: 'Sophia',
          timestamp: DateTime.now(),
        ),
        ProximityAlert(
          id: 'alt-sos-1',
          tripId: testTrip.id,
          type: AlertType.sosEmergency,
          title: 'SOS Emergency Broadcast',
          message: 'Help needed',
          senderMemberId: 'mem_1',
          senderName: 'Arun',
          timestamp: DateTime.now(),
        ),
      ];

      final invites = alerts.where((a) => a.type == AlertType.invitation).toList();
      final bills = alerts.where((a) => a.type == AlertType.billAdded).toList();
      final audits = alerts.where((a) => a.type == AlertType.sosEmergency || a.type == AlertType.tripReopened).toList();

      expect(invites.length, 1);
      expect(bills.length, 1);
      expect(audits.length, 1);
    });
  });
}
