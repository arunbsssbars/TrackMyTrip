import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/trip.dart';
import '../../../providers/audit_log_provider.dart';
import '../../../widgets/audit_log_entry_card.dart';

/// Responsive, AQIL-verified embedded Trip Financial Audit Subtab.
/// Strictly captures financial activities: bill creation/edit/deletion,
/// payments, settlements, advance payments, and budget limit changes.
class AuditTab extends ConsumerStatefulWidget {
  final Trip trip;

  const AuditTab({super.key, required this.trip});

  @override
  ConsumerState<AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends ConsumerState<AuditTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _selectedTimeRange = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auditLogs = ref.watch(tripAuditLogsProvider(widget.trip.id));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allCount = auditLogs.length;
    final billsCount = auditLogs.where((l) => l.category == 'expense').length;
    final paymentsCount = auditLogs.where((l) => l.category == 'settlement').length;
    final advanceCount = auditLogs.where((l) => l.category == 'advance').length;
    final budgetCount = auditLogs.where((l) => l.category == 'budget').length;

    final query = _searchQuery.trim().toLowerCase();

    final filteredLogs = auditLogs.where((l) {
      if (_selectedCategory != 'all' && l.category != _selectedCategory) {
        return false;
      }
      if (_selectedTimeRange != 'all') {
        final now = DateTime.now();
        if (_selectedTimeRange == 'today') {
          final isSameDay = l.timestamp.year == now.year &&
              l.timestamp.month == now.month &&
              l.timestamp.day == now.day;
          if (!isSameDay) return false;
        } else if (_selectedTimeRange == '7days') {
          final sevenDaysAgo = now.subtract(const Duration(days: 7));
          if (l.timestamp.isBefore(sevenDaysAgo)) return false;
        }
      }
      if (query.isNotEmpty) {
        final matchesTitle = l.itemTitle.toLowerCase().contains(query);
        final matchesPerformer = l.performedByName.toLowerCase().contains(query);
        final matchesReason = l.reason?.toLowerCase().contains(query) ?? false;
        final matchesDetails = l.changeDetails?.toLowerCase().contains(query) ?? false;
        final matchesAction = l.actionType.toLowerCase().replaceAll('_', ' ').contains(query);
        final matchesAmount = l.amount != null && l.amount!.toString().contains(query);
        return matchesTitle || matchesPerformer || matchesReason || matchesDetails || matchesAction || matchesAmount;
      }
      return true;
    }).toList();

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
            // 1. Header Banner
            Container(
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Financial Audit Trail',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Immutable ledger of bills, payments, advances & settlements.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Search Field
            TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search financial records...',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.2),
                ),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),

            // 3. Time Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTimeFilterChip('all', 'All Time', isDark),
                  const SizedBox(width: 6),
                  _buildTimeFilterChip('today', 'Today', isDark),
                  const SizedBox(width: 6),
                  _buildTimeFilterChip('7days', 'Last 7 Days', isDark),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 4. Financial Category Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryFilterChip('all', 'All ($allCount)', isDark),
                  const SizedBox(width: 6),
                  _buildCategoryFilterChip('expense', 'Bills ($billsCount)', isDark),
                  const SizedBox(width: 6),
                  _buildCategoryFilterChip('settlement', 'Payments ($paymentsCount)', isDark),
                  if (advanceCount > 0) ...[
                    const SizedBox(width: 6),
                    _buildCategoryFilterChip('advance', 'Advance ($advanceCount)', isDark),
                  ],
                  if (budgetCount > 0) ...[
                    const SizedBox(width: 6),
                    _buildCategoryFilterChip('budget', 'Budget ($budgetCount)', isDark),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 5. Entries List
            if (filteredLogs.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 40,
                      color: isDark ? Colors.grey[600] : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No financial records matching "$_searchQuery"'
                          : 'No financial activities recorded yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...filteredLogs.map(
                (log) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AuditLogEntryCard(log: log, trip: widget.trip),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTimeFilterChip(String key, String label, bool isDark) {
    final isSelected = _selectedTimeRange == key;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTimeRange = key;
        });
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppTheme.primary : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilterChip(String category, String label, bool isDark) {
    final isSelected = _selectedCategory == category;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0F766E)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F766E) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }
}
