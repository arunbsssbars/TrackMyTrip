import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/design_system/design_system.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/expense.dart';
import '../../models/trip.dart';
import '../../providers/expense_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';
import '../../core/services/trip_share_service.dart';
import '../common/universal_bottom_bar.dart';

class TripAnalyticsScreen extends ConsumerStatefulWidget {
  final String? tripId;
  final int initialTabIndex;
  final bool isEmbedded;

  const TripAnalyticsScreen({
    super.key,
    this.tripId,
    this.initialTabIndex = 0,
    this.isEmbedded = false,
  });

  bool get isGlobal => tripId == null || tripId!.isEmpty;

  @override
  ConsumerState<TripAnalyticsScreen> createState() => _TripAnalyticsScreenState();
}

class _TripAnalyticsScreenState extends ConsumerState<TripAnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _previewCurrency = 'INR';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allTrips = ref.watch(tripListProvider);
    final allStoppages = ref.watch(allStoppagesProvider);
    final allExpenses = ref.watch(allExpensesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isGlobal) {
      return _buildGlobalScreen(
        context,
        allTrips,
        allStoppages,
        allExpenses,
        isDark,
      );
    } else {
      final trip = allTrips.firstWhere(
        (t) => t.id == widget.tripId,
        orElse: () => ref.watch(currentTripProvider) ?? (allTrips.isNotEmpty ? allTrips.first : _fallbackTrip()),
      );
      final tripStoppages = allStoppages.where((s) => s.tripId == trip.id).toList();
      final tripExpenses = allExpenses.where((e) => e.tripId == trip.id).toList();

      return _buildTripScopedScreen(
        context,
        trip,
        tripStoppages,
        tripExpenses,
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

  // ==========================================
  // GLOBAL VIEW (Dashboard Top Card)
  // ==========================================
  Widget _buildGlobalScreen(
    BuildContext context,
    List<Trip> trips,
    List<dynamic> stoppages,
    List<Expense> expenses,
    bool isDark,
  ) {
    final totalSpent = expenses.fold<double>(0.0, (sum, e) => sum + e.totalAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Travel & Expenses'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelColor: isDark ? Colors.tealAccent : AppTheme.primary,
          unselectedLabelColor: isDark ? Colors.grey[400] : const Color(0xFF64748B),
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: const [
            Tab(
              icon: Icon(Icons.pie_chart_rounded, size: 18),
              text: 'Visual Analytics',
            ),
            Tab(
              icon: Icon(Icons.receipt_long_rounded, size: 18),
              text: 'Trip-wise Ledger',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGlobalVisualAnalyticsTab(context, trips, stoppages, expenses, totalSpent, isDark),
          _buildGlobalTripwiseLedgerTab(context, trips, expenses, isDark),
        ],
      ),
      bottomNavigationBar: const UniversalBottomBar(),
    );
  }

  Widget _buildGlobalVisualAnalyticsTab(
    BuildContext context,
    List<Trip> trips,
    List<dynamic> stoppages,
    List<Expense> expenses,
    double totalSpent,
    bool isDark,
  ) {
    if (expenses.isEmpty) {
      return _buildNoDataPlaceholder(
        icon: Icons.pie_chart_outline_rounded,
        title: 'No Expense Data Available',
        subtitle: 'Record expenses across your journeys to view global financial analytics, category distributions, and insights.',
      );
    }

    // Category aggregation using robust normalizer (Point 21 fix)
    final Map<String, double> categoryTotals = {};
    for (final exp in expenses) {
      final label = AppConstants.normalizeExpenseCategory(exp.category);
      categoryTotals[label] = (categoryTotals[label] ?? 0.0) + exp.totalAmount;
    }
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Spending per trip ranking
    final Map<String, double> tripSpendMap = {};
    for (final exp in expenses) {
      final tId = exp.tripId;
      tripSpendMap[tId] = (tripSpendMap[tId] ?? 0.0) + exp.totalAmount;
    }
    final rankedTrips = trips.toList()
      ..sort((a, b) => (tripSpendMap[b.id] ?? 0.0).compareTo(tripSpendMap[a.id] ?? 0.0));

    return ListView(
      padding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width > 800 ? (MediaQuery.sizeOf(context).width - 760) / 2 : 16.0, 12, MediaQuery.sizeOf(context).width > 800 ? (MediaQuery.sizeOf(context).width - 760) / 2 : 16.0, 32),
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
              const Text(
                'Cumulative Travel Spending Across All Journeys',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                CurrencyFormatter.format(
                  CurrencyFormatter.convertEstimated(totalSpent, 'INR', _previewCurrency),
                  currency: _previewCurrency,
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              if (_previewCurrency != 'INR') ...[
                const SizedBox(height: 3),
                Text(
                  'Base: ${CurrencyFormatter.format(totalSpent, currency: 'INR')}',
                  style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 12),
              // Currency Preview Switcher
              SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: ['INR', 'USD', 'EUR', 'GBP', 'AED', 'SGD', 'THB'].map((cur) {
                    final isSel = _previewCurrency == cur;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _previewCurrency = cur);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isSel ? Colors.white : Colors.white.withAlpha(35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            cur,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isSel ? const Color(0xFF0D9488) : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat('Total Trips', '${trips.length}', Colors.white),
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
                      'Global Category Breakdown',
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
                        final color = AppConstants.getExpenseCategoryColor(entry.key);
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
                                    AppConstants.getExpenseIcon(entry.key),
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
                  final color = AppConstants.getExpenseCategoryColor(entry.key);
                  final count = expenses.where((e) {
                    final label = AppConstants.normalizeExpenseCategory(e.category);
                    return label == entry.key;
                  }).length;
                  final percentage = totalSpent > 0 ? (entry.value / totalSpent) * 100 : 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(AppConstants.getExpenseIcon(entry.key), size: 14, color: color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color),
                              ),
                              Text(
                                '$count bill${count == 1 ? "" : "s"} • ${percentage.toStringAsFixed(1)}%',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          CurrencyFormatter.format(entry.value, currency: 'INR'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
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

        // Trip Spending Leaderboard
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
                      'Spending by Journey Ranking',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...rankedTrips.map((trip) {
                  final spent = tripSpendMap[trip.id] ?? 0.0;
                  final ratio = totalSpent > 0 ? spent / totalSpent : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                trip.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              CurrencyFormatter.format(spent, currency: trip.defaultCurrency),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio.clamp(0.0, 1.0),
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
      ],
    );
  }

  // ==========================================
  // TRIP-WISE GROUPED EXPENSE LEDGER (Global)
  // ==========================================
  Widget _buildGlobalTripwiseLedgerTab(
    BuildContext context,
    List<Trip> trips,
    List<Expense> allExpenses,
    bool isDark,
  ) {
    if (allExpenses.isEmpty) {
      return _buildNoDataPlaceholder(
        icon: Icons.receipt_long_rounded,
        title: 'No Expenses in Ledger',
        subtitle: 'Add expenses from your journeys to see an itemized, trip-wise ledger.',
      );
    }

    // Filter and group trips that have expenses or all active trips
    final tripsWithExpenses = trips.where((t) => allExpenses.any((e) => e.tripId == t.id)).toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 36),
      itemCount: tripsWithExpenses.length,
      itemBuilder: (context, index) {
        final trip = tripsWithExpenses[index];
        final tripExpenses = allExpenses.where((e) => e.tripId == trip.id).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final tripTotal = tripExpenses.fold<double>(0.0, (sum, e) => sum + e.totalAmount);

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              width: 1,
            ),
          ),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: index == 0,
              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.card_travel_rounded, color: AppTheme.primary, size: 20),
              ),
              title: Text(
                trip.title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${tripExpenses.length} bill${tripExpenses.length == 1 ? "" : "s"} • ${DateFormatter.formatTripDateRange(trip.startDate, trip.endDate)}',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(tripTotal, currency: trip.defaultCurrency),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.secondary),
                  ),
                  const SizedBox(height: 2),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey),
                ],
              ),
              children: tripExpenses.map((expense) {
                final categoryColor = AppConstants.getExpenseCategoryColor(expense.category);
                final categoryIcon = AppConstants.getExpenseIcon(expense.category);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: categoryColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(categoryIcon, color: categoryColor, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              expense.title,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                Text(
                                  'Paid by: ${trip.getMemberName(expense.paidByMemberId)}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (expense.receiptImagePath != null && expense.receiptImagePath!.isNotEmpty)
                                  InkWell(
                                    onTap: () => _showReceiptViewer(context, expense),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withAlpha(25),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.blue.withAlpha(60), width: 0.8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.receipt_rounded, size: 10, color: Colors.blue),
                                          SizedBox(width: 2.5),
                                          Text(
                                            'Receipt',
                                            style: TextStyle(fontSize: 9.5, color: Colors.blue, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.format(expense.totalAmount, currency: trip.defaultCurrency),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                          ),
                          Text(
                            DateFormatter.formatDateTime(expense.createdAt),
                            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // TRIP-SCOPED VIEW (Current Trip Top Card)
  // ==========================================
  Widget _buildTripScopedScreen(
    BuildContext context,
    Trip trip,
    List<dynamic> stoppages,
    List<Expense> expenses,
    bool isDark,
  ) {
    const tabs = [
      Tab(
        icon: Icon(Icons.analytics_rounded, size: 18),
        text: 'Visual Analytics',
      ),
      Tab(
        icon: Icon(Icons.receipt_long_rounded, size: 18),
        text: 'Expense Ledger',
      ),
    ];

    final tabBarView = TabBarView(
      controller: _tabController,
      children: [
        _buildTripVisualAnalyticsTab(context, trip, stoppages, expenses, isDark),
        _buildTripScopedLedgerTab(context, trip, expenses, isDark),
      ],
    );

    if (widget.isEmbedded) {
      return Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 3,
              labelColor: isDark ? Colors.tealAccent : AppTheme.primary,
              unselectedLabelColor: isDark ? Colors.grey[400] : const Color(0xFF64748B),
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              tabs: tabs,
            ),
          ),
          Expanded(child: tabBarView),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${trip.title} • Hub',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Trip Financial Ledger (CSV)',
            onPressed: () {
              final csvContent = StringBuffer();
              csvContent.writeln('ID,Title,Category,Amount,Currency,Payer,Date');
              for (final e in expenses) {
                final payer = trip.getMemberName(e.paidByMemberId);
                csvContent.writeln('"${e.id}","${e.title}","${e.category}",${e.totalAmount},"${e.currency}","$payer","${e.createdAt.toIso8601String()}"');
              }
              TripShareService.shareText(
                'Financial Ledger for ${trip.title}\n\n${csvContent.toString()}',
                subject: '${trip.title} - Expense Ledger CSV',
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Financial ledger ready to share/export.'), behavior: SnackBarBehavior.floating),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelColor: isDark ? Colors.tealAccent : AppTheme.primary,
          unselectedLabelColor: isDark ? Colors.grey[400] : const Color(0xFF64748B),
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: tabs,
        ),
      ),
      body: tabBarView,
      bottomNavigationBar: const UniversalBottomBar(),
    );
  }

  Widget _buildTripVisualAnalyticsTab(
    BuildContext context,
    Trip trip,
    List<dynamic> stoppages,
    List<Expense> expenses,
    bool isDark,
  ) {
    final totalSpent = expenses.fold<double>(0.0, (sum, e) => sum + e.totalAmount);
    final tripDurationDays = math.max(1, trip.endDate.difference(trip.startDate).inDays + 1);
    final daysElapsed = math.max(1, math.min(tripDurationDays, DateTime.now().difference(trip.startDate).inDays + 1));
    final dailyAvgSpent = totalSpent / daysElapsed;
    final budget = trip.budget;
    final hasBudget = budget != null && budget > 0;
    final budgetRemaining = hasBudget ? (budget - totalSpent) : null;
    final budgetPercent = hasBudget ? (totalSpent / budget).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = hasBudget && totalSpent > budget;
    final daysOfBudgetRemaining = (hasBudget && !isOverBudget && dailyAvgSpent > 0.01 && budgetRemaining! > 0)
        ? (budgetRemaining / dailyAvgSpent)
        : null;

    if (expenses.isEmpty) {
      return _buildNoDataPlaceholder(
        icon: Icons.receipt_long_rounded,
        title: 'No Bills Logged for this Journey',
        subtitle: 'Add expenses and split bills with companions to generate spending breakdowns and charts.',
      );
    }

    // Category aggregation using robust normalizer (Point 21 fix)
    final Map<String, double> categoryTotals = {};
    for (final exp in expenses) {
      final label = AppConstants.normalizeExpenseCategory(exp.category);
      categoryTotals[label] = (categoryTotals[label] ?? 0.0) + exp.totalAmount;
    }
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width > 800 ? (MediaQuery.sizeOf(context).width - 760) / 2 : 16.0, 12, MediaQuery.sizeOf(context).width > 800 ? (MediaQuery.sizeOf(context).width - 760) / 2 : 16.0, 32),
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
                CurrencyFormatter.format(
                  CurrencyFormatter.convertEstimated(totalSpent, trip.defaultCurrency, _previewCurrency),
                  currency: _previewCurrency,
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              if (_previewCurrency != trip.defaultCurrency) ...[
                const SizedBox(height: 3),
                Text(
                  'Base: ${CurrencyFormatter.format(totalSpent, currency: trip.defaultCurrency)}',
                  style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 12),
              // Currency Preview Switcher
              SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: {trip.defaultCurrency, 'INR', 'USD', 'EUR', 'GBP', 'AED', 'SGD', 'THB'}.map((cur) {
                      final isSel = _previewCurrency == cur;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _previewCurrency = cur);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSel ? Colors.white : Colors.white.withAlpha(35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              cur,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: isSel ? const Color(0xFF0D9488) : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(child: _buildMiniStat('Stoppages', '${stoppages.length}', Colors.white)),
                  Container(width: 1, height: 26, color: Colors.white24),
                  Expanded(child: _buildMiniStat('Bills Logged', '${expenses.length}', Colors.white)),
                  Container(width: 1, height: 26, color: Colors.white24),
                  Expanded(
                    child: _buildMiniStat(
                      'Avg / Person',
                      CurrencyFormatter.format(
                        trip.members.isNotEmpty ? totalSpent / trip.members.length : totalSpent,
                        currency: trip.defaultCurrency,
                      ),
                      Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Budget Health & Burn-Rate Forecast Card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                            hasBudget ? (isOverBudget ? Icons.warning_rounded : Icons.savings_rounded) : Icons.trending_up_rounded,
                            size: 18,
                            color: hasBudget ? (isOverBudget ? Colors.red : const Color(0xFF10B981)) : AppTheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hasBudget ? 'Budget Health & Pace' : 'Daily Spending Pace',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasBudget) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isOverBudget ? Colors.red : const Color(0xFF10B981)).withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isOverBudget ? 'Over Budget' : '${(budgetPercent * 100).toStringAsFixed(0)}% Used',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isOverBudget ? Colors.red : const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                if (hasBudget) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: budgetPercent,
                      minHeight: 8,
                      backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOverBudget
                            ? Colors.red
                            : (budgetPercent > 0.8 ? Colors.amber : const Color(0xFF10B981)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Budget: ${CurrencyFormatter.format(budget, currency: trip.defaultCurrency)}',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isOverBudget
                              ? 'Over: ${CurrencyFormatter.format(totalSpent - budget, currency: trip.defaultCurrency)}'
                              : 'Left: ${CurrencyFormatter.format(budgetRemaining!, currency: trip.defaultCurrency)}',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isOverBudget ? Colors.red : const Color(0xFF10B981),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Burn: ${CurrencyFormatter.format(dailyAvgSpent, currency: trip.defaultCurrency)}/d',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[300] : const Color(0xFF334155)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: daysOfBudgetRemaining != null
                          ? Text(
                              '~${daysOfBudgetRemaining.toStringAsFixed(1)}d left',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            )
                          : Text(
                              'Day $daysElapsed/$tripDurationDays',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

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
                    Expanded(
                      child: Text(
                        'Spending by Category',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
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
                        final color = AppConstants.getExpenseCategoryColor(entry.key);
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
                                    AppConstants.getExpenseIcon(entry.key),
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
                  final color = AppConstants.getExpenseCategoryColor(entry.key);
                  final count = expenses.where((e) {
                    final label = AppConstants.normalizeExpenseCategory(e.category);
                    return label == entry.key;
                  }).length;
                  final percentage = totalSpent > 0 ? (entry.value / totalSpent) * 100 : 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(AppConstants.getExpenseIcon(entry.key), size: 14, color: color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color),
                              ),
                              Text(
                                '$count bill${count == 1 ? "" : "s"} • ${percentage.toStringAsFixed(1)}%',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          CurrencyFormatter.format(entry.value, currency: trip.defaultCurrency),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
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

        // Point 23: User-Wise / Member-Wise Spendings Breakdown Card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.people_alt_rounded, size: 18, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Member-Wise Spending Breakdown',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...(trip.members.map((member) {
                  final memberPaid = expenses
                      .where((e) => e.paidByMemberId == member.id)
                      .fold<double>(0.0, (acc, e) => acc + e.totalAmount);
                  return (member: member, paid: memberPaid);
                }).toList()..sort((a, b) => a.paid.compareTo(b.paid))).map((item) {
                  final member = item.member;
                  final memberPaid = item.paid;
                  final pct = totalSpent > 0 ? (memberPaid / totalSpent) : 0.0;
                  final isCurrentUser = member.id == trip.currentUserMember?.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppTheme.primary.withAlpha(isDark ? 50 : 30),
                              child: Text(
                                member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      member.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isCurrentUser) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withAlpha(isDark ? 40 : 25),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'YOU',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(memberPaid, currency: trip.defaultCurrency),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: pct.clamp(0.0, 1.0),
                                  minHeight: 6,
                                  backgroundColor: isDark ? Colors.grey[800] : const Color(0xFFE2E8F0),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    pct > 0.5 ? AppTheme.primary : AppTheme.secondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${(pct * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildTripScopedLedgerTab(
    BuildContext context,
    Trip trip,
    List<Expense> expenses,
    bool isDark,
  ) {
    if (expenses.isEmpty) {
      return _buildNoDataPlaceholder(
        icon: Icons.receipt_long_rounded,
        title: 'No Expenses Recorded',
        subtitle: 'Add expenses to see the itemized bill ledger for ${trip.title}.',
      );
    }

    final sorted = expenses.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 36),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final expense = sorted[index];
        final categoryColor = AppConstants.getExpenseCategoryColor(expense.category);
        final categoryIcon = AppConstants.getExpenseIcon(expense.category);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: categoryColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(categoryIcon, color: categoryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          'Paid by ${trip.getMemberName(expense.paidByMemberId)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (expense.receiptImagePath != null && expense.receiptImagePath!.isNotEmpty)
                          InkWell(
                            onTap: () => _showReceiptViewer(context, expense),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.blue.withAlpha(25),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue.withAlpha(60), width: 0.8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.receipt_rounded, size: 10, color: Colors.blue),
                                  SizedBox(width: 2.5),
                                  Text(
                                    'Receipt',
                                    style: TextStyle(fontSize: 9.5, color: Colors.blue, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(expense.totalAmount, currency: trip.defaultCurrency),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: AppTheme.secondary),
                  ),
                  Text(
                    DateFormatter.formatDateTime(expense.createdAt),
                    style: TextStyle(fontSize: 10.5, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReceiptViewer(BuildContext context, Expense expense) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBar(
              title: Text('Receipt • ${expense.title}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            if (expense.receiptImagePath != null && File(expense.receiptImagePath!).existsSync())
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: Image.file(
                  File(expense.receiptImagePath!),
                  fit: BoxFit.contain,
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text('Receipt image not locally available on this device'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataPlaceholder({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          child: AppEmptyState(
            icon: icon,
            title: title,
            message: subtitle,
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color.withAlpha(180), fontSize: 10),
        ),
      ],
    );
  }
}
