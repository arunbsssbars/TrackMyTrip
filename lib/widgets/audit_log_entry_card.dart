import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../core/theme/app_theme.dart';
import '../core/utils/date_formatter.dart';
import '../models/trip.dart';
import '../models/trip_audit_log.dart';

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
      return const _ActionDescriptor(label: 'Budget Allocated', icon: Icons.account_balance_wallet_rounded, color: Color(0xFF0D9488));
    default:
      return const _ActionDescriptor(label: 'Financial Ledger', icon: Icons.verified_user_rounded, color: AppTheme.primary);
  }
}

/// Unified, self-contained immutable audit log entry card across the entire app.
/// Displays all essential details inline (Action, Time, Title, Performer, Diff, Remark).
/// No popup modal required.
class AuditLogEntryCard extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final desc = _resolveAction(log.actionType);

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
                    onTap: onNavigate != null
                        ? () {
                            HapticFeedback.lightImpact();
                            onNavigate!();
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Action Badge + Timestamp
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _ActionBadge(desc: desc),
                              Text(
                                DateFormatter.formatDateTime(log.timestamp),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),

                          // Row 2: Item Title
                          Text(
                            log.itemTitle,
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
                                const Text(' • ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                              Text(
                                'By ${log.performedByName}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
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
                              Row(
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
                                  Text(
                                    log.performedByName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.shield_rounded, size: 11, color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                                  const SizedBox(width: 3.5),
                                  Text(
                                    'Immutable Record',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
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
          Text(
            desc.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: desc.color,
            ),
          ),
        ],
      ),
    );
  }
}
