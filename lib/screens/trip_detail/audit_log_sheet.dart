import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/trip.dart';
import '../../models/trip_audit_log.dart';
import '../../providers/audit_log_provider.dart';
import '../../widgets/audit_log_entry_card.dart';

class AuditLogSheet extends ConsumerStatefulWidget {
  final Trip trip;

  const AuditLogSheet({super.key, required this.trip});

  static void show(BuildContext context, Trip trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AuditLogSheet(trip: trip),
    );
  }

  @override
  ConsumerState<AuditLogSheet> createState() => _AuditLogSheetState();
}

class _AuditLogSheetState extends ConsumerState<AuditLogSheet> {
  final Set<String> _expandedDates = {};
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _displayLimit = 10;
  String _selectedCategory = 'all';
  String _selectedTimeRange = 'all';
  String? _selectedMemberId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 150) {
      if (_displayLimit < 200) {
        setState(() {
          _displayLimit += 10;
        });
      }
    }
  }

  String _getDateKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatDateHeading(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final logDate = DateTime(dt.year, dt.month, dt.day);

    if (logDate == today) {
      return 'Today • ${DateFormatter.formatShortDate(dt)}';
    } else if (logDate == yesterday) {
      return 'Yesterday • ${DateFormatter.formatShortDate(dt)}';
    } else {
      return DateFormatter.formatShortDate(dt);
    }
  }

  Widget _buildFilterChip(String category, String label) {
    final isSelected = _selectedCategory == category;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary
              : (isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey[300] : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeRangeChip(String rangeKey, String label) {
    final isSelected = _selectedTimeRange == rangeKey;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTimeRange = rangeKey;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF0284C7) : const Color(0xFF0EA5E9))
              : (isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0EA5E9)
                : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (rangeKey == 'today') ...[
              Icon(Icons.today_rounded, size: 12, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(width: 4),
            ] else if (rangeKey == '7days') ...[
              Icon(Icons.date_range_rounded, size: 12, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auditLogs = ref.watch(tripAuditLogsProvider(widget.trip.id));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allCount = auditLogs.length;
    final billsCount = auditLogs.where((l) => l.category == 'expense').length;
    final paymentsCount = auditLogs.where((l) => l.category == 'settlement').length;
    final stopsCount = auditLogs.where((l) => l.category == 'stoppage').length;
    final memoriesCount = auditLogs.where((l) => l.category == 'memory').length;
    final tripCount = auditLogs.where((l) => l.category == 'trip' || l.category == 'general').length;

    final query = _searchQuery.trim().toLowerCase();

    final filteredLogs = auditLogs.where((l) {
      if (_selectedCategory != 'all') {
        if (_selectedCategory == 'trip') {
          if (l.category != 'trip' && l.category != 'general') return false;
        } else if (l.category != _selectedCategory) {
          return false;
        }
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
      if (_selectedMemberId != null && l.performedByMemberId != _selectedMemberId) {
        return false;
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

    // Group audit logs by date key (YYYY-MM-DD)
    final Map<String, List<TripAuditLog>> groupedByDate = {};
    for (final log in filteredLogs) {
      final key = _getDateKey(log.timestamp);
      groupedByDate.putIfAbsent(key, () => []).add(log);
    }

    // Sort dates descending
    final sortedDateKeys = groupedByDate.keys.toList()..sort((a, b) => b.compareTo(a));

    // Ensure the latest date accordion is open by default (Requirement 2)
    if (_expandedDates.isEmpty && sortedDateKeys.isNotEmpty) {
      _expandedDates.add(sortedDateKeys.first);
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.verified_user_rounded, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audit Trail & Trust History',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                    ),
                    Text(
                      'Immutable financial audit trail & tamper-evident history',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Instant Search Bar
          TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search audit records, items, members...',
              hintStyle: TextStyle(
                fontSize: 12,
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
              fillColor: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF1F5F9),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primary, width: 1.2),
              ),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),

          // Date/Time Range Quick Filter Chips (Loop 66)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTimeRangeChip('all', 'All Time'),
                const SizedBox(width: 6),
                _buildTimeRangeChip('today', 'Today'),
                const SizedBox(width: 6),
                _buildTimeRangeChip('7days', 'Last 7 Days'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Category filter pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All ($allCount)'),
                const SizedBox(width: 8),
                _buildFilterChip('expense', 'Bills ($billsCount)'),
                const SizedBox(width: 8),
                _buildFilterChip('settlement', 'Payments ($paymentsCount)'),
                if (stopsCount > 0) ...[
                  const SizedBox(width: 8),
                  _buildFilterChip('stoppage', 'Stops ($stopsCount)'),
                ],
                if (memoriesCount > 0) ...[
                  const SizedBox(width: 8),
                  _buildFilterChip('memory', 'Photos ($memoriesCount)'),
                ],
                if (tripCount > 0) ...[
                  const SizedBox(width: 8),
                  _buildFilterChip('trip', 'Trip ($tripCount)'),
                ],
              ],
            ),
          ),

          // Loop 118: Companion Member Quick Filter Chips
          if (widget.trip.members.length > 1) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  InkWell(
                    onTap: () => setState(() => _selectedMemberId = null),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _selectedMemberId == null
                            ? AppTheme.primary
                            : (isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedMemberId == null
                              ? AppTheme.primary
                              : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
                        ),
                      ),
                      child: Text(
                        'All Companions',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _selectedMemberId == null ? FontWeight.bold : FontWeight.w500,
                          color: _selectedMemberId == null
                              ? Colors.white
                              : (isDark ? Colors.grey[300] : const Color(0xFF334155)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ...widget.trip.members.map((m) {
                    final isSel = _selectedMemberId == m.id;
                    final memberActionCount = auditLogs.where((l) => l.performedByMemberId == m.id).length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => setState(() => _selectedMemberId = isSel ? null : m.id),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSel
                                ? AppTheme.primary
                                : (isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSel
                                  ? AppTheme.primary
                                  : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
                            ),
                          ),
                          child: Text(
                            '${m.name.split(" ").first} ($memberActionCount)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                              color: isSel
                                  ? Colors.white
                                  : (isDark ? Colors.grey[300] : const Color(0xFF334155)),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          const Divider(height: 16),

          // Audit Logs List grouped datewise
          Expanded(
            child: filteredLogs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.shield_outlined,
                            size: 52,
                            color: AppTheme.primary.withAlpha(120),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty ? 'No Matching Records' : 'No Activity Recorded',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No audit trail entries matched "$_searchQuery".'
                                : (_selectedCategory == 'all'
                                    ? 'No trip activities have been logged yet.\nEvery action (stoppage, bill, photo, payment) is broadcasted live to all companions.'
                                    : 'No activity under this category yet.'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[500], fontSize: 12, height: 1.4),
                          ),
                          if (_searchQuery.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Clear Search Filter'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : Builder(
                    builder: (context) {
                      final displayedDateKeys = sortedDateKeys.take(_displayLimit).toList();
                      final hasMore = sortedDateKeys.length > displayedDateKeys.length;

                      return ListView.builder(
                        controller: _scrollController,
                        itemCount: displayedDateKeys.length + (hasMore ? 1 : 0),
                        itemBuilder: (context, dateIndex) {
                          if (dateIndex == displayedDateKeys.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: Text(
                                  'Showing ${displayedDateKeys.length} of ${sortedDateKeys.length} days • Scroll for more',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          }
                          final dateKey = displayedDateKeys[dateIndex];
                          final dateLogs = groupedByDate[dateKey]!;
                          final isExpanded = _expandedDates.contains(dateKey);
                          final firstDate = dateLogs.first.timestamp;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                            ),
                            child: Column(
                              children: [
                                // Date Accordion Header
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (isExpanded) {
                                        _expandedDates.remove(dateKey);
                                      } else {
                                        _expandedDates.add(dateKey);
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary.withAlpha(20),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.primary),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _formatDateHeading(firstDate),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isExpanded ? AppTheme.primary : Colors.grey.withAlpha(40),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '${dateLogs.length} ${dateLogs.length == 1 ? 'activity' : 'activities'}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isExpanded ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                          color: Colors.grey,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Expanded Activities for this Date — now using shared AuditLogEntryCard
                                if (isExpanded) ...[
                                  const Divider(height: 1),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      children: dateLogs.map((log) => AuditLogEntryCard(
                                        key: ValueKey(log.id),
                                        log: log,
                                        trip: widget.trip,
                                      )).toList(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
