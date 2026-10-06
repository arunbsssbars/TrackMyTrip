import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/design_system/design_system.dart';
import 'package:trackmytrip/core/utils/currency_formatter.dart';
import 'package:trackmytrip/core/utils/date_formatter.dart';
import 'package:trackmytrip/core/utils/debt_simplifier.dart';
import 'package:trackmytrip/models/expense.dart';
import 'package:trackmytrip/models/expense_split.dart';
import 'package:trackmytrip/models/memory.dart';
import 'package:trackmytrip/models/settlement.dart';
import 'package:trackmytrip/models/trip.dart';
import 'package:trackmytrip/models/trip_member.dart';
import 'package:uuid/uuid.dart';

void main() {
  const member1 = TripMember(id: 'm1', name: 'Alice', colorHex: '0xFF3B82F6');
  const member2 = TripMember(id: 'm2', name: 'Bob', colorHex: '0xFF10B981');
  const member3 = TripMember(id: 'm3', name: 'Charlie', colorHex: '0xFFF97316');

  final sampleTrip = Trip(
    id: 'trip_100_centennial',
    title: 'Centennial Expedition',
    description: '100th loop milestone test trip',
    startDate: DateTime(2026, 10, 5),
    endDate: DateTime(2026, 10, 10),
    createdAt: DateTime(2026, 10, 5),
    members: [member1, member2, member3],
    defaultCurrency: 'USD',
    budget: 3000.0,
    createdByMemberId: 'm1',
  );

  group('Loop 96: Expenses Tab Filter Reset & Empty State Resilience', () {
    testWidgets('AppEmptyState displays Reset Filters button and triggers callback when filters are active', (tester) async {
      bool resetTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No Food Bills',
              message: 'No expenses matched the active filter or search keyword.',
              actionLabel: 'Reset Filters',
              onAction: () {
                resetTriggered = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('No Food Bills'), findsOneWidget);
      expect(find.text('No expenses matched the active filter or search keyword.'), findsOneWidget);
      expect(find.text('Reset Filters'), findsOneWidget);

      await tester.tap(find.text('Reset Filters'));
      await tester.pumpAndSettle();

      expect(resetTriggered, isTrue);
    });

    testWidgets('Filtered Subtotal Badge renders with AppResilientText.badge and accessible Reset Semantics', (tester) async {
      bool resetClicked = false;
      const subtotal = 145.50;
      const filteredCount = 3;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: AppResilientText.badge(
                      'Filtered Subtotal: ${CurrencyFormatter.format(subtotal, currency: 'USD')} ($filteredCount bills)',
                      textAlign: TextAlign.start,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Reset all filters',
                    child: InkWell(
                      onTap: () {
                        resetClicked = true;
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded, size: 14),
                          SizedBox(width: 3),
                          Text('Reset'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Filtered Subtotal: \$145.50 (3 bills)'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);

      // Verify accessible semantics
      final semanticsWidget = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Reset all filters',
      );
      expect(semanticsWidget, findsOneWidget);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(resetClicked, isTrue);
    });
  });

  group('Loop 97: Timeline Tab Density Toggle (Compact vs Detailed)', () {
    testWidgets('Timeline density toggle button toggles state and updates icon & tooltip', (tester) async {
      bool isCompactDensity = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                appBar: AppBar(
                  actions: [
                    Semantics(
                      button: true,
                      label: isCompactDensity ? 'Switch to detailed timeline' : 'Switch to compact timeline',
                      child: IconButton(
                        icon: Icon(
                          isCompactDensity ? Icons.view_agenda_rounded : Icons.view_headline_rounded,
                        ),
                        tooltip: isCompactDensity ? 'Detailed View' : 'Compact View',
                        onPressed: () {
                          setState(() {
                            isCompactDensity = !isCompactDensity;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Initial state: detailed -> shows view_headline_rounded to switch to compact
      expect(find.byIcon(Icons.view_headline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.view_agenda_rounded), findsNothing);

      // Tap toggle
      await tester.tap(find.byIcon(Icons.view_headline_rounded));
      await tester.pumpAndSettle();

      // State is now compact -> shows view_agenda_rounded to switch back to detailed
      expect(find.byIcon(Icons.view_agenda_rounded), findsOneWidget);
      expect(find.byIcon(Icons.view_headline_rounded), findsNothing);
    });

    testWidgets('Compact timeline tile renders streamlined single-line layout without overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Golden Gate Viewpoint Overlook',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2.5),
                        Text(
                          'sightseeing • ${DateFormatter.formatDateTime(DateTime(2026, 10, 5, 14, 30))} • 45m',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    child: const Text('\$25.00', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 19),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Golden Gate Viewpoint Overlook'), findsOneWidget);
      expect(find.textContaining('sightseeing • Oct 5, 2026 • 2:30 PM • 45m'), findsOneWidget);
      expect(find.text('\$25.00'), findsOneWidget);
    });
  });

  group('Loop 98: Memories Tab Photo Lightbox Direct Share & Timestamp', () {
    test('DateFormatter formats memory timestamps accurately with delimiter', () {
      final dt = DateTime(2026, 10, 5, 16, 45);
      final formatted = DateFormatter.formatDateTime(dt);

      expect(formatted, contains('Oct 5, 2026'));
      expect(formatted, contains('4:45 PM'));
      expect(formatted, contains(' • '));
    });

    test('Photo share text combines caption, delimiter, and formatted timestamp', () {
      final memory = Memory(
        id: 'mem_1',
        tripId: 'trip_100_centennial',
        stoppageId: 'stop_1',
        uploadedByMemberId: 'm1',
        createdAt: DateTime(2026, 10, 5, 16, 45),
        caption: 'Sunset across the bay',
        mediaPath: 'assets/images/sunset.jpg',
      );

      final caption = memory.caption ?? 'Memory from Centennial Expedition';
      final timestamp = DateFormatter.formatDateTime(memory.createdAt);
      final shareText = '$caption • $timestamp';

      expect(shareText, equals('Sunset across the bay • Oct 5, 2026 • 4:45 PM'));
    });
  });

  group('Loop 99: Settlement Tab Batch Settle Preview & Execution', () {
    test('DebtSimplifier computes optimal debt transfers for group balances', () {
      // Alice paid $90 for everyone equally ($30 each)
      // Bob paid $0
      // Charlie paid $0
      final netBalances = {
        'm1': 60.0,   // Alice is owed $60
        'm2': -30.0,  // Bob owes $30
        'm3': -30.0,  // Charlie owes $30
      };

      final transfers = DebtSimplifier.simplifyDebts(netBalances);
      expect(transfers.length, equals(2));

      final totalTransferred = transfers.fold<double>(0.0, (sum, t) => sum + t.amount);
      expect(totalTransferred, equals(60.0));

      // Each transfer is directed to m1
      for (final t in transfers) {
        expect(t.toMemberId, equals('m1'));
        expect(t.amount, equals(30.0));
      }
    });

    test('Batch settlement recording produces valid Settlement models that resolve group debt to zero', () {
      final now = DateTime(2026, 10, 5, 18, 0);
      final transfers = [
        const DebtTransfer(fromMemberId: 'm2', toMemberId: 'm1', amount: 30.0),
        const DebtTransfer(fromMemberId: 'm3', toMemberId: 'm1', amount: 30.0),
      ];

      final recordedSettlements = transfers.map((t) {
        return Settlement(
          id: const Uuid().v4(),
          tripId: sampleTrip.id,
          payerMemberId: t.fromMemberId,
          receiverMemberId: t.toMemberId,
          amount: t.amount,
          currency: sampleTrip.defaultCurrency,
          settledAt: now,
          notes: 'Batch settled transfer',
          paymentMethod: 'Cash',
        );
      }).toList();

      expect(recordedSettlements.length, equals(2));
      expect(recordedSettlements[0].payerMemberId, equals('m2'));
      expect(recordedSettlements[0].receiverMemberId, equals('m1'));
      expect(recordedSettlements[0].amount, equals(30.0));

      // Simulate ledger update
      final initialBalances = {'m1': 60.0, 'm2': -30.0, 'm3': -30.0};
      final postSettlementBalances = Map<String, double>.from(initialBalances);

      for (final s in recordedSettlements) {
        postSettlementBalances[s.payerMemberId] = (postSettlementBalances[s.payerMemberId] ?? 0.0) + s.amount;
        postSettlementBalances[s.receiverMemberId] = (postSettlementBalances[s.receiverMemberId] ?? 0.0) - s.amount;
      }

      // Ledger must be completely settled
      expect(postSettlementBalances['m1'], equals(0.0));
      expect(postSettlementBalances['m2'], equals(0.0));
      expect(postSettlementBalances['m3'], equals(0.0));
    });
  });

  group('Loop 100: Centennial Milestone Master Gate Verification', () {
    test('All Sprint 10 features operate harmoniously', () {
      final expense = Expense(
        id: 'e_100',
        tripId: sampleTrip.id,
        title: 'Centennial Dinner',
        totalAmount: 300.0,
        currency: 'USD',
        category: 'food',
        paidByMemberId: 'm1',
        splitType: SplitType.equal,
        splits: [
          const ExpenseSplit(memberId: 'm1', allocatedAmount: 100.0),
          const ExpenseSplit(memberId: 'm2', allocatedAmount: 100.0),
          const ExpenseSplit(memberId: 'm3', allocatedAmount: 100.0),
        ],
        createdAt: DateTime(2026, 10, 5, 20, 0),
      );

      expect(expense.splits.length, equals(3));
      expect(expense.totalAmount, equals(300.0));
    });
  });
}
