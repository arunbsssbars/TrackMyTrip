import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/services/trip_share_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/expense.dart';
import '../../../models/stoppage.dart';
import '../../../models/trip.dart';
import '../../../models/trip_audit_log.dart';
import '../../../providers/audit_log_provider.dart';
import '../../../providers/expense_provider.dart';
import '../../../providers/settlement_provider.dart';
import '../../../providers/stoppage_provider.dart';
import '../../../providers/trip_provider.dart';
import '../audit_log_sheet.dart';
import '../../../widgets/expense_detail_sheet.dart';

class ExpensesTab extends ConsumerStatefulWidget {
  final Trip trip;

  const ExpensesTab({super.key, required this.trip});

  @override
  ConsumerState<ExpensesTab> createState() => _ExpensesTabState();
}

enum ExpenseSortMode { newestFirst, oldestFirst, highestAmount, lowestAmount }

class _ExpensesTabState extends ConsumerState<ExpensesTab> {
  String? _selectedCategoryFilter;
  String? _selectedPayerFilter; // Loop 127: Quick filter by companion / payer
  String? _previewCurrency; // Loop 108: Multi-currency quick preview
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _displayLimit = 20;
  ExpenseSortMode _sortMode = ExpenseSortMode.newestFirst;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_displayLimit < 500) {
        setState(() {
          _displayLimit += 20;
        });
      }
    }
  }

  void _resetAllFilters() {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedCategoryFilter = null;
      _selectedPayerFilter = null;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _showExpenseDetailSheet(BuildContext context, Expense expense, Stoppage? matchedStop) {
    ExpenseDetailSheet.show(context, ref, widget.trip, expense, matchedStop: matchedStop);
  }

  void _showSortBottomSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(isDark ? 80 : 100),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.sort_rounded, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Sort Bills By',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _buildSortOption(
              ctx,
              title: 'Newest First',
              subtitle: 'Most recently recorded bills at top',
              icon: Icons.calendar_today_rounded,
              mode: ExpenseSortMode.newestFirst,
            ),
            _buildSortOption(
              ctx,
              title: 'Oldest First',
              subtitle: 'Earliest bills at top',
              icon: Icons.history_rounded,
              mode: ExpenseSortMode.oldestFirst,
            ),
            _buildSortOption(
              ctx,
              title: 'Highest Amount',
              subtitle: 'Largest expenditures first',
              icon: Icons.arrow_upward_rounded,
              mode: ExpenseSortMode.highestAmount,
            ),
            _buildSortOption(
              ctx,
              title: 'Lowest Amount',
              subtitle: 'Smallest expenditures first',
              icon: Icons.arrow_downward_rounded,
              mode: ExpenseSortMode.lowestAmount,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(
    BuildContext ctx, {
    required String title,
    required String subtitle,
    required IconData icon,
    required ExpenseSortMode mode,
  }) {
    final isSelected = _sortMode == mode;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.primary : Colors.grey),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? AppTheme.primary : null,
          fontSize: 14,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary) : null,
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(ctx).pop();
        setState(() {
          _sortMode = mode;
        });
      },
    );
  }

  Widget _buildDateHeader(DateTime date, double dayTotal, int dayCount, String currency, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    final String dateLabel = d == today
        ? 'Today'
        : d == yesterday
            ? 'Yesterday'
            : DateFormatter.formatShortDate(date);

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 13,
                color: d == today ? AppTheme.primary : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 5),
              Text(
                dateLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: d == today ? AppTheme.primary : (isDark ? Colors.grey[200] : AppTheme.textMainLight),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(12) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                width: 0.8,
              ),
            ),
            child: Text(
              '${CurrencyFormatter.format(dayTotal, currency: currency)} • $dayCount bill${dayCount == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.grey[300] : const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Loop 107: Daily spending trend sparkline breakdown
  Widget _buildDailySpendingSparkline(Map<String, double> dayTotals, bool isDark, String currency) {
    if (dayTotals.length < 2) return const SizedBox.shrink();
    final sortedKeys = dayTotals.keys.toList()..sort();
    final maxSpend = dayTotals.values.fold<double>(0.0, (m, v) => v > m ? v : m);
    if (maxSpend <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart_rounded, size: 13, color: AppTheme.primary),
                const SizedBox(width: 4),
                Text(
                  'DAILY SPENDING TREND',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            Text(
              '${sortedKeys.length} active days',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withAlpha(8) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0), width: 0.8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: sortedKeys.take(7).map((dKey) {
              final val = dayTotals[dKey] ?? 0.0;
              final heightRatio = (val / maxSpend).clamp(0.15, 1.0);
              final date = DateTime.tryParse(dKey) ?? DateTime.now();
              final dayLabel = DateFormatter.formatShortDate(date).split(' ').first;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        val >= 1000 ? '${(val / 1000).toStringAsFixed(1)}k' : val.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        height: 28 * heightRatio,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha((heightRatio * 180 + 75).toInt().clamp(50, 255)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dayLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showSetBudgetDialog(BuildContext context) {
    final controller = TextEditingController(
      text: widget.trip.budget != null ? widget.trip.budget!.toStringAsFixed(0) : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Set Trip Budget', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set a spending goal for this trip to track your remaining balance:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Trip Budget',
                prefixText: '${CurrencyFormatter.getCurrencySymbol(widget.trip.defaultCurrency)} ',
                hintText: 'e.g. 1000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              final oldBudget = widget.trip.budget;
              final updated = widget.trip.copyWith(budget: val);
              ref.read(tripListProvider.notifier).updateTrip(updated);

              final currentMember = widget.trip.currentUserMember;
              final curSymbol = CurrencyFormatter.getCurrencySymbol(widget.trip.defaultCurrency);
              final changeText = oldBudget == null
                  ? 'Set trip budget to $curSymbol${val?.toStringAsFixed(2) ?? '0.00'}'
                  : 'Updated trip budget from $curSymbol${oldBudget.toStringAsFixed(2)} to $curSymbol${val?.toStringAsFixed(2) ?? '0.00'}';

              ref.read(allAuditLogsProvider.notifier).logAction(
                TripAuditLog(
                  id: const Uuid().v4(),
                  tripId: widget.trip.id,
                  actionType: oldBudget == null ? 'set_budget' : 'update_budget',
                  itemTitle: 'Trip Budget',
                  performedByMemberId: currentMember?.id ?? 'User',
                  performedByName: currentMember?.name ?? 'Companion',
                  timestamp: DateTime.now(),
                  changeDetails: changeText,
                ),
              );

              Navigator.of(ctx).pop();
            },
            child: const Text('Save Budget'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(tripExpensesProvider(widget.trip.id));
    final stoppages = ref.watch(currentTripStoppagesProvider);
    final totalSpent = ref.watch(currentTripTotalSpentProvider);
    final auditLogs = ref.watch(tripAuditLogsProvider(widget.trip.id));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trip = ref.watch(tripListProvider).firstWhere((t) => t.id == widget.trip.id, orElse: () => widget.trip);
    final budget = trip.budget;

    // Point 24: Personal expenses are private to the creator; other companions do not see them.
    final currentMember = trip.currentUserMember;
    final visibleExpenses = expenses.where((e) {
      if (e.isPersonal && currentMember != null && e.paidByMemberId != currentMember.id) {
        return false;
      }
      return true;
    }).toList();

    final advancePool = ref.watch(tripAdvancePoolProvider);
    final personalSpent = visibleExpenses.where((e) => e.isPersonal).fold<double>(0.0, (acc, e) => acc + e.totalAmount);
    final sharedSpent = visibleExpenses.where((e) => !e.isPersonal).fold<double>(0.0, (acc, e) => acc + e.totalAmount);
    final overallTotalSpent = visibleExpenses.fold<double>(0.0, (acc, e) => acc + e.totalAmount);

    final Map<String, int> categoryCounts = {};
    final Map<String, double> categorySums = {};
    for (final e in visibleExpenses) {
      categoryCounts[e.category] = (categoryCounts[e.category] ?? 0) + 1;
      categorySums[e.category] = (categorySums[e.category] ?? 0.0) + e.totalAmount;
    }

    final benchmarkTotal = (budget != null && budget > 0) ? budget : overallTotalSpent;
    String? highSpendCategory;
    double? highSpendPct;
    if (benchmarkTotal > 0 && visibleExpenses.length >= 2) {
      for (final entry in categorySums.entries) {
        final pct = (entry.value / benchmarkTotal) * 100;
        if (pct >= 45.0 && (highSpendPct == null || pct > highSpendPct)) {
          highSpendCategory = entry.key;
          highSpendPct = pct;
        }
      }
    }

    final filteredExpenses = visibleExpenses.where((e) {
      if (_selectedCategoryFilter != null && e.category != _selectedCategoryFilter) {
        return false;
      }
      if (_selectedPayerFilter != null && e.paidByMemberId != _selectedPayerFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final titleMatch = e.title.toLowerCase().contains(query);
        final noteMatch = e.notes?.toLowerCase().contains(query) ?? false;
        final payer = widget.trip.getMember(e.paidByMemberId);
        final payerMatch = payer?.name.toLowerCase().contains(query) ?? false;
        final catMatch = e.category.toLowerCase().contains(query);
        final amountMatch = e.totalAmount.toStringAsFixed(0).contains(query);
        if (!titleMatch && !noteMatch && !payerMatch && !catMatch && !amountMatch) {
          return false;
        }
      }
      return true;
    }).toList();

    // Loop 52: Dynamic multi-sort
    switch (_sortMode) {
      case ExpenseSortMode.newestFirst:
        filteredExpenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case ExpenseSortMode.oldestFirst:
        filteredExpenses.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case ExpenseSortMode.highestAmount:
        filteredExpenses.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
        break;
      case ExpenseSortMode.lowestAmount:
        filteredExpenses.sort((a, b) => a.totalAmount.compareTo(b.totalAmount));
        break;
    }

    // Loop 51: Precompute daily totals and counts for day divider headers
    final Map<String, double> dayTotals = {};
    final Map<String, int> dayCounts = {};
    for (final e in filteredExpenses) {
      final dKey = '${e.createdAt.year}-${e.createdAt.month.toString().padLeft(2, '0')}-${e.createdAt.day.toString().padLeft(2, '0')}';
      dayTotals[dKey] = (dayTotals[dKey] ?? 0.0) + e.totalAmount;
      dayCounts[dKey] = (dayCounts[dKey] ?? 0) + 1;
    }

    final filteredSubtotal = filteredExpenses.fold<double>(0.0, (acc, e) => acc + e.totalAmount);
    final displayedExpenses = filteredExpenses.take(_displayLimit).toList();
    final hasMore = filteredExpenses.length > displayedExpenses.length;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPad = screenWidth >= 800 ? ((screenWidth - 760) / 2).clamp(16.0, 380.0) : 16.0;

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        // Expenditure Summary & Compact Budget Card (Points 7, 8, 10, 11 - Scrollable)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 20 : 6),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_rounded,
                                size: 13,
                                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'TOTAL EXPENDITURE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  CurrencyFormatter.format(overallTotalSpent, currency: trip.defaultCurrency),
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    color: isDark ? Colors.white : AppTheme.textMainLight,
                                  ),
                                ),
                              ),
                              if (_previewCurrency != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withAlpha(isDark ? 40 : 25),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.primary.withAlpha(80), width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '≈ ${CurrencyFormatter.format(CurrencyFormatter.convertEstimated(overallTotalSpent, trip.defaultCurrency, _previewCurrency!), currency: _previewCurrency!)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () => setState(() => _previewCurrency = null),
                                        child: const Icon(Icons.close_rounded, size: 12, color: AppTheme.primary),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          // Currency conversion preview selector chips (Loop 107)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 2),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: ['USD', 'EUR', 'GBP', 'AED', 'SGD', 'THB', 'JPY']
                                    .where((c) => c != trip.defaultCurrency.toUpperCase())
                                    .map((curr) {
                                  final isSel = _previewCurrency == curr;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: InkWell(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() {
                                          _previewCurrency = isSel ? null : curr;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(5),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isSel
                                              ? AppTheme.primary
                                              : (isDark ? Colors.white.withAlpha(12) : const Color(0xFFF1F5F9)),
                                          borderRadius: BorderRadius.circular(5),
                                          border: Border.all(
                                            color: isSel
                                                ? AppTheme.primary
                                                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                            width: 0.7,
                                          ),
                                        ),
                                        child: Text(
                                          curr,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: isSel
                                                ? Colors.white
                                                : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          if (personalSpent > 0 || advancePool.totalAdvanceCollected > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                [
                                  if (personalSpent > 0) 'Shared: ${CurrencyFormatter.format(sharedSpent, currency: trip.defaultCurrency)} • Personal: ${CurrencyFormatter.format(personalSpent, currency: trip.defaultCurrency)}',
                                  if (advancePool.totalAdvanceCollected > 0) 'Kitty Pool: ${CurrencyFormatter.format(advancePool.totalAdvanceCollected, currency: trip.defaultCurrency)}',
                                ].join(' • '),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6366F1),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (budget == null || budget <= 0)
                      // Only show Set Budget pill when no budget is defined
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showSetBudgetDialog(context),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withAlpha(isDark ? 30 : 18),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.primary.withAlpha(60), width: 0.9),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.track_changes_rounded, size: 15, color: AppTheme.primary),
                                SizedBox(width: 4),
                                Text(
                                  'Set Budget',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      // Subtle status pill (Item 7: Edit Target button removed; tap to edit)
                      Flexible(
                        child: GestureDetector(
                          onTap: () => _showSetBudgetDialog(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: (totalSpent > budget
                                      ? Colors.red
                                      : (totalSpent / budget > 0.8
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF10B981)))
                                  .withAlpha(isDark ? 35 : 20),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (totalSpent > budget
                                        ? Colors.red
                                        : (totalSpent / budget > 0.8
                                            ? const Color(0xFFF59E0B)
                                            : const Color(0xFF10B981)))
                                    .withAlpha(isDark ? 90 : 60),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              totalSpent > budget
                                  ? 'Over by ${CurrencyFormatter.format(totalSpent - budget, currency: trip.defaultCurrency)}'
                                  : 'Left: ${CurrencyFormatter.format(budget - totalSpent, currency: trip.defaultCurrency)}',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: totalSpent > budget
                                    ? Colors.red
                                    : (totalSpent / budget > 0.8
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF10B981)),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // Budget Progress Section
                if (budget != null && budget > 0) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: (totalSpent / budget).clamp(0.0, 1.0),
                      backgroundColor: isDark ? Colors.grey[800] : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        totalSpent > budget
                            ? const Color(0xFFEF4444)
                            : (totalSpent / budget > 0.8 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Budget: ${CurrencyFormatter.format(budget, currency: trip.defaultCurrency)}',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${((totalSpent / budget).clamp(0.0, 1.0) * 100).toStringAsFixed(0)}% used',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ] else
                  const SizedBox(height: 4),

                if (highSpendCategory != null && highSpendPct != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(isDark ? 35 : 20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withAlpha(80), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 12, color: isDark ? Colors.amber[300] : Colors.amber[900]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$highSpendCategory takes ${highSpendPct.toStringAsFixed(0)}% of your ${budget != null ? "budget" : "total spending"}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.amber[300] : Colors.amber[900],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // Category Spending Distribution Mini-Bar (Loop 62)
                if (overallTotalSpent > 0 && categorySums.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 5,
                      child: Row(
                        children: categorySums.entries.where((e) => e.value > 0).map((entry) {
                          final pct = entry.value / overallTotalSpent;
                          final color = AppConstants.getExpenseCategoryColor(entry.key);
                          return Expanded(
                            flex: (pct * 1000).toInt().clamp(1, 1000),
                            child: Container(color: color),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: (categorySums.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value)))
                        .take(3)
                        .where((e) => e.value > 0)
                        .map((entry) {
                      final pct = (entry.value / overallTotalSpent * 100).round();
                      final color = AppConstants.getExpenseCategoryColor(entry.key);
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.key.split(' ').first} $pct%',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],

                // Loop 108: Daily spending sparkline breakdown chart
                if (dayTotals.length >= 2) ...[
                  const SizedBox(height: 8),
                  _buildDailySpendingSparkline(dayTotals, isDark, trip.defaultCurrency),
                  const SizedBox(height: 6),
                ],

                // Quick stats row at the bottom of the compact card
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 11.5,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${expenses.length} bill${expenses.length == 1 ? '' : 's'} recorded',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        widget.trip.isSolo
                            ? 'Solo Journey'
                            : widget.trip.isFamily
                                ? 'Family Pool'
                                : '${widget.trip.members.length} members sharing',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        ),
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
        ),

        // Dedicated Full-Width Audit Trail & Trust History Button + Export CSV Action
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 8),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: Ink(
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(isDark ? 22 : 12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.primary.withAlpha(50), width: 1.0),
                      ),
                      child: InkWell(
                        onTap: () => AuditLogSheet.show(context, widget.trip),
                        borderRadius: BorderRadius.circular(14),
                        splashColor: AppTheme.primary.withAlpha(30),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_user_rounded, size: 15, color: AppTheme.primary),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  'Trust History (${auditLogs.length})',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.primary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (expenses.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: Ink(
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(isDark ? 25 : 14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF10B981).withAlpha(60), width: 1.0),
                      ),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          TripShareService.shareExpensesCsv(widget.trip, expenses);
                        },
                        borderRadius: BorderRadius.circular(14),
                        splashColor: const Color(0xFF10B981).withAlpha(30),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.file_download_outlined, size: 15, color: Color(0xFF10B981)),
                              SizedBox(width: 4),
                              Text(
                                'CSV',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Instant Expense Search Bar & Sort Action Button
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 2, hPad, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search bills, payers, notes, or amounts...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 19, color: AppTheme.primary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 17),
                              tooltip: 'Clear search',
                              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? AppTheme.surfaceDark : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: 'Sort Bills',
                  child: Material(
                    color: isDark ? AppTheme.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => _showSortBottomSheet(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _sortMode != ExpenseSortMode.newestFirst
                                ? AppTheme.primary
                                : (isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
                            width: _sortMode != ExpenseSortMode.newestFirst ? 1.5 : 1,
                          ),
                          color: _sortMode != ExpenseSortMode.newestFirst
                              ? AppTheme.primary.withAlpha(isDark ? 30 : 18)
                              : null,
                        ),
                        child: Icon(
                          Icons.swap_vert_rounded,
                          size: 21,
                          color: _sortMode != ExpenseSortMode.newestFirst
                              ? AppTheme.primary
                              : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Category Filter Chips (Scrollable)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 2),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    showCheckmark: false,
                    label: Text('All (${visibleExpenses.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    selected: _selectedCategoryFilter == null,
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(color: _selectedCategoryFilter == null ? Colors.white : null),
                    onSelected: (_) => setState(() => _selectedCategoryFilter = null),
                  ),
                  const SizedBox(width: 6),
                  ...AppConstants.expenseCategories.map((cat) {
                    final isSelected = _selectedCategoryFilter == cat;
                    final count = categoryCounts[cat] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        showCheckmark: false,
                        avatar: Icon(AppConstants.getExpenseIcon(cat), size: 14, color: isSelected ? Colors.white : AppTheme.primary),
                        label: Text('$cat ($count)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        selected: isSelected,
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : null),
                        onSelected: (_) => setState(() => _selectedCategoryFilter = cat),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),

        // Loop 127: Companion Payer Quick Filter Chips (for group trips)
        if (widget.trip.members.length > 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 2),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      showCheckmark: false,
                      avatar: Icon(Icons.people_alt_rounded, size: 13, color: _selectedPayerFilter == null ? Colors.white : AppTheme.primary),
                      label: const Text('All Payers', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                      selected: _selectedPayerFilter == null,
                      selectedColor: const Color(0xFF0D9488),
                      labelStyle: TextStyle(color: _selectedPayerFilter == null ? Colors.white : null),
                      onSelected: (_) => setState(() => _selectedPayerFilter = null),
                    ),
                    const SizedBox(width: 6),
                    ...widget.trip.members.map((member) {
                      final isSelected = _selectedPayerFilter == member.id;
                      final memberExpenseCount = visibleExpenses.where((e) => e.paidByMemberId == member.id).length;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          showCheckmark: false,
                          avatar: Icon(Icons.person_rounded, size: 13, color: isSelected ? Colors.white : const Color(0xFF0D9488)),
                          label: Text('${member.name} ($memberExpenseCount)', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                          selected: isSelected,
                          selectedColor: const Color(0xFF0D9488),
                          labelStyle: TextStyle(color: isSelected ? Colors.white : null),
                          onSelected: (_) => setState(() => _selectedPayerFilter = isSelected ? null : member.id),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),

        // Filtered Subtotal Badge
        if (_selectedCategoryFilter != null || _selectedPayerFilter != null || _searchQuery.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(isDark ? 25 : 15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary.withAlpha(50), width: 0.8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: AppResilientText.badge(
                        'Filtered Subtotal: ${CurrencyFormatter.format(filteredSubtotal, currency: trip.defaultCurrency)} (${filteredExpenses.length} bill${filteredExpenses.length == 1 ? '' : 's'})',
                        textAlign: TextAlign.start,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: 'Reset all filters',
                      child: InkWell(
                        onTap: _resetAllFilters,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.close_rounded, size: 14, color: AppTheme.primary),
                              SizedBox(width: 3),
                              Text(
                                'Reset',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Expense List or Empty State
        if (filteredExpenses.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              icon: Icons.receipt_long_outlined,
              title: _selectedCategoryFilter == null ? 'No Bills Logged Yet' : 'No $_selectedCategoryFilter Bills',
              message: (_selectedCategoryFilter != null || _searchQuery.isNotEmpty)
                  ? 'No expenses matched the active filter or search keyword.'
                  : 'Track shared food, gas, tickets, and activities at each stop.',
              actionLabel: (_selectedCategoryFilter != null || _searchQuery.isNotEmpty) ? 'Reset Filters' : null,
              onAction: (_selectedCategoryFilter != null || _searchQuery.isNotEmpty) ? _resetAllFilters : null,
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 6, hPad, 80),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                        if (index == displayedExpenses.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: Text(
                                'Showing ${displayedExpenses.length} of ${filteredExpenses.length} bills • Scroll for more',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }
                        final expense = displayedExpenses[index];
                        final currentMember = widget.trip.currentUserMember;
                        final payer = widget.trip.getMember(expense.paidByMemberId);
                        final payerName = payer?.name ??
                            (expense.paidByMemberId == currentMember?.id
                                ? (currentMember?.name ?? 'You')
                                : (widget.trip.members.where((m) => m.id == expense.paidByMemberId).firstOrNull?.name ?? 'Companion'));

                    Stoppage? matchedStop;
                    if (expense.stoppageId != null) {
                      for (final s in stoppages) {
                        if (s.id == expense.stoppageId) {
                          matchedStop = s;
                          break;
                        }
                      }
                    }

                    final dateKey = '${expense.createdAt.year}-${expense.createdAt.month.toString().padLeft(2, '0')}-${expense.createdAt.day.toString().padLeft(2, '0')}';
                    final showDateHeader = (_sortMode == ExpenseSortMode.newestFirst || _sortMode == ExpenseSortMode.oldestFirst) &&
                        (index == 0 ||
                            '${displayedExpenses[index - 1].createdAt.year}-${displayedExpenses[index - 1].createdAt.month.toString().padLeft(2, '0')}-${displayedExpenses[index - 1].createdAt.day.toString().padLeft(2, '0')}' != dateKey);

                    final card = Container(
                      margin: const EdgeInsets.symmetric(vertical: 5.5),
                      child: Material(
                        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                        elevation: isDark ? 0 : 2,
                        shadowColor: Colors.black.withAlpha(isDark ? 45 : 18),
                        borderRadius: BorderRadius.circular(18),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _showExpenseDetailSheet(context, expense, matchedStop),
                          borderRadius: BorderRadius.circular(18),
                          splashColor: AppTheme.primary.withAlpha(22),
                          highlightColor: AppTheme.primary.withAlpha(12),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                                width: 1.1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Tier 1: Category Icon + Title + Amount + Foreign + Chevron
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withAlpha(isDark ? 28 : 16),
                                        borderRadius: BorderRadius.circular(11),
                                        border: Border.all(
                                          color: AppTheme.primary.withAlpha(isDark ? 55 : 35),
                                          width: 0.9,
                                        ),
                                      ),
                                      child: Icon(AppConstants.getExpenseIcon(expense.category), color: AppTheme.primary, size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        expense.title,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, letterSpacing: -0.2),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            CurrencyFormatter.format(expense.totalAmount, currency: expense.currency),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16.5,
                                              letterSpacing: -0.4,
                                              color: isDark ? Colors.white : AppTheme.textMainLight,
                                            ),
                                          ),
                                        ),
                                        if (expense.hasForeignConversion)
                                          Text(
                                            CurrencyFormatter.format(expense.originalAmount!, currency: expense.originalCurrency),
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.blue,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 19,
                                      color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                // Tier 2: Payer Name (Left) + Date/Time (Right)
                                Row(
                                  children: [
                                    Icon(Icons.person_outline_rounded, size: 13, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Paid by $payerName',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.schedule_rounded, size: 11.5, color: isDark ? Colors.grey[400] : const Color(0xFF94A3B8)),
                                        const SizedBox(width: 3.5),
                                        Text(
                                          DateFormatter.formatRelativeOrTime(expense.createdAt),
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
                                const SizedBox(height: 6),
                                Divider(
                                  color: isDark ? AppTheme.borderDark : const Color(0xFFF1F5F9),
                                  height: 1,
                                  thickness: 0.8,
                                ),
                                const SizedBox(height: 5),

                                // Stoppage Anchor tag + Bill Badge + Splits Info
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        if (matchedStop != null)
                                          Material(
                                            color: Colors.transparent,
                                            child: Ink(
                                              decoration: BoxDecoration(
                                                color: AppTheme.secondary.withAlpha(isDark ? 28 : 18),
                                                borderRadius: BorderRadius.circular(7),
                                                border: Border.all(color: AppTheme.secondary.withAlpha(isDark ? 80 : 50), width: 0.8),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.place_rounded, size: 11.5, color: AppTheme.secondary),
                                                    const SizedBox(width: 3.5),
                                                    ConstrainedBox(
                                                      constraints: const BoxConstraints(maxWidth: 130),
                                                      child: Text(
                                                        matchedStop.name,
                                                        style: const TextStyle(
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppTheme.secondary,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          )
                                        else if (expense.locationName != null && expense.locationName!.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppTheme.secondary.withAlpha(isDark ? 28 : 18),
                                              borderRadius: BorderRadius.circular(7),
                                              border: Border.all(color: AppTheme.secondary.withAlpha(isDark ? 80 : 50), width: 0.8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.place_rounded, size: 11.5, color: AppTheme.secondary),
                                                const SizedBox(width: 3.5),
                                                ConstrainedBox(
                                                  constraints: const BoxConstraints(maxWidth: 130),
                                                  child: Text(
                                                    expense.locationName!,
                                                    style: const TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.secondary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          Text('General Trip', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                        if (expense.receiptImagePath != null)
                                          Material(
                                            color: Colors.transparent,
                                            child: Ink(
                                              decoration: BoxDecoration(
                                                color: Colors.teal.withAlpha(isDark ? 30 : 20),
                                                borderRadius: BorderRadius.circular(7),
                                                border: Border.all(color: Colors.teal.withAlpha(isDark ? 80 : 50), width: 0.8),
                                              ),
                                              child: InkWell(
                                                onTap: () {
                                                  HapticFeedback.selectionClick();
                                                  ExpenseDetailSheet.showReceiptDialog(context, expense);
                                                },
                                                borderRadius: BorderRadius.circular(7),
                                                splashColor: Colors.teal.withAlpha(40),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      ClipRRect(
                                                        borderRadius: BorderRadius.circular(3),
                                                        child: SizedBox(
                                                          width: 13,
                                                          height: 13,
                                                          child: ExpenseDetailSheet.buildReceiptImage(expense.receiptImagePath!),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      const Text(
                                                        'Receipt',
                                                        style: TextStyle(
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.teal,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (expense.isPersonal)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6366F1).withAlpha(isDark ? 35 : 20),
                                          borderRadius: BorderRadius.circular(7),
                                          border: Border.all(
                                            color: const Color(0xFF6366F1).withAlpha(isDark ? 90 : 60),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.lock_rounded, size: 11.5, color: Color(0xFF6366F1)),
                                            SizedBox(width: 4),
                                            Text(
                                              'Personal (Private)',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF6366F1),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white.withAlpha(10) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(7),
                                          border: Border.all(
                                            color: isDark ? Colors.white.withAlpha(18) : const Color(0xFFE2E8F0),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              widget.trip.isSolo
                                                  ? Icons.person_rounded
                                                  : widget.trip.isFamily
                                                      ? Icons.family_restroom_rounded
                                                      : Icons.group_rounded,
                                              size: 11.5,
                                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              widget.trip.isSolo
                                                  ? 'Solo Log'
                                                  : widget.trip.isFamily
                                                      ? 'Family Pool'
                                                      : 'Split • ${expense.splits.where((s) => s.isIncluded).length} members',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );

                    if (showDateHeader) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildDateHeader(
                            expense.createdAt,
                            dayTotals[dateKey] ?? expense.totalAmount,
                            dayCounts[dateKey] ?? 1,
                            trip.defaultCurrency,
                            isDark,
                          ),
                          card,
                        ],
                      );
                    }

                    return card;
                  },
                  childCount: displayedExpenses.length + (hasMore ? 1 : 0),
                ),
              ),
            ),
        ],
      );
    }
}