import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_tracker_app/core/services/live_location_tracker_service.dart';
import 'package:trip_tracker_app/models/trip.dart';
import 'package:trip_tracker_app/models/trip_member.dart';
import 'package:trip_tracker_app/widgets/current_trip_hero_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Trip createTestTrip({
    String id = 'trip-101',
    String title = 'Swiss Alps Expedition',
    double? budget = 2000.0,
    String defaultCurrency = 'USD',
    String? shareCode = 'ALPINE-99',
    bool isCompleted = false,
    String status = 'active',
    List<TripMember>? members,
  }) {
    return Trip(
      id: id,
      title: title,
      startDate: DateTime(2026, 7, 10),
      endDate: DateTime(2026, 7, 20),
      createdAt: DateTime(2026, 7, 1),
      budget: budget,
      defaultCurrency: defaultCurrency,
      shareCode: shareCode,
      isCompleted: isCompleted,
      status: status,
      createdByMemberId: 'u1',
      members: members ??
          const [
            TripMember(id: 'u1', name: 'Alice', isCurrentUser: true),
            TripMember(id: 'u2', name: 'Bob'),
          ],
    );
  }

  group('CurrentTripHeroCard Component Tests', () {
    testWidgets('renders basic trip details, telemetry gauges, and share code', (WidgetTester tester) async {
      final trip = createTestTrip();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrentTripHeroCard(
              trip: trip,
              isDark: false,
              totalSpent: 1200.0,
              expenseCount: 4,
              trackingState: const LiveTrackingState(
                currentSpeedKmh: 45.0,
                totalDistanceKm: 12.3,
              ),
              onTapLedger: () {},
            ),
          ),
        ),
      );

      // Verify title & telemetry
      expect(find.text('Swiss Alps Expedition'), findsOneWidget);
      expect(find.byIcon(Icons.groups_rounded), findsOneWidget);
      expect(find.text('ALPINE-99'), findsOneWidget);
      expect(find.text('KM/H SPEED'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text('KM DISTANCE'), findsOneWidget);
      expect(find.text('12.3'), findsOneWidget);
      expect(find.text('Total Spent: '), findsOneWidget);
      expect(find.text('\$1,200.00'), findsOneWidget);
      expect(find.text('4 bills'), findsOneWidget);
    });

    testWidgets('correctly pluralizes single expense entry as 1 bill', (WidgetTester tester) async {
      final trip = createTestTrip();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrentTripHeroCard(
              trip: trip,
              isDark: false,
              totalSpent: 85.0,
              expenseCount: 1,
              onTapLedger: () {},
            ),
          ),
        ),
      );

      expect(find.text('1 bill'), findsOneWidget);
    });

    testWidgets('correctly pluralizes multiple expense entries as N bills', (WidgetTester tester) async {
      final trip = createTestTrip();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrentTripHeroCard(
              trip: trip,
              isDark: false,
              totalSpent: 450.0,
              expenseCount: 3,
              onTapLedger: () {},
            ),
          ),
        ),
      );

      expect(find.text('3 bills'), findsOneWidget);
    });

    testWidgets('displays CONCLUDED badge when trip is completed', (WidgetTester tester) async {
      final completedTrip = createTestTrip(isCompleted: true, status: 'completed');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrentTripHeroCard(
              trip: completedTrip,
              isDark: false,
              totalSpent: 900.0,
              expenseCount: 2,
              onTapLedger: () {},
            ),
          ),
        ),
      );

      expect(find.text('CONCLUDED'), findsOneWidget);
    });

    testWidgets('displays backpack icon when trip is solo', (WidgetTester tester) async {
      final soloTrip = createTestTrip(
        members: const [
          TripMember(id: 'u1', name: 'Solo Traveler', isCurrentUser: true),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrentTripHeroCard(
              trip: soloTrip,
              isDark: false,
              totalSpent: 300.0,
              expenseCount: 1,
              onTapLedger: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.backpack_rounded), findsOneWidget);
    });

    testWidgets('triggers onTapLedger callback when financial summary is tapped', (WidgetTester tester) async {
      var ledgerTapped = false;
      final trip = createTestTrip();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrentTripHeroCard(
              trip: trip,
              isDark: false,
              totalSpent: 500.0,
              expenseCount: 2,
              onTapLedger: () {
                ledgerTapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('2 bills'));
      await tester.pumpAndSettle();

      expect(ledgerTapped, isTrue);
    });

    testWidgets('triggers onToggleTracking callback when telemetry button is tapped', (WidgetTester tester) async {
      var trackingToggled = false;
      final trip = createTestTrip();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrentTripHeroCard(
              trip: trip,
              isDark: false,
              totalSpent: 500.0,
              expenseCount: 2,
              onTapLedger: () {},
              onToggleTracking: () {
                trackingToggled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start Live Convoy Telemetry'));
      await tester.pumpAndSettle();

      expect(trackingToggled, isTrue);
    });

    testWidgets('triggers onTapCard callback when trip title header is tapped', (WidgetTester tester) async {
      var cardTapped = false;
      final trip = createTestTrip();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrentTripHeroCard(
              trip: trip,
              isDark: false,
              totalSpent: 500.0,
              expenseCount: 2,
              onTapLedger: () {},
              onTapCard: () {
                cardTapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Swiss Alps Expedition'));
      await tester.pumpAndSettle();

      expect(cardTapped, isTrue);
    });

    testWidgets('triggers onToggleTracking callback when live convoy button is tapped', (WidgetTester tester) async {
      var trackingToggled = false;
      final trip = createTestTrip();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrentTripHeroCard(
              trip: trip,
              isDark: false,
              totalSpent: 500.0,
              expenseCount: 2,
              onTapLedger: () {},
              onToggleTracking: () {
                trackingToggled = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Start Live Convoy Telemetry'), findsOneWidget);
      await tester.tap(find.text('Start Live Convoy Telemetry'));
      await tester.pumpAndSettle();

      expect(trackingToggled, isTrue);
    });
  });
}
