import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/trip.dart';
import '../../providers/expense_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';
import '../common/universal_bottom_bar.dart';

class TripAnalyticsScreen extends ConsumerWidget {
  final String? tripId;

  const TripAnalyticsScreen({super.key, this.tripId});

  bool get isGlobal => tripId == null || tripId!.isEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTrips = ref.watch(tripListProvider);
    final allStoppages = ref.watch(allStoppagesProvider);
    final allExpenses = ref.watch(allExpensesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categoryColors = [
      AppTheme.primary,
      const Color(0xFF0891B2),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF3B82F6),
      const Color(0xFF64748B),
    ];

    if (isGlobal) {
      return _buildGlobalAnalytics(
        context,
        allTrips,
        allStoppages,
        allExpenses,
        categoryColors,
        isDark,
      );
    } else {
      final trip = allTrips.firstWhere(
        (t) => t.id == tripId,
        orElse: () => ref.watch(currentTripProvider) ?? (allTrips.isNotEmpty ? allTrips.first : _fallbackTrip()),
      );
      final tripStoppages = allStoppages.where((s) => s.tripId == trip.id).toList();
      final tripExpenses = allExpenses.where((e) => e.tripId == trip.id).toList();

      return _buildTripAnalytics(
        context,
        trip,
        tripStoppages,
        tripExpenses,
        categoryColors,
        isDark,
      );
    }
  }

  Trip _fallbackTrip() {
    return Trip(
      id: 'default',
      title: 'Current Journey',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 1)),
      createdByMemberId: 'default',
      defaultCurrency: 'INR',
      members: const [],
      createdAt: DateTime.now(),
    );
  }

  Widget _buildGlobalAnalytics(
    BuildContext context,
    List<Trip> trips,
    List<dynamic> stoppages,
    List<dynamic> expenses,
    List<Color> categoryColors,
    bool isDark,
  ) {
    final totalSpent = expenses.fold<double>(0.0, (sum, e) => sum + (e.totalAmount as num).toDouble());

    // Aggregate category totals
    final Map<String, double> categoryTotals = {};
    for (final exp in expenses) {
      final cat = exp.category.toString().split('.').last;
      final label = AppConstants.expenseCategories.contains(cat)
          ? '${cat[0].toUpperCase()}${cat.substring(1)}'
          : 'General';
      categoryTotals[label] = (categoryTotals[label] ?? 0.0) + (exp.totalAmount as num).toDouble();
    }
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Aggregate spending per trip
    final Map<String, double> tripSpendMap = {};
    for (final exp in expenses) {
      final tId = exp.tripId as String;
      tripSpendMap[tId] = (tripSpendMap[tId] ?? 0.0) + (exp.totalAmount as num).toDouble();
    }
    final rankedTrips = trips.toList()
      ..sort((a, b) => (tripSpendMap[b.id] ?? 0.0).compareTo(tripSpendMap[a.id] ?? 0.0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Travel Analytics'),
        elevation: 0,
      ),
      body: expenses.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, size: 56, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No Expense Data Available',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Record expenses across your journeys to view global financial analytics, category distributions, and expedition insights.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // Top Global Total Summary Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D9488).withAlpha(90),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.public_rounded, color: Colors.white70, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'ALL EXPEDITIONS COMBINED',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        CurrencyFormatter.format(totalSpent),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniStat('Journeys', '${trips.length}', Colors.white),
                          Container(width: 1, height: 26, color: Colors.white24),
                          _buildMiniStat('Stoppages', '${stoppages.length}', Colors.white),
                          Container(width: 1, height: 26, color: Colors.white24),
                          _buildMiniStat('Bills Logged', '${expenses.length}', Colors.white),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Global Category Spending Pie Chart
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.pie_chart_rounded, size: 18, color: AppTheme.primary),
                            SizedBox(width: 8),
                            Text(
                              'Global Spending by Category',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 220,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 36,
                              sections: sortedCategories.map((entry) {
                                final index = sortedCategories.indexOf(entry);
                                final color = categoryColors[index % categoryColors.length];
                                final percentage = totalSpent > 0 ? (entry.value / totalSpent) * 100 : 0.0;
                                return PieChartSectionData(
                                  color: color,
                                  value: entry.value,
                                  title: percentage >= 5 ? '${percentage.toStringAsFixed(0)}%' : '',
                                  radius: 52,
                                  titleStyle: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    shadows: [Shadow(color: Colors.black45, blurRadius: 3)],
                                  ),
                                  badgeWidget: percentage >= 8
                                      ? Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 1.5),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Colors.black38,
                                                blurRadius: 4,
                                                offset: Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            _getCategoryIcon(entry.key),
                                            size: 13,
                                            color: Colors.white,
                                          ),
                                        )
                                      : null,
                                  badgePositionPercentageOffset: 1.05,
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        ...sortedCategories.map((entry) {
                          final index = sortedCategories.indexOf(entry);
                          final color = categoryColors[index % categoryColors.length];
                          final percentage = totalSpent > 0 ? (entry.value / totalSpent) * 100 : 0.0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(entry.value),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${percentage.toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
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

                // Spending by Journey Ranking
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.leaderboard_rounded, size: 18, color: AppTheme.primary),
                            SizedBox(width: 8),
                            Text(
                              'Spending by Journey',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ...rankedTrips.map((t) {
                          final tripSpent = tripSpendMap[t.id] ?? 0.0;
                          final pct = totalSpent > 0 ? (tripSpent / totalSpent) : 0.0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(
                                            t.isSolo
                                                ? Icons.person_rounded
                                                : (t.isFamily ? Icons.family_restroom_rounded : Icons.groups_rounded),
                                            size: 15,
                                            color: AppTheme.primary,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              t.title,
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      CurrencyFormatter.format(tripSpent, currency: t.defaultCurrency),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormatter.formatTripDateRange(t.startDate, t.endDate),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                      ),
                                    ),
                                    Text(
                                      '${(pct * 100).toStringAsFixed(1)}% of total',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                      ),
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
                const SizedBox(height: 30),
              ],
            ),
      bottomNavigationBar: const UniversalBottomBar(),
    );
  }

  Widget _buildTripAnalytics(
    BuildContext context,
    Trip trip,
    List<dynamic> stoppages,
    List<dynamic> expenses,
    List<Color> categoryColors,
    bool isDark,
  ) {
    final totalSpent = expenses.fold<double>(0.0, (sum, e) => sum + (e.totalAmount as num).toDouble());

    // Aggregate category totals for this trip
    final Map<String, double> categoryTotals = {};
    for (final exp in expenses) {
      final cat = exp.category.toString().split('.').last;
      final label = AppConstants.expenseCategories.contains(cat)
          ? '${cat[0].toUpperCase()}${cat.substring(1)}'
          : 'General';
      categoryTotals[label] = (categoryTotals[label] ?? 0.0) + (exp.totalAmount as num).toDouble();
    }
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: Text('${trip.title} Analytics'),
        elevation: 0,
      ),
      body: expenses.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_rounded, size: 56, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No Bills Logged for this Journey',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Add expenses and split bills with companions to generate spending breakdowns, charts, and payer contribution metrics.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // Top Trip Total Summary Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D9488).withAlpha(90),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Total Journey Spending • ${trip.title}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        CurrencyFormatter.format(totalSpent, currency: trip.defaultCurrency),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniStat('Stoppages', '${stoppages.length}', Colors.white),
                          Container(width: 1, height: 26, color: Colors.white24),
                          _buildMiniStat('Bills Logged', '${expenses.length}', Colors.white),
                          Container(width: 1, height: 26, color: Colors.white24),
                          _buildMiniStat(
                            'Avg / Person',
                            CurrencyFormatter.format(
                              trip.members.isNotEmpty ? totalSpent / trip.members.length : totalSpent,
                              currency: trip.defaultCurrency,
                            ),
                            Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Category Spending Pie Chart
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.pie_chart_rounded, size: 18, color: AppTheme.primary),
                            SizedBox(width: 8),
                            Text(
                              'Spending by Category',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 220,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 36,
                              sections: sortedCategories.map((entry) {
                                final index = sortedCategories.indexOf(entry);
                                final color = categoryColors[index % categoryColors.length];
                                final percentage = totalSpent > 0 ? (entry.value / totalSpent) * 100 : 0.0;
                                return PieChartSectionData(
                                  color: color,
                                  value: entry.value,
                                  title: percentage >= 5 ? '${percentage.toStringAsFixed(0)}%' : '',
                                  radius: 52,
                                  titleStyle: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    shadows: [Shadow(color: Colors.black45, blurRadius: 3)],
                                  ),
                                  badgeWidget: percentage >= 8
                                      ? Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 1.5),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Colors.black38,
                                                blurRadius: 4,
                                                offset: Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            _getCategoryIcon(entry.key),
                                            size: 13,
                                            color: Colors.white,
                                          ),
                                        )
                                      : null,
                                  badgePositionPercentageOffset: 1.05,
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        ...sortedCategories.map((entry) {
                          final index = sortedCategories.indexOf(entry);
                          final color = categoryColors[index % categoryColors.length];
                          final percentage = totalSpent > 0 ? (entry.value / totalSpent) * 100 : 0.0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(entry.value, currency: trip.defaultCurrency),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${percentage.toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
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

                // Top Spending Stoppages
                if (stoppages.isNotEmpty) ...[
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.place_rounded, size: 18, color: AppTheme.primary),
                              SizedBox(width: 8),
                              Text(
                                'Spending by Stoppage',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ...stoppages.map((s) {
                            final stopExpenses = expenses.where((e) => e.stoppageId == s.id).toList();
                            final stopTotal = stopExpenses.fold<double>(0, (sum, e) => sum + (e.totalAmount as num).toDouble());
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
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        CurrencyFormatter.format(stopTotal, currency: trip.defaultCurrency),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                ],

                // Member Contribution (Who Paid What)
                if (trip.members.isNotEmpty) ...[
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.groups_rounded, size: 18, color: AppTheme.primary),
                              SizedBox(width: 8),
                              Text(
                                'Payer Contributions',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ...trip.members.map((member) {
                            final paidTotal = expenses
                                .where((e) => e.paidByMemberId == member.id)
                                .fold<double>(0, (sum, e) => sum + (e.totalAmount as num).toDouble());
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
                                              member.name.isNotEmpty ? member.name.substring(0, 1) : '?',
                                              style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        ],
                                      ),
                                      Text(
                                        CurrencyFormatter.format(paidTotal, currency: trip.defaultCurrency),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                ],
                const SizedBox(height: 30),
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

  IconData _getCategoryIcon(String category) {
    return AppConstants.getExpenseIcon(category);
  }
}
