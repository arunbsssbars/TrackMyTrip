import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/trip.dart';
import '../../models/trip_audit_log.dart';
import '../../providers/audit_log_provider.dart';

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

  @override
  void initState() {
    super.initState();
    // Default expand today
    _expandedDates.add(_getDateKey(DateTime.now()));
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

  String _selectedCategory = 'all';

  Color _getActionColor(String actionType) {
    switch (actionType) {
      case 'delete_expense':
      case 'delete_settlement':
      case 'delete_stoppage':
      case 'delete_memory':
        return Colors.red;
      case 'edit_expense':
      case 'edit_settlement':
      case 'edit_stoppage':
        return Colors.amber.shade800;
      case 'create_expense':
      case 'create_settlement':
      case 'create_stoppage':
        return Colors.green;
      case 'add_memory':
        return AppTheme.secondary;
      case 'update_budget':
        return Colors.teal;
      case 'member_joined':
        return Colors.blue;
      case 'depart_stoppage':
        return Colors.indigo;
      default:
        return AppTheme.primary;
    }
  }

  String _getActionLabel(String actionType) {
    switch (actionType) {
      case 'delete_expense':
        return 'Deleted Bill';
      case 'edit_expense':
        return 'Edited Bill';
      case 'create_expense':
        return 'Added Bill';
      case 'delete_settlement':
        return 'Deleted Payment';
      case 'edit_settlement':
        return 'Edited Payment';
      case 'create_settlement':
        return 'Recorded Payment';
      case 'create_stoppage':
        return 'Added Stoppage';
      case 'edit_stoppage':
        return 'Updated Stoppage';
      case 'depart_stoppage':
        return 'Departed Stoppage';
      case 'delete_stoppage':
        return 'Deleted Stoppage';
      case 'add_memory':
        return 'Added Photo';
      case 'delete_memory':
        return 'Deleted Photo';
      case 'update_budget':
        return 'Updated Budget';
      case 'member_joined':
        return 'Companion Joined';
      default:
        return 'Activity';
    }
  }

  IconData _getActionIcon(String actionType) {
    switch (actionType) {
      case 'delete_expense':
      case 'delete_settlement':
      case 'delete_stoppage':
      case 'delete_memory':
        return Icons.delete_forever_rounded;
      case 'edit_expense':
      case 'edit_settlement':
      case 'edit_stoppage':
        return Icons.edit_note_rounded;
      case 'create_expense':
      case 'create_settlement':
        return Icons.add_circle_outline_rounded;
      case 'create_stoppage':
        return Icons.add_location_alt_rounded;
      case 'depart_stoppage':
        return Icons.directions_walk_rounded;
      case 'add_memory':
        return Icons.add_photo_alternate_rounded;
      case 'update_budget':
        return Icons.account_balance_wallet_rounded;
      case 'member_joined':
        return Icons.person_add_alt_1_rounded;
      default:
        return Icons.history_rounded;
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

  void _showActivityDetailDialog(BuildContext context, TripAuditLog log) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actionColor = _getActionColor(log.actionType);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: actionColor.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getActionIcon(log.actionType), color: actionColor, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _getActionLabel(log.actionType),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.itemTitle,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                // Performer & Time details
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          const Text('Modified by:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              log.performedByName,
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 16, color: AppTheme.secondary),
                          const SizedBox(width: 8),
                          const Text('Timestamp:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormatter.formatDateTime(log.timestamp),
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 12),

            // Actual Change Details
            if (log.changeDetails != null && log.changeDetails!.isNotEmpty) ...[
              const Text('What Changed:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  log.changeDetails!,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[200] : const Color(0xFF1E293B)),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Remark
            const Text('Remark:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.secondary.withAlpha(40)),
              ),
              child: Text(
                (log.reason != null && log.reason!.isNotEmpty) ? log.reason! : 'No remark provided.',
                style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auditLogs = ref.watch(currentTripAuditLogsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allCount = auditLogs.length;
    final billsCount = auditLogs.where((l) => l.category == 'expense').length;
    final stopsCount = auditLogs.where((l) => l.category == 'stoppage').length;
    final photosCount = auditLogs.where((l) => l.category == 'memory').length;
    final paymentsCount = auditLogs.where((l) => l.category == 'settlement').length;

    final filteredLogs = _selectedCategory == 'all'
        ? auditLogs
        : auditLogs.where((l) => l.category == _selectedCategory).toList();

    // Group audit logs by date key (YYYY-MM-DD)
    final Map<String, List<TripAuditLog>> groupedByDate = {};
    for (final log in filteredLogs) {
      final key = _getDateKey(log.timestamp);
      groupedByDate.putIfAbsent(key, () => []).add(log);
    }

    // Sort dates descending
    final sortedDateKeys = groupedByDate.keys.toList()..sort((a, b) => b.compareTo(a));

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
                      'Trip Trust & Live Audit Trail',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                    ),
                    Text(
                      'Real-time transparent activity & modification remarks',
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
          const SizedBox(height: 10),

          // Category filter pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All ($allCount)'),
                const SizedBox(width: 6),
                _buildFilterChip('expense', 'Bills ($billsCount)'),
                const SizedBox(width: 6),
                _buildFilterChip('stoppage', 'Stops ($stopsCount)'),
                const SizedBox(width: 6),
                _buildFilterChip('memory', 'Photos ($photosCount)'),
                const SizedBox(width: 6),
                _buildFilterChip('settlement', 'Payments ($paymentsCount)'),
              ],
            ),
          ),
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
                          Icon(Icons.shield_outlined, size: 56, color: AppTheme.primary.withAlpha(120)),
                          const SizedBox(height: 14),
                          const Text(
                            'No Activity Recorded',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _selectedCategory == 'all'
                                ? 'No trip activities have been logged yet.\nEvery action (stoppage, bill, photo, payment) is broadcasted live to all companions.'
                                : 'No activity under this category yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[500], fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: sortedDateKeys.length,
                    itemBuilder: (context, dateIndex) {
                      final dateKey = sortedDateKeys[dateIndex];
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

                            // Expanded Activities for this Date
                            if (isExpanded) ...[
                              const Divider(height: 1),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(12),
                                itemCount: dateLogs.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (ctx, logIndex) {
                                  final log = dateLogs[logIndex];
                                  final actionColor = _getActionColor(log.actionType);
                                  final actionLabel = _getActionLabel(log.actionType);
                                  final actionIcon = _getActionIcon(log.actionType);

                                  return InkWell(
                                    onTap: () => _showActivityDetailDialog(context, log),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppTheme.surfaceDark : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: actionColor.withAlpha(20),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(actionIcon, size: 12, color: actionColor),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      actionLabel,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: actionColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                DateFormatter.formatTimeOnly(log.timestamp),
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            log.itemTitle,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          if (log.changeDetails != null && log.changeDetails!.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              log.changeDetails!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Icon(Icons.notes_rounded, size: 13, color: AppTheme.secondary),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: RichText(
                                                    text: TextSpan(
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                                                      ),
                                                      children: [
                                                        const TextSpan(
                                                          text: 'Remark: ',
                                                          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondary),
                                                        ),
                                                        TextSpan(
                                                          text: (log.reason != null && log.reason!.isNotEmpty)
                                                              ? log.reason!
                                                              : 'No remark provided.',
                                                          style: const TextStyle(fontStyle: FontStyle.italic),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 9,
                                                    backgroundColor: AppTheme.primary.withAlpha(30),
                                                    child: Text(
                                                      log.performedByName.isNotEmpty ? log.performedByName[0].toUpperCase() : '?',
                                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    log.performedByName,
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                              const Text(
                                                'View Details ➔',
                                                style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
