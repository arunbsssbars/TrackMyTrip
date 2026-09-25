// A premium hero card for the Current Trip screen, extracted from CurrentTripTab.
// Implements glass‑morphism style, dark‑mode aware gradient and micro‑animations.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/trip.dart';

class CurrentTripHeroCard extends StatelessWidget {
  final Trip trip;
  final bool isDark;
  final double totalSpent;
  final int expenseCount;
  final VoidCallback onTapLedger;

  const CurrentTripHeroCard({
    super.key,
    required this.trip,
    required this.isDark,
    this.totalSpent = 0.0,
    this.expenseCount = 0,
    required this.onTapLedger,
  });

  bool get isEnded => trip.isCompleted || trip.status == 'completed';

  @override
  Widget build(BuildContext context) {
    final hasBudget = trip.budget != null && trip.budget! > 0;
    final budgetPercent = hasBudget ? (totalSpent / trip.budget!).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = hasBudget && totalSpent > trip.budget!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [AppTheme.primary, const Color(0xFF0891B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.white.withAlpha(50),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withAlpha(isDark ? 40 : 75),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Journey Type Pill & Share Code Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _journeyTypePill(context),
              if (trip.shareCode != null && trip.shareCode!.isNotEmpty) _shareCodeChip(context),
            ],
          ),
          const SizedBox(height: 12),
          // Title & Sub‑metadata
          Text(
            trip.title,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.event_note_rounded, size: 13, color: Colors.white70),
              const SizedBox(width: 5),
              Text(
                DateFormatter.formatTripDateRange(trip.startDate, trip.endDate),
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              if (trip.members.isNotEmpty) ...[
                const Text('  •  ', style: TextStyle(color: Colors.white38)),
                const Icon(Icons.people_alt_rounded, size: 13, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  '${trip.members.length} Traveler${trip.members.length == 1 ? "" : "s"}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          // Integrated Financial Glance Block
          _financialGlance(context, hasBudget, totalSpent, budgetPercent, isOverBudget, isEnded),
        ],
      ),
    );
  }

  Widget _journeyTypePill(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withAlpha(50), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    trip.isSolo
                        ? Icons.person_rounded
                        : (trip.isFamily ? Icons.family_restroom_rounded : Icons.groups_rounded),
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      trip.isSolo
                          ? 'SOLO JOURNEY'
                          : (trip.isFamily ? 'FAMILY CONVOY' : 'GROUP EXPEDITION'),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isEnded) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withAlpha(50),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white38, width: 0.8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_rounded, size: 10, color: Colors.white),
                  SizedBox(width: 3),
                  Text('CONCLUDED', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _shareCodeChip(BuildContext context) {
    return InkWell(
      onTap: () => _copyShareCode(context, trip.shareCode!),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withAlpha(50), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.copy_rounded, size: 11, color: Colors.white),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                trip.shareCode!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to copy share code – uses ScaffoldMessenger from the context.
  void _copyShareCode(BuildContext ctx, String code) {
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text('Trip share code $code copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _financialGlance(BuildContext context, bool hasBudget, double totalSpent, double budgetPercent, bool isOverBudget, bool isEnded) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(isDark ? 55 : 30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(35)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTapLedger,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.account_balance_wallet_rounded, size: 14, color: Colors.white70),
                        SizedBox(width: 5),
                        Text('TOTAL EXPENDITURE', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Ledger & Splits', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                          SizedBox(width: 3),
                          Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Colors.white),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  CurrencyFormatter.format(totalSpent, currency: trip.defaultCurrency),
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
                if (hasBudget) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: budgetPercent,
                      minHeight: 5,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(isOverBudget ? const Color(0xFFEF4444) : const Color(0xFF34D399)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${(budgetPercent * 100).toInt()}% of ${CurrencyFormatter.format(trip.budget!, currency: trip.defaultCurrency)}', style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600)),
                      Text(isOverBudget ? 'Over Budget!' : 'Left: ${CurrencyFormatter.format(trip.budget! - totalSpent, currency: trip.defaultCurrency)}', style: TextStyle(color: isOverBudget ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7), fontSize: 10.5, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 5),
                  Text('$expenseCount expense ${expenseCount == 1 ? "entry" : "entries"} logged • Tap to view ledger & splits', style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
