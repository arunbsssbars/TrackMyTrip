import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/trip.dart';
import '../screens/common/pulsing_live_beacon.dart';

class CurrentTripHeroCard extends StatelessWidget {
  final Trip trip;
  final bool isDark;
  final double totalSpent;
  final int expenseCount;
  final Map<String, double>? categoryBreakdown;
  final VoidCallback onTapLedger;
  final VoidCallback? onTapCard;
  final VoidCallback? onTapAuditTrail;
  final VoidCallback? onTapPieChart;

  const CurrentTripHeroCard({
    super.key,
    required this.trip,
    required this.isDark,
    this.totalSpent = 0.0,
    this.expenseCount = 0,
    this.categoryBreakdown,
    required this.onTapLedger,
    this.onTapCard,
    this.onTapAuditTrail,
    this.onTapPieChart,
  });

  bool get isEnded => trip.isCompleted || trip.status == 'completed' || trip.status == 'concluded' || trip.status == 'ended';

  @override
  Widget build(BuildContext context) {
    final hasBudget = trip.budget != null && trip.budget! > 0;
    final budgetPercent = hasBudget ? (totalSpent / trip.budget!).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = hasBudget && totalSpent > trip.budget!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [AppTheme.primary, const Color(0xFF0891B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEnded
              ? (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706))
              : (isDark ? const Color(0xFF334155) : Colors.white.withAlpha(50)),
          width: isEnded ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isEnded
                ? (isDark ? const Color(0xFFF59E0B).withAlpha(45) : const Color(0xFFD97706).withAlpha(50))
                : (AppTheme.primary.withAlpha(isDark ? 35 : 65)),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Journey Type Pill, Status & Share Code
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: _journeyTypePill(context)),
              if (trip.shareCode != null && trip.shareCode!.isNotEmpty) ...[
                const SizedBox(width: 6),
                _shareCodeChip(context),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Title & Sub-metadata (Tap to view Trip Details)
          InkWell(
            onTap: onTapCard ?? onTapLedger,
            borderRadius: BorderRadius.circular(12),
            splashColor: Colors.white.withAlpha(25),
            highlightColor: Colors.white.withAlpha(15),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          trip.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      const Icon(Icons.event_note_rounded, size: 12, color: Colors.white70),
                      Text(
                        DateFormatter.formatTripDateRange(trip.startDate, trip.endDate),
                        style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                      if (trip.members.isNotEmpty) ...[
                        const Text('  •  ', style: TextStyle(color: Colors.white38)),
                        const Icon(Icons.people_alt_rounded, size: 12, color: Colors.white70),
                        Text(
                          '${trip.members.length} Traveler${trip.members.length == 1 ? "" : "s"}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Financial Glance & Analytics Link Block
          _financialGlance(context, hasBudget, totalSpent, budgetPercent, isOverBudget, isEnded),
        ],
      ),
    );
  }

  Widget _journeyTypePill(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
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
              const SizedBox(width: 4.5),
              Text(
                trip.isSolo
                    ? 'SOLO'
                    : (trip.isFamily ? 'FAMILY' : 'GROUP'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        if (isEnded)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withAlpha(60),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white38, width: 0.8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flag_rounded, size: 10, color: Colors.white),
                SizedBox(width: 3.5),
                Text('CONCLUDED', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ],
            ),
          )
        else
          const PulsingLiveBeacon(
            label: 'LIVE',
            color: Color(0xFF34D399),
            dotSize: 8.0,
            labelStyle: TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
      ],
    );
  }

  Widget _shareCodeChip(BuildContext context) {
    return InkWell(
      onTap: () => _copyShareCode(context, trip.shareCode!),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 1,
          margin: const EdgeInsets.only(top: 2, bottom: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withAlpha(50),
                Colors.white.withAlpha(20),
                Colors.white.withAlpha(5),
              ],
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTapLedger();
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet_rounded, size: 13, color: Colors.white.withAlpha(200)),
                      const SizedBox(width: 5),
                      Text(
                        'JOURNEY EXPENDITURE',
                        style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'View Analytics & Ledger',
                        style: TextStyle(
                          color: Colors.white.withAlpha(180),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded, size: 14, color: Colors.white70),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        CurrencyFormatter.format(totalSpent, currency: trip.defaultCurrency),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withAlpha(40), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.receipt_long_rounded, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '$expenseCount bill${expenseCount == 1 ? "" : "s"}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (hasBudget) ...[
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: budgetPercent,
                        minHeight: 4,
                        backgroundColor: Colors.white.withAlpha(35),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isOverBudget ? const Color(0xFFF87171) : const Color(0xFF34D399),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '${(budgetPercent * 100).toInt()}% of ${CurrencyFormatter.format(trip.budget!, currency: trip.defaultCurrency)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOverBudget
                              ? 'Over Budget!'
                              : 'Left: ${CurrencyFormatter.format(trip.budget! - totalSpent, currency: trip.defaultCurrency)}',
                          style: TextStyle(
                            color: isOverBudget ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    Text(
                      '$expenseCount ${expenseCount == 1 ? "entry" : "entries"} logged • Tap to view ledger & analytics',
                      style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
