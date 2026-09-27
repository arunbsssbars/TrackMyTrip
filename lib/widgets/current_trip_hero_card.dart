// A premium hero card for the Current Trip screen, extracted from CurrentTripTab.
// Implements glass‑morphism style, dark‑mode aware gradient and micro‑animations.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
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

  bool get isEnded => trip.isCompleted || trip.status == 'completed';

  @override
  Widget build(BuildContext context) {
    final hasBudget = trip.budget != null && trip.budget! > 0;
    final budgetPercent = hasBudget ? (totalSpent / trip.budget!).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = hasBudget && totalSpent > trip.budget!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          width: isEnded ? 2.0 : 1.0,
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
          // Top Row: Journey Type Pill, Pulsing Live Beacon & Share Code
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
          const SizedBox(height: 8),
          // Title & Sub‑metadata (Tap to view Trip Details)
          InkWell(
            onTap: onTapCard,
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
                          style: const TextStyle(color: Colors.white, fontSize: 18.5, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onTapCard != null)
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
                  const SizedBox(height: 3),
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
          const SizedBox(height: 8),
          // Integrated Financial Glance Block
          _financialGlance(context, hasBudget, totalSpent, budgetPercent, isOverBudget, isEnded),
          if (categoryBreakdown != null && categoryBreakdown!.isNotEmpty && totalSpent > 0) ...[
            const SizedBox(height: 10),
            _categoryPieChartGlance(context),
          ],
          if (onTapAuditTrail != null) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onTapAuditTrail?.call();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(28),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withAlpha(50), width: 0.9),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Audit Trail & Trust History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ],
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
              Text(
                trip.isSolo
                    ? 'SOLO JOURNEY'
                    : (trip.isFamily ? 'FAMILY CONVOY' : 'GROUP EXPEDITION'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        if (isEnded)
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
                SizedBox(width: 3.5),
                Text('CONCLUDED', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ],
            ),
          )
        else
          const PulsingLiveBeacon(
            label: 'LIVE',
            color: Color(0xFF34D399),
            dotSize: 9.0,
            labelStyle: TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subtle integrated divider eliminating box-in-box look
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
                      Icon(Icons.account_balance_wallet_rounded, size: 13, color: Colors.white.withAlpha(190)),
                      const SizedBox(width: 5),
                      Text(
                        'TOTAL EXPENDITURE',
                        style: TextStyle(
                          color: Colors.white.withAlpha(190),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
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
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Colors.white,
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
                    const SizedBox(height: 4),
                    Text(
                      '$expenseCount expense ${expenseCount == 1 ? "entry" : "entries"} logged • Tap to view ledger & splits',
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
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

  Widget _categoryPieChartGlance(BuildContext context) {
    final sortedCategories = categoryBreakdown!.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTapPieChart?.call();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha(40), width: 0.9),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 10,
                  sections: sortedCategories.map((entry) {
                    return PieChartSectionData(
                      color: _getCategoryColor(entry.key),
                      value: entry.value,
                      title: '',
                      radius: 12,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        'Category Expense Breakdown',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.pie_chart_rounded, size: 12, color: Colors.white70),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    children: sortedCategories.take(3).map((entry) {
                      final pct = (entry.value / totalSpent * 100).toInt();
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getCategoryColor(entry.key),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.key} ($pct%)',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'dining':
        return const Color(0xFFF97316);
      case 'fuel':
      case 'transport':
        return const Color(0xFF3B82F6);
      case 'stay':
      case 'accommodation':
      case 'hotel':
        return const Color(0xFF8B5CF6);
      case 'ticket':
      case 'toll':
      case 'entry':
        return const Color(0xFF10B981);
      case 'shopping':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFFF59E0B);
    }
  }
}
