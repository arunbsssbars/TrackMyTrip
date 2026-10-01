import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/expense.dart';
import '../../../models/stoppage.dart';
import '../../../models/trip.dart';
import '../../../models/trip_audit_log.dart';
import '../../../providers/audit_log_provider.dart';
import '../../../providers/expense_provider.dart';
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

class _ExpensesTabState extends ConsumerState<ExpensesTab> {
  String? _selectedCategoryFilter;
  final ScrollController _scrollController = ScrollController();
  int _displayLimit = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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

  void _showExpenseDetailSheet(BuildContext context, Expense expense, Stoppage? matchedStop) {
    ExpenseDetailSheet.show(context, ref, widget.trip, expense, matchedStop: matchedStop);
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

    final personalSpent = visibleExpenses.where((e) => e.isPersonal).fold<double>(0.0, (acc, e) => acc + e.totalAmount);
    final sharedSpent = visibleExpenses.where((e) => !e.isPersonal).fold<double>(0.0, (acc, e) => acc + e.totalAmount);
    final overallTotalSpent = visibleExpenses.fold<double>(0.0, (acc, e) => acc + e.totalAmount);

    final filteredExpenses = _selectedCategoryFilter == null
        ? visibleExpenses
        : visibleExpenses.where((e) => e.category == _selectedCategoryFilter).toList();

    final displayedExpenses = filteredExpenses.take(_displayLimit).toList();
    final hasMore = filteredExpenses.length > displayedExpenses.length;

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        // Expenditure Summary & Compact Budget Card (Points 7, 8, 10, 11 - Scrollable)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                          if (personalSpent > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Shared: ${CurrencyFormatter.format(sharedSpent, currency: trip.defaultCurrency)} • Personal: ${CurrencyFormatter.format(personalSpent, currency: trip.defaultCurrency)}',
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

                const SizedBox(height: 8),

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

        // Dedicated Full-Width Audit Trail & Trust History Button (Item 10 & 11 - Scrollable)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, size: 15, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Audit Trail & Trust History (${auditLogs.length} events logged)',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded, size: 17, color: AppTheme.primary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        ),

        // Category Filter Chips (Scrollable)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  showCheckmark: false,
                  label: const Text('All Bills', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  selected: _selectedCategoryFilter == null,
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(color: _selectedCategoryFilter == null ? Colors.white : null),
                  onSelected: (_) => setState(() => _selectedCategoryFilter = null),
                ),
                const SizedBox(width: 6),
                ...AppConstants.expenseCategories.map((cat) {
                  final isSelected = _selectedCategoryFilter == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      showCheckmark: false,
                      avatar: Icon(AppConstants.getExpenseIcon(cat), size: 14, color: isSelected ? Colors.white : AppTheme.primary),
                      label: Text(cat, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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

        // Expense List or Empty State
        if (filteredExpenses.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    _selectedCategoryFilter == null ? 'No Bills Logged Yet' : 'No $_selectedCategoryFilter Bills',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text('Track shared food, gas, tickets, and activities at each stop.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
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

                    return Container(
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
                                        Text(
                                          CurrencyFormatter.format(expense.totalAmount, currency: expense.currency),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16.5,
                                            letterSpacing: -0.4,
                                            color: isDark ? Colors.white : AppTheme.textMainLight,
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
                                                onTap: () => ExpenseDetailSheet.showReceiptDialog(context, expense),
                                                borderRadius: BorderRadius.circular(7),
                                                splashColor: Colors.teal.withAlpha(40),
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.receipt_long_rounded, size: 11.5, color: Colors.teal),
                                                      SizedBox(width: 3.5),
                                                      Text(
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
                  },
                  childCount: displayedExpenses.length + (hasMore ? 1 : 0),
                ),
              ),
            ),
        ],
      );
    }
}