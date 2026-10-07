import 'package:flutter/material.dart';
import '../../models/category_sub_budget.dart';

class CategoryBudgetService {
  static final CategoryBudgetService _instance = CategoryBudgetService._internal();
  factory CategoryBudgetService() => _instance;
  CategoryBudgetService._internal();

  /// Default categories with default distribution
  List<CategorySubBudget> createDefaultBudgets({
    required double totalBudget,
    String currencyCode = 'INR',
  }) {
    if (totalBudget <= 0) totalBudget = 10000.0;

    // Industry standard roadtrip ratio: Stay 35%, Food 25%, Fuel 20%, Activities 10%, Misc 10%
    return [
      CategorySubBudget(
        category: 'Stay & Hotels',
        allocatedAmount: totalBudget * 0.35,
        currencyCode: currencyCode,
      ),
      CategorySubBudget(
        category: 'Food & Dining',
        allocatedAmount: totalBudget * 0.25,
        currencyCode: currencyCode,
      ),
      CategorySubBudget(
        category: 'Fuel & Tolls',
        allocatedAmount: totalBudget * 0.20,
        currencyCode: currencyCode,
      ),
      CategorySubBudget(
        category: 'Activities & Tickets',
        allocatedAmount: totalBudget * 0.10,
        currencyCode: currencyCode,
      ),
      CategorySubBudget(
        category: 'Shopping & Misc',
        allocatedAmount: totalBudget * 0.10,
        currencyCode: currencyCode,
      ),
    ];
  }

  /// Calculates updated category sub-budgets given a list of expenses/bills
  List<CategorySubBudget> recalculateBudgets({
    required List<CategorySubBudget> currentBudgets,
    required List<Map<String, dynamic>> rawExpenses,
  }) {
    final Map<String, double> spendMap = {};
    for (final exp in rawExpenses) {
      final cat = (exp['category'] as String?)?.trim().toLowerCase() ?? 'shopping & misc';
      final amount = (exp['amount'] as num?)?.toDouble() ?? 0.0;

      // Find best match or bucket
      final matchedKey = currentBudgets.firstWhere(
        (b) => b.category.toLowerCase().contains(cat) || cat.contains(b.category.toLowerCase().split(' ').first),
        orElse: () => currentBudgets.last,
      ).category;

      spendMap[matchedKey] = (spendMap[matchedKey] ?? 0.0) + amount;
    }

    return currentBudgets.map((b) {
      final spent = spendMap[b.category] ?? 0.0;
      return b.copyWith(spentAmount: spent);
    }).toList();
  }

  /// Checks if any category has exceeded or is nearing its limit
  List<String> getActiveBudgetAlerts(List<CategorySubBudget> budgets) {
    final List<String> alerts = [];
    for (final b in budgets) {
      if (b.isExceeded) {
        final diff = (b.spentAmount - b.allocatedAmount).toStringAsFixed(0);
        alerts.add('Over budget in ${b.category} by ${b.currencyCode} $diff!');
      } else if (b.isNearLimit) {
        alerts.add('${b.category} reached ${(b.utilizationRatio * 100).toStringAsFixed(0)}% of limit.');
      }
    }
    return alerts;
  }

  static IconData getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('stay') || lower.contains('hotel')) return Icons.hotel_rounded;
    if (lower.contains('food') || lower.contains('dining')) return Icons.restaurant_rounded;
    if (lower.contains('fuel') || lower.contains('toll')) return Icons.local_gas_station_rounded;
    if (lower.contains('activit') || lower.contains('ticket')) return Icons.attractions_rounded;
    if (lower.contains('shop')) return Icons.shopping_bag_rounded;
    return Icons.category_rounded;
  }
}
