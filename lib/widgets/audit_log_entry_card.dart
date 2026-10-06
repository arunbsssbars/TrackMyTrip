import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/date_formatter.dart';
import '../models/expense.dart';
import '../models/trip.dart';
import '../models/trip_audit_log.dart';
import '../providers/expense_provider.dart';
import '../providers/trip_provider.dart';
import 'expense_detail_sheet.dart';

/// A semantic action descriptor derived from an [actionType] string.
class _ActionDescriptor {
  final String label;
  final IconData icon;
  final Color color;
  const _ActionDescriptor({
    required this.label,
    required this.icon,
    required this.color,
  });
}

/// Resolves a [TripAuditLog.actionType] into a displayable [_ActionDescriptor].
_ActionDescriptor _resolveAction(String actionType) {
  switch (actionType) {
    case 'delete_expense':
      return const _ActionDescriptor(label: 'Deleted Bill', icon: Icons.delete_forever_rounded, color: Color(0xFFEF4444));
    case 'edit_expense':
      return const _ActionDescriptor(label: 'Edited Bill', icon: Icons.edit_note_rounded, color: Color(0xFFD97706));
    case 'create_expense':
    case 'add_expense':
      return const _ActionDescriptor(label: 'Added Bill', icon: Icons.add_circle_outline_rounded, color: Color(0xFF10B981));
    case 'delete_settlement':
      return const _ActionDescriptor(label: 'Deleted Payment', icon: Icons.delete_forever_rounded, color: Color(0xFFEF4444));
    case 'edit_settlement':
      return const _ActionDescriptor(label: 'Edited Payment', icon: Icons.edit_note_rounded, color: Color(0xFFD97706));
    case 'create_settlement':
    case 'settlement':
      return const _ActionDescriptor(label: 'Recorded Payment', icon: Icons.add_circle_outline_rounded, color: Color(0xFF10B981));
    case 'set_budget':
    case 'update_budget':
    case 'trip_budget_allocated':
      return const _ActionDescriptor(label: 'Budget Set', icon: Icons.account_balance_wallet_rounded, color: Color(0xFF0D9488));
    case 'sos':
    case 'trigger_sos':
    case 'sos_emergency':
    case 'emergency_sos':
      return const _ActionDescriptor(label: 'SOS Sent', icon: Icons.emergency_rounded, color: Color(0xFFEF4444));
    default:
      if (actionType.contains('sos') || actionType.contains('emergency')) {
        return const _ActionDescriptor(label: 'SOS Sent', icon: Icons.emergency_rounded, color: Color(0xFFEF4444));
      }
      return const _ActionDescriptor(label: 'Financial Ledger', icon: Icons.verified_user_rounded, color: AppTheme.primary);
  }
}

/// Unified, self-contained immutable audit log entry card across the entire app.
/// Displays all essential details inline (Action, Time, Title, Performer, Diff, Remark).
/// Tapping on a bill log deep-links directly to ExpenseDetailSheet.
class AuditLogEntryCard extends ConsumerWidget {
  final TripAuditLog log;
  final Trip? trip;
  final VoidCallback? onNavigate;
  final bool showAccentStrip;

  const AuditLogEntryCard({
    super.key,
    required this.log,
    this.trip,
    this.onNavigate,
    this.showAccentStrip = false,
  });

  String _cleanDisplayTitle() {
    var title = log.itemTitle.trim();
    // Strip trailing parenthesized currency amount: e.g. " (INR 5000)" or " (₹5,000)" to prevent duplication
    title = title.replaceAll(RegExp(r'\s*\([₹$€£A-Za-z]+\s*[\d,]+(?:\.\d+)?\)\s*$'), '');
    return title;
  }

  String? _resolveDisplayAmount(Expense? matchedExpense) {
    // Point 3: When amount itself is changed, hide the top-right chip because
    // the diff box already clearly captures "Amount: ₹5,000 ➔ ₹4,500".
    if (log.changeDetails != null && log.changeDetails!.contains('Amount:')) {
      return null;
    }
    if (log.amount != null) {
      return CurrencyFormatter.format(log.amount!, currency: log.currency ?? 'INR');
    }
    if (matchedExpense != null) {
      return CurrencyFormatter.format(matchedExpense.totalAmount, currency: matchedExpense.currency);
    }
    if (log.changeDetails != null && log.changeDetails!.isNotEmpty) {
      final toMatch = RegExp(r'to\s*([₹$€£]|INR|USD|EUR)?\s*([\d,]+(?:\.\d+)?)', caseSensitive: false).firstMatch(log.changeDetails!);
      if (toMatch != null) {
        final sym = toMatch.group(1) ?? '₹';
        final val = toMatch.group(2) ?? '';
        return '$sym$val';
      }
      final anyMatch = RegExp(r'([₹$€£]|INR|USD|EUR)\s*([\d,]+(?:\.\d+)?)').firstMatch(log.changeDetails!);
      if (anyMatch != null) {
        return anyMatch.group(0);
      }
    }
    if (log.itemTitle.isNotEmpty) {
      final titleMatch = RegExp(r'([₹$€£]|INR|USD|EUR)\s*([\d,]+(?:\.\d+)?)').firstMatch(log.itemTitle);
      if (titleMatch != null) {
        return titleMatch.group(0);
      }
    }
    return null;
  }

  void _handleTap(BuildContext context, WidgetRef ref, Expense? matchedExpense) {
    HapticFeedback.lightImpact();
    if (onNavigate != null) {
      onNavigate!();
      return;
    }

    final isDeleted = log.actionType.contains('delete') ||
        log.itemTitle.toLowerCase().startsWith('deleted');

    if (isDeleted) {
      _showDeletedDialog(context);
      return;
    }

    if (matchedExpense != null) {
      final tripList = ref.read(tripListProvider);
      final effectiveTrip = trip ??
          tripList.where((t) => t.id == log.tripId).firstOrNull ??
          ref.read(currentTripProvider);
      if (effectiveTrip != null) {
        ExpenseDetailSheet.show(context, ref, effectiveTrip, matchedExpense);
        return;
      }
    }

    if (log.actionType.contains('expense') || log.actionType.contains('bill')) {
      // Expense was deleted or not found
      _showDeletedDialog(context);
    }
  }

  void _showDeletedDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Item Deleted',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This bill or record ("${_cleanDisplayTitle()}") was deleted by ${log.performedByName}.',
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? Colors.grey[300] : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'All historical diffs and changes remain permanently secured in this immutable Trust History.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Understood', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final desc = _resolveAction(log.actionType);

    final allExpenses = ref.watch(allExpensesProvider);
    final cleanTitle = _cleanDisplayTitle();
    final matchedExpense = (log.targetItemId != null && log.targetItemId!.isNotEmpty)
        ? allExpenses.where((e) => e.id == log.targetItemId).firstOrNull
        : allExpenses.where((e) => e.tripId == log.tripId && e.title.toLowerCase() == cleanTitle.toLowerCase()).firstOrNull;

    final displayAmount = _resolveDisplayAmount(matchedExpense);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: desc.color.withAlpha(isDark ? 12 : 8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Semantic left accent strip
              if (showAccentStrip)
                Container(width: 3.5, color: desc.color),

              // Main content block
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _handleTap(context, ref, matchedExpense),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Action Badge + Amount Chip (if available) + Timestamp
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(child: _ActionBadge(desc: desc)),
                              const SizedBox(width: 6),
                              if (displayAmount != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: desc.color.withAlpha(isDark ? 35 : 20),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: desc.color.withAlpha(isDark ? 80 : 45), width: 0.8),
                                  ),
                                  child: Text(
                                    displayAmount,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: desc.color,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  DateFormatter.formatRelativeOrTime(log.timestamp),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),

                          // Row 2: Item Title
                          Text(
                            cleanTitle,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),

                          // Row 3: Trip Name & Performer Info
                          Row(
                            children: [
                              if (trip != null) ...[
                                Flexible(
                                  child: Text(
                                    trip!.title,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!cleanTitle.toLowerCase().contains(log.performedByName.toLowerCase()))
                                  const Text(' • ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                              if (!cleanTitle.toLowerCase().contains(log.performedByName.toLowerCase()))
                                Flexible(
                                  child: Text(
                                    'By ${log.performedByName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          // Row 4: Change Diff Details (if present)
                          if (log.changeDetails != null && log.changeDetails!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                log.changeDetails!,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],

                          // Row 5: Remark pill (if present)
                          if (log.reason != null && log.reason!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                  width: 0.8,
                                ),
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
                                            text: log.reason!,
                                            style: const TextStyle(fontStyle: FontStyle.italic),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Row 6: Performer Avatar + Immutable Ledger Badge
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 9,
                                      backgroundColor: AppTheme.primary.withAlpha(30),
                                      child: Text(
                                        log.performedByName.isNotEmpty
                                            ? log.performedByName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        log.performedByName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.shield_rounded, size: 11, color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                                    const SizedBox(width: 3.5),
                                    Flexible(
                                      child: Text(
                                        'Immutable Record',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                          letterSpacing: 0.2,
                                        ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small coloured badge pill rendered at the top-left of each card.
class _ActionBadge extends StatelessWidget {
  final _ActionDescriptor desc;
  const _ActionBadge({required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: desc.color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(desc.icon, size: 12, color: desc.color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              desc.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: desc.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
