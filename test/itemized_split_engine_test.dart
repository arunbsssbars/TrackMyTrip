import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/models/itemized_split_breakdown.dart';
import 'package:trackmytrip/core/services/itemized_split_engine.dart';
import 'package:trackmytrip/screens/expenses/itemized_split_sheet.dart';

void main() {
  group('ItemizedSplitEngine Mathematical Reconciliation Tests', () {
    final engine = ItemizedSplitEngine();

    test('Splits 100 INR equally between 3 members with exact zero penny discrepancy', () {
      final breakdown = engine.splitEqual(
        totalAmount: 100.0,
        memberNames: ['Arun', 'Priya', 'Rahul'],
        currency: 'INR',
      );

      expect(breakdown.memberOwedAmounts.length, 3);
      expect(breakdown.memberOwedAmounts['Arun'], 33.34);
      expect(breakdown.memberOwedAmounts['Priya'], 33.33);
      expect(breakdown.memberOwedAmounts['Rahul'], 33.33);

      final totalSum = breakdown.calculatedSum;
      expect(totalSum, 100.00);
      expect(breakdown.isReconciled, true);
    });

    test('Splits by weighted shares accurately', () {
      // Arun (couple = 2 shares), Priya (single = 1 share), Rahul (single = 1 share) -> Total 4 shares
      final breakdown = engine.splitByShares(
        totalAmount: 4000.0,
        memberShares: {'Arun': 2.0, 'Priya': 1.0, 'Rahul': 1.0},
        currency: 'INR',
      );

      expect(breakdown.memberOwedAmounts['Arun'], 2000.0);
      expect(breakdown.memberOwedAmounts['Priya'], 1000.0);
      expect(breakdown.memberOwedAmounts['Rahul'], 1000.0);
      expect(breakdown.calculatedSum, 4000.0);
    });

    test('Splits by percentage with rounding reconciliation', () {
      final breakdown = engine.splitByPercentages(
        totalAmount: 550.0,
        memberPercentages: {'Arun': 45.0, 'Priya': 35.0, 'Rahul': 20.0},
      );

      expect(breakdown.memberOwedAmounts['Arun'], 247.50);
      expect(breakdown.memberOwedAmounts['Priya'], 192.50);
      expect(breakdown.memberOwedAmounts['Rahul'], 110.00);
      expect(breakdown.calculatedSum, 550.0);
      expect(breakdown.isReconciled, true);
    });

    test('Json serialization and deserialization retains accuracy', () {
      const original = ItemizedSplitBreakdown(
        totalAmount: 1500.0,
        splitMethod: 'shares',
        memberOwedAmounts: {'Arun': 750.0, 'Priya': 750.0},
      );

      final json = original.toJson();
      final restored = ItemizedSplitBreakdown.fromJson(json);

      expect(restored.totalAmount, 1500.0);
      expect(restored.splitMethod, 'shares');
      expect(restored.memberOwedAmounts['Arun'], 750.0);
      expect(restored.isReconciled, true);
    });
  });

  group('AQIL Multi-Viewport & Accessibility Tests for ItemizedSplitSheet', () {
    const totalAmount = 3750.0;
    final members = ['Arun', 'Priya', 'Vikram', 'Ananya'];

    final viewports = <String, Size>{
      'Compact Mobile (320px)': const Size(320, 568),
      'Standard Mobile (393px)': const Size(393, 852),
      'Large Mobile (412px)': const Size(412, 915),
      'Tablet Portrait (800px)': const Size(800, 1280),
      'Desktop Landscape (1280px)': const Size(1280, 800),
    };

    for (final entry in viewports.entries) {
      testWidgets('Renders zero overflow on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ItemizedSplitSheet(
                totalAmount: totalAmount,
                memberNames: members,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Expense Split Engine'), findsOneWidget);
        expect(find.byType(ItemizedSplitSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Renders with 1.5x font scale without overflow and switches to shares', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ItemizedSplitBreakdown? confirmed;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              textScaler: const TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: ItemizedSplitSheet(
                totalAmount: totalAmount,
                memberNames: members,
                onConfirmBreakdown: (b) => confirmed = b,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Expense Split Engine'), findsOneWidget);

      // Switch to Weighted Shares
      final sharesChip = find.text('Weighted Shares');
      await tester.ensureVisible(sharesChip);
      await tester.tap(sharesChip);
      await tester.pumpAndSettle();

      final confirmBtn = find.text('Confirm Split Breakdown');
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(confirmed, isNotNull);
      expect(confirmed!.splitMethod, 'shares');
      expect(tester.takeException(), isNull);
    });
  });
}
