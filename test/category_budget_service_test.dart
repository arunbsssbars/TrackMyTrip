import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/models/category_sub_budget.dart';
import 'package:trackmytrip/core/services/category_budget_service.dart';
import 'package:trackmytrip/screens/expenses/budget_progress_radar_card.dart';

void main() {
  group('CategoryBudgetService Logic Tests', () {
    final service = CategoryBudgetService();

    test('Creates default budget distribution for roadtrip', () {
      final budgets = service.createDefaultBudgets(totalBudget: 20000.0, currencyCode: 'INR');
      expect(budgets.length, 5);

      final stay = budgets.firstWhere((b) => b.category.contains('Stay'));
      expect(stay.allocatedAmount, 7000.0); // 35%
      expect(stay.spentAmount, 0.0);

      final totalAllocated = budgets.fold<double>(0.0, (acc, b) => acc + b.allocatedAmount);
      expect(totalAllocated, 20000.0);
    });

    test('Recalculates budgets based on expenses and triggers warnings', () {
      final initial = service.createDefaultBudgets(totalBudget: 10000.0, currencyCode: 'INR');
      // Fuel is 20% = 2000 allocated
      final expenses = [
        {'category': 'fuel', 'amount': 1700.0}, // 85% utilization -> warning
        {'category': 'food', 'amount': 3000.0}, // Food is 2500 -> exceeded!
      ];

      final updated = service.recalculateBudgets(
        currentBudgets: initial,
        rawExpenses: expenses,
      );

      final fuel = updated.firstWhere((b) => b.category.contains('Fuel'));
      expect(fuel.spentAmount, 1700.0);
      expect(fuel.isNearLimit, true);
      expect(fuel.isExceeded, false);

      final food = updated.firstWhere((b) => b.category.contains('Food'));
      expect(food.spentAmount, 3000.0);
      expect(food.isExceeded, true);

      final alerts = service.getActiveBudgetAlerts(updated);
      expect(alerts.length, 2);
      expect(alerts.any((a) => a.contains('Over budget in Food & Dining')), true);
      expect(alerts.any((a) => a.contains('Fuel & Tolls reached 85%')), true);
    });

    test('Json serialization and deserialization retains accuracy', () {
      const budget = CategorySubBudget(
        category: 'Camping Gear',
        allocatedAmount: 4500.0,
        spentAmount: 2250.0,
        currencyCode: 'USD',
      );

      final json = budget.toJson();
      final restored = CategorySubBudget.fromJson(json);

      expect(restored.category, 'Camping Gear');
      expect(restored.allocatedAmount, 4500.0);
      expect(restored.spentAmount, 2250.0);
      expect(restored.utilizationPercent, 50.0);
      expect(restored.currencyCode, 'USD');
    });
  });

  group('AQIL Multi-Viewport & Accessibility Tests for BudgetProgressRadarCard', () {
    final service = CategoryBudgetService();
    final sampleBudgets = service.recalculateBudgets(
      currentBudgets: service.createDefaultBudgets(totalBudget: 25000.0),
      rawExpenses: [
        {'category': 'stay', 'amount': 6000.0},
        {'category': 'food', 'amount': 7000.0}, // over budget
        {'category': 'fuel', 'amount': 4200.0}, // near limit
      ],
    );

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
              body: SingleChildScrollView(
                child: BudgetProgressRadarCard(
                  budgets: sampleBudgets,
                  onAdjustBudgets: () {},
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Category Sub-Budgets'), findsOneWidget);
        expect(find.byType(BudgetProgressRadarCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Renders with 1.5x font scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: BudgetProgressRadarCard(
                  budgets: sampleBudgets,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Category Sub-Budgets'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
