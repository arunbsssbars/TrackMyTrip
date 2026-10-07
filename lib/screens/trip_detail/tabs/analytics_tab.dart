import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/trip.dart';
import '../../../providers/expense_provider.dart';
import '../../../providers/stoppage_provider.dart';

/// Responsive, AQIL-verified embedded Analytics subtab for a specific Trip.
/// Provides financial breakdowns, category spend distribution, top spenders,
/// and travel velocity without layout overflows across viewports (320px–1280px).
class AnalyticsTab extends ConsumerWidget {
  final Trip trip;

  const AnalyticsTab({super.key, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allExpenses = ref.watch(allExpensesProvider);
    final tripExpenses = allExpenses.where((e) => e.tripId == trip.id).toList();
    final allStoppages = ref.watch(allStoppagesProvider);
    final tripStoppages = allStoppages.where((s) => s.tripId == trip.id).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalSpent = tripExpenses.fold<double>(0.0, (sum, e) => sum + e.totalAmount);
    final budget = trip.budget ?? 0.0;
    final hasBudget = budget > 0.0;
    final budgetPercent = hasBudget ? (totalSpent / budget).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = hasBudget && totalSpent > budget;

    // Category breakdown
    final Map<String, double> categorySpend = {};
    for (final exp in tripExpenses) {
      categorySpend[exp.category] = (categorySpend[exp.category] ?? 0.0) + exp.totalAmount;
    }
    final sortedCategories = categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Spender breakdown
    final Map<String, double> spenderSpend = {};
    for (final exp in tripExpenses) {
      final payerName = trip.getMemberName(exp.paidByMemberId);
      final displayName = payerName.isNotEmpty && payerName != 'Unknown Member'
          ? payerName
          : exp.paidByMemberId;
      spenderSpend[displayName] = (spenderSpend[displayName] ?? 0.0) + exp.totalAmount;
    }
    final sortedSpenders = spenderSpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPadding = screenWidth < 360
        ? 12.0
        : (screenWidth >= 800 ? ((screenWidth - 760) / 2).clamp(16.0, 380.0) : 16.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: EdgeInsets.fromLTRB(hPadding, 12, hPadding, 90),
          children: [
            // 1. Overview Card (Total Spent vs Budget)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 30 : 10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withAlpha(25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.analytics_rounded, size: 18, color: AppTheme.primary),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Financial Overview',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isOverBudget
                              ? Colors.red.withAlpha(25)
                              : const Color(0xFF10B981).withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isOverBudget
                              ? 'Over Budget'
                              : (hasBudget ? '${(budgetPercent * 100).toInt()}% Used' : 'No Cap'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isOverBudget ? Colors.redAccent : const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Text(
                        CurrencyFormatter.format(totalSpent, currency: trip.defaultCurrency),
                        style: TextStyle(
                          fontSize: screenWidth < 360 ? 20 : 26,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'total spent',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  if (hasBudget) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: budgetPercent,
                        minHeight: 8,
                        backgroundColor: isDark ? Colors.grey[800] : const Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isOverBudget ? Colors.redAccent : AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      runAlignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Budget: ${CurrencyFormatter.format(budget, currency: trip.defaultCurrency)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          isOverBudget
                              ? 'Exceeded by ${CurrencyFormatter.format(totalSpent - budget, currency: trip.defaultCurrency)}'
                              : 'Remaining: ${CurrencyFormatter.format(budget - totalSpent, currency: trip.defaultCurrency)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isOverBudget ? Colors.redAccent : const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickStat(
                          label: 'Bills Count',
                          value: '${tripExpenses.length}',
                          icon: Icons.receipt_long_rounded,
                          isDark: isDark,
                        ),
                      ),
                      Expanded(
                        child: _buildQuickStat(
                          label: 'Companions',
                          value: '${trip.members.length}',
                          icon: Icons.people_outline_rounded,
                          isDark: isDark,
                        ),
                      ),
                      Expanded(
                        child: _buildQuickStat(
                          label: 'Waypoints',
                          value: '${tripStoppages.length}',
                          icon: Icons.pin_drop_outlined,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Spending by Category
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.pie_chart_rounded, size: 18, color: Color(0xFF6366F1)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Spending by Category',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (sortedCategories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No expenses logged yet.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    )
                  else
                    ...sortedCategories.map((entry) {
                      final ratio = totalSpent > 0 ? (entry.value / totalSpent) : 0.0;
                      final percent = (ratio * 100).toStringAsFixed(1);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getCategoryIcon(entry.key),
                                  size: 16,
                                  color: _getCategoryColor(entry.key),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '${CurrencyFormatter.format(entry.value, currency: trip.defaultCurrency)} ($percent%)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                      color: isDark ? Colors.grey[200] : const Color(0xFF1E293B),
                                    ),
                                    textAlign: TextAlign.end,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 6,
                                backgroundColor: isDark ? Colors.grey[800] : const Color(0xFFF1F5F9),
                                valueColor: AlwaysStoppedAnimation<Color>(_getCategoryColor(entry.key)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. Spenders Breakdown
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.payments_rounded, size: 18, color: Color(0xFFF59E0B)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Spending by Member',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (sortedSpenders.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No bills logged yet.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    )
                  else
                    ...sortedSpenders.map((entry) {
                      final ratio = totalSpent > 0 ? (entry.value / totalSpent) : 0.0;
                      final percent = (ratio * 100).toStringAsFixed(1);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppTheme.primary.withAlpha(35),
                              child: Text(
                                entry.key.isNotEmpty ? entry.key[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.key,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$percent% of total expenditure',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                CurrencyFormatter.format(entry.value, currency: trip.defaultCurrency),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickStat({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('food') || cat.contains('meal') || cat.contains('dinner')) return Icons.restaurant_rounded;
    if (cat.contains('fuel') || cat.contains('gas')) return Icons.local_gas_station_rounded;
    if (cat.contains('stay') || cat.contains('hotel')) return Icons.hotel_rounded;
    if (cat.contains('travel') || cat.contains('flight') || cat.contains('taxi')) return Icons.directions_car_rounded;
    if (cat.contains('shopping')) return Icons.shopping_bag_rounded;
    if (cat.contains('ticket') || cat.contains('activity')) return Icons.confirmation_number_rounded;
    return Icons.receipt_rounded;
  }

  Color _getCategoryColor(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('food')) return const Color(0xFFF59E0B);
    if (cat.contains('fuel')) return const Color(0xFFEF4444);
    if (cat.contains('stay')) return const Color(0xFF3B82F6);
    if (cat.contains('travel')) return const Color(0xFF10B981);
    if (cat.contains('shopping')) return const Color(0xFF8B5CF6);
    return const Color(0xFF0D9488);
  }
}
