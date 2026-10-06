import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/expense.dart';
import '../../models/trip.dart';
import '../../providers/expense_provider.dart';
import '../../providers/trip_provider.dart';
import '../trip_detail/trip_detail_screen.dart';
import '../common/sheet_drag_handle.dart';

enum ExpenseGroupingMode { byTrip, byDate }

class GlobalExpensesSheet extends ConsumerStatefulWidget {
  const GlobalExpensesSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const GlobalExpensesSheet(),
    );
  }

  @override
  ConsumerState<GlobalExpensesSheet> createState() => _GlobalExpensesSheetState();
}

class _GlobalExpensesSheetState extends ConsumerState<GlobalExpensesSheet> {
  ExpenseGroupingMode _groupingMode = ExpenseGroupingMode.byTrip;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  int _displayedItemLimit = 25;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (mounted) {
        setState(() {
          _displayedItemLimit += 20;
        });
      }
    }
  }

  String _getDateHeader(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormatter.formatShortDate(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    final allExpenses = ref.watch(allExpensesProvider);
    final trips = ref.watch(tripListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter by search query and category
    final filteredExpenses = allExpenses.where((e) {
      if (_selectedCategory != 'All' && e.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesTitle = e.title.toLowerCase().contains(query);
        final matchesCategory = e.category.toLowerCase().contains(query);
        final matchesNotes = e.notes?.toLowerCase().contains(query) ?? false;
        final trip = trips.where((t) => t.id == e.tripId).firstOrNull;
        final matchesTrip = trip?.title.toLowerCase().contains(query) ?? false;
        return matchesTitle || matchesCategory || matchesNotes || matchesTrip;
      }
      return true;
    }).toList();

    // Sort descending by date
    filteredExpenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Calculate total spend
    final totalSpent = filteredExpenses.fold<double>(0.0, (acc, e) => acc + e.totalAmount);
    final defaultCurrency = trips.isNotEmpty ? trips.first.defaultCurrency : 'INR';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SheetDragHandle(margin: EdgeInsets.only(top: 10, bottom: 8)),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Global Expenses Ledger',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${filteredExpenses.length} bills across all expeditions • Total: ${CurrencyFormatter.format(totalSpent, currency: defaultCurrency)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 22),
                  padding: const EdgeInsets.all(10),
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  tooltip: 'Close Ledger',
                ),
              ],
            ),
          ),

          // Search and Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDark : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search bills, merchants, notes...',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.primary),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                tooltip: 'Clear Search',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Grouping Mode Segmented Control
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildGroupingTab('By Trip', ExpenseGroupingMode.byTrip, Icons.explore_outlined, isDark),
                      _buildGroupingTab('By Date', ExpenseGroupingMode.byDate, Icons.calendar_today_rounded, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Category Pills
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryChip('All', isDark),
                ...AppConstants.expenseCategories.map((c) => _buildCategoryChip(c, isDark)),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Divider(height: 1, color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),

          // Body Content
          Expanded(
            child: filteredExpenses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 10),
                        Text(
                          _searchQuery.isNotEmpty ? 'No expenses match "$_searchQuery"' : 'No recorded expenses yet',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add expenses during your trips or scan receipts with OCR.',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    children: _groupingMode == ExpenseGroupingMode.byTrip
                        ? _buildTripGroupedList(filteredExpenses, trips, isDark)
                        : _buildDateGroupedList(filteredExpenses, trips, isDark),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupingTab(String label, ExpenseGroupingMode mode, IconData icon, bool isDark) {
    final isSelected = _groupingMode == mode;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _groupingMode = mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : const Color(0xFF64748B))),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String category, bool isDark) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(category, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        selected: isSelected,
        selectedColor: AppTheme.primary,
        backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF1F5F9),
        labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : const Color(0xFF475569))),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        showCheckmark: false,
        onSelected: (_) => setState(() => _selectedCategory = category),
      ),
    );
  }

  List<Widget> _buildTripGroupedList(List<Expense> expenses, List<Trip> trips, bool isDark) {
    final Map<String, List<Expense>> groups = {};
    for (final e in expenses) {
      groups.putIfAbsent(e.tripId, () => []).add(e);
    }

    final widgets = <Widget>[];
    int count = 0;

    for (final entry in groups.entries) {
      if (count >= _displayedItemLimit) break;
      final tripId = entry.key;
      final tripExpenses = entry.value;
      final trip = trips.where((t) => t.id == tripId).firstOrNull;
      final tripTitle = trip?.title ?? 'Trip $tripId';
      final tripTotal = tripExpenses.fold<double>(0.0, (acc, e) => acc + e.totalAmount);
      final currency = trip?.defaultCurrency ?? 'INR';

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.explore_rounded, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tripTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${tripExpenses.length} bills • ${CurrencyFormatter.format(tripTotal, currency: currency)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );

      for (final exp in tripExpenses) {
        if (count >= _displayedItemLimit) break;
        count++;
        widgets.add(_buildExpenseCard(exp, trip, isDark));
      }
    }

    if (expenses.length > _displayedItemLimit) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _displayedItemLimit += 20),
              icon: const Icon(Icons.expand_more_rounded),
              label: Text('Load More (${expenses.length - _displayedItemLimit} remaining)'),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  List<Widget> _buildDateGroupedList(List<Expense> expenses, List<Trip> trips, bool isDark) {
    final Map<String, List<Expense>> groups = {};
    for (final e in expenses) {
      final key = '${e.createdAt.year}-${e.createdAt.month.toString().padLeft(2, '0')}-${e.createdAt.day.toString().padLeft(2, '0')}';
      groups.putIfAbsent(key, () => []).add(e);
    }

    final widgets = <Widget>[];
    int count = 0;

    for (final entry in groups.entries) {
      if (count >= _displayedItemLimit) break;
      final dateExpenses = entry.value;
      final dateHeader = _getDateHeader(dateExpenses.first.createdAt);
      final dateTotal = dateExpenses.fold<double>(0.0, (acc, e) => acc + e.totalAmount);
      final currency = trips.isNotEmpty ? trips.first.defaultCurrency : 'INR';

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF0F766E)),
                  const SizedBox(width: 6),
                  Text(
                    dateHeader,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Text(
                '${dateExpenses.length} bills • ${CurrencyFormatter.format(dateTotal, currency: currency)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );

      for (final exp in dateExpenses) {
        if (count >= _displayedItemLimit) break;
        count++;
        final trip = trips.where((t) => t.id == exp.tripId).firstOrNull;
        widgets.add(_buildExpenseCard(exp, trip, isDark));
      }
    }

    if (expenses.length > _displayedItemLimit) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _displayedItemLimit += 20),
              icon: const Icon(Icons.expand_more_rounded),
              label: Text('Load More (${expenses.length - _displayedItemLimit} remaining)'),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildExpenseCard(Expense expense, Trip? trip, bool isDark) {
    final currency = trip?.defaultCurrency ?? 'INR';
    final categoryIcon = AppConstants.getExpenseIcon(expense.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: () {
          if (trip != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => TripDetailScreen(tripId: trip.id),
              ),
            );
          }
        },
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppTheme.primary.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(categoryIcon, size: 18, color: AppTheme.primary),
        ),
        title: Text(
          expense.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                expense.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (trip != null) ...[
              Flexible(
                child: Text(
                  trip.title,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              CurrencyFormatter.format(expense.totalAmount, currency: currency),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF0F766E)),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormatter.formatShortDate(expense.createdAt),
              style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[500] : Colors.grey[600]),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
