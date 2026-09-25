import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/expense_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';
import '../common/universal_bottom_bar.dart';

class TripAnalyticsScreen extends ConsumerWidget {
  final String tripId;

  const TripAnalyticsScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripListProvider);
    final trip = trips.firstWhere(
      (t) => t.id == tripId,
      orElse: () => ref.watch(currentTripProvider) ?? trips.first,
    );
    final stoppages = ref.watch(currentTripStoppagesProvider);
    final expenses = ref.watch(currentTripExpensesProvider);
    final categoryTotals = ref.watch(expensesByCategoryProvider);
    final totalSpent = ref.watch(currentTripTotalSpentProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categoryColors = [
      AppTheme.primary,
      AppTheme.secondary,
      AppTheme.accent,
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
      const Color(0xFF6B7280),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Analytics & Spending'),
      ),
      body: expenses.isEmpty
          ? const Center(child: Text('No expense data available for analytics yet.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Top Big Total
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Total Trip Spending',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        CurrencyFormatter.format(totalSpent, currency: trip.defaultCurrency),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniStat('Stoppages', '${stoppages.length}', Colors.white),
                          Container(width: 1, height: 28, color: Colors.white24),
                          _buildMiniStat('Bills Logged', '${expenses.length}', Colors.white),
                          Container(width: 1, height: 28, color: Colors.white24),
                          _buildMiniStat(
                            'Avg / Person',
                            CurrencyFormatter.format(
                              trip.members.isNotEmpty ? totalSpent / trip.members.length : 0,
                              currency: trip.defaultCurrency,
                            ),
                            Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Category Spending Pie Chart
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Spending by Category',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 40,
                              sections: categoryTotals.entries.map((entry) {
                                final index = categoryTotals.keys.toList().indexOf(entry.key);
                                final color = categoryColors[index % categoryColors.length];
                                final percentage = (entry.value / totalSpent) * 100;
                                return PieChartSectionData(
                                  color: color,
                                  value: entry.value,
                                  title: '${percentage.toStringAsFixed(0)}%',
                                  radius: 50,
                                  titleStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...categoryTotals.entries.map((entry) {
                          final index = categoryTotals.keys.toList().indexOf(entry.key);
                          final color = categoryColors[index % categoryColors.length];
                          final percentage = (entry.value / totalSpent) * 100;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500))),
                                Text(
                                  CurrencyFormatter.format(entry.value, currency: trip.defaultCurrency),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${percentage.toStringAsFixed(1)}%)',
                                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 11),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Top Spending Stoppages
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Spending by Stoppage',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 14),
                        ...stoppages.map((s) {
                          final stopExpenses = expenses.where((e) => e.stoppageId == s.id).toList();
                          final stopTotal = stopExpenses.fold<double>(0, (sum, e) => sum + e.totalAmount);
                          final pct = totalSpent > 0 ? (stopTotal / totalSpent) : 0.0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(AppConstants.getStoppageIcon(s.category), size: 16, color: AppTheme.primary),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              s.name,
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      CurrencyFormatter.format(stopTotal, currency: trip.defaultCurrency),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 6,
                                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Member Contribution (Who Paid What)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payer Contributions',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 14),
                        ...trip.members.map((member) {
                          final paidTotal = expenses
                              .where((e) => e.paidByMemberId == member.id)
                              .fold<double>(0, (sum, e) => sum + e.totalAmount);
                          final pct = totalSpent > 0 ? (paidTotal / totalSpent) : 0.0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 10,
                                          backgroundColor: member.colorHex != null
                                              ? Color(int.parse(member.colorHex!))
                                              : AppTheme.primary,
                                          child: Text(
                                            member.name.substring(0, 1),
                                            style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    Text(
                                      CurrencyFormatter.format(paidTotal, currency: trip.defaultCurrency),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 6,
                                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.secondary),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
      bottomNavigationBar: const UniversalBottomBar(),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: color.withAlpha(180), fontSize: 10)),
      ],
    );
  }
}
