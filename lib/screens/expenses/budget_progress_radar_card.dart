import 'package:flutter/material.dart';
import '../../models/category_sub_budget.dart';
import '../../core/services/category_budget_service.dart';

class BudgetProgressRadarCard extends StatelessWidget {
  final List<CategorySubBudget> budgets;
  final VoidCallback? onAdjustBudgets;

  const BudgetProgressRadarCard({
    super.key,
    required this.budgets,
    this.onAdjustBudgets,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alerts = CategoryBudgetService().getActiveBudgetAlerts(budgets);

    final totalAllocated = budgets.fold<double>(0.0, (acc, b) => acc + b.allocatedAmount);
    final totalSpent = budgets.fold<double>(0.0, (acc, b) => acc + b.spentAmount);
    final totalRatio = totalAllocated > 0 ? (totalSpent / totalAllocated).clamp(0.0, 1.0) : 0.0;
    final currency = budgets.isNotEmpty ? budgets.first.currencyCode : 'INR';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Row
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(Icons.pie_chart_rounded, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Category Sub-Budgets',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Spent $currency ${totalSpent.toStringAsFixed(0)} of $currency ${totalAllocated.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (onAdjustBudgets != null)
                  TextButton(
                    onPressed: onAdjustBudgets,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(44, 44),
                    ),
                    child: const Text('Adjust'),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Overall Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: totalRatio,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  totalSpent > totalAllocated ? Colors.red : theme.colorScheme.primary,
                ),
              ),
            ),

            // Active Warnings / Overspend alerts
            if (alerts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        alerts.first,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Category list
            ...budgets.map((b) => _buildCategoryRow(context, b)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow(BuildContext context, CategorySubBudget b) {
    final theme = Theme.of(context);
    final icon = CategoryBudgetService.getCategoryIcon(b.category);
    final ratio = (b.allocatedAmount > 0 ? (b.spentAmount / b.allocatedAmount) : 0.0).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: b.statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  b.category,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${b.spentAmount.toStringAsFixed(0)} / ${b.allocatedAmount.toStringAsFixed(0)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: b.statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(b.statusColor),
            ),
          ),
        ],
      ),
    );
  }
}
