import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    testWidgets('renders basic trip details, travelers count, and share code', (WidgetTester tester) async {
      final trip = createTestTrip();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrentTripHeroCard(
              trip: trip,
              isDark: false,
              totalSpent: 1200.0,
              expenseCount: 4,
              onTapLedger: () {},
            ),
          ),
        ),
      );

      // Verify title & journey type pill
      expect(find.text('Swiss Alps Expedition'), findsOneWidget);
      expect(find.text('GROUP'), findsOneWidget);
      expect(find.text('2 Travelers'), findsOneWidget);
      expect(find.text('ALPINE-99'), findsOneWidget);
      expect(find.text('JOURNEY EXPENDITURE'), findsOneWidget);
      expect(find.text('\$1,200.00'), findsOneWidget);
    });

    testWidgets('displays budget progress bar and remaining budget when under budget', (WidgetTester tester) async {
      final trip = createTestTrip(budget: 2000.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrentTripHeroCard(
              trip: trip,
              isDark: false,
              totalSpent: 1200.0,
              expenseCount: 3,
              onTapLedger: () {},
            ),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('60% of \$2,000.00'), findsOneWidget);
      expect(find.text('Left: \$800.00'), findsOneWidget);
    });

    testWidgets('displays Over Budget warning when totalSpent exceeds budget', (WidgetTester tester) async {
      final trip = createTestTrip(budget: 1000.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrentTripHeroCard(
              trip: trip,
              isDark: true,
              totalSpent: 1350.0,
              expenseCount: 6,
              onTapLedger: () {},
            ),
          ),
        ),
      );

      expect(find.text('Over Budget!'), findsOneWidget);
      expect(find.text('100% of \$1,000.00'), findsOneWidget);
    });

    testWidgets('renders fallback expense entry count when trip has no budget', (WidgetTester tester) async {
      final tripWithoutBudget = createTestTrip(budget: null);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrentTripHeroCard(
              trip: tripWithoutBudget,
              isDark: false,
              totalSpent: 450.0,
              expenseCount: 3,
              onTapLedger: () {},
            ),
          ),
        ),
      );

      // Should not show LinearProgressIndicator
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('3 entries logged • Tap to view ledger & analytics'), findsOneWidget);
    });

    testWidgets('correctly pluralizes single expense entry', (WidgetTester tester) async {
      final tripWithoutBudget = createTestTrip(budget: null);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrentTripHeroCard(
              trip: tripWithoutBudget,
              isDark: false,
              totalSpent: 85.0,
              expenseCount: 1,
              onTapLedger: () {},
            ),
          ),
        ),
      );

      expect(find.text('1 entry logged • Tap to view ledger & analytics'), findsOneWidget);
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

    testWidgets('displays SOLO JOURNEY badge when trip is solo', (WidgetTester tester) async {
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

      expect(find.text('SOLO'), findsOneWidget);
    });

    testWidgets('triggers onTapLedger callback when ledger block is tapped', (WidgetTester tester) async {
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

      // Tap on the financial glance expenditure block
      await tester.tap(find.text('JOURNEY EXPENDITURE'));
      await tester.pumpAndSettle();

      expect(ledgerTapped, isTrue);
    });
  });
}
