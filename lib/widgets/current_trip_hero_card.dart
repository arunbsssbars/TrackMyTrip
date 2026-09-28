import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/live_location_tracker_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/trip.dart';
import '../screens/common/pulsing_live_beacon.dart';

class CurrentTripHeroCard extends StatelessWidget {
  final Trip trip;
  final bool isDark;
  final double totalSpent;
  final int expenseCount;
  final LiveTrackingState? trackingState;
  final VoidCallback? onToggleTracking;
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
    this.trackingState,
    this.onToggleTracking,
    required this.onTapLedger,
    this.onTapCard,
    this.onTapAuditTrail,
    this.onTapPieChart,
  });

  bool get isEnded =>
      trip.isCompleted ||
      trip.status == 'completed' ||
      trip.status == 'concluded' ||
      trip.status == 'ended';

  @override
  Widget build(BuildContext context) {
    Color modeColor;
    IconData modeIcon;

    if (trip.isSolo) {
      modeColor = const Color(0xFF60A5FA); // Light Blue
      modeIcon = Icons.backpack_rounded;
    } else if (trip.isFamily) {
      modeColor = const Color(0xFFFBBF24); // Amber
      modeIcon = Icons.family_restroom_rounded;
    } else {
      modeColor = const Color(0xFF2DD4BF); // Teal
      modeIcon = Icons.groups_rounded;
    }

    final isTracking = trackingState?.isTracking ?? false;
    final currentSpeed = trackingState?.currentSpeedKmh ?? 0.0;
    final totalDistance = trackingState?.totalDistanceKm ?? 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFF0D6E63), const Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEnded
              ? (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706))
              : Colors.white.withAlpha(isDark ? 30 : 45),
          width: isEnded ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isEnded
                ? (isDark
                    ? const Color(0xFFF59E0B).withAlpha(45)
                    : const Color(0xFFD97706).withAlpha(50))
                : (const Color(0xFF0D6E63).withAlpha(isDark ? 35 : 65)),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Mode Icon + Title + Status Beacon & Room Code
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Mode Icon Badge
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(28),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(modeIcon, size: 16, color: modeColor),
              ),
              const SizedBox(width: 8),

              // Title (Tappable)
              Expanded(
                child: InkWell(
                  onTap: onTapCard ?? onTapLedger,
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          trip.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: Colors.white.withAlpha(180),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 6),
              // Status Indicator
              _statusIndicator(),

              // Share / Room Code Chip
              if (trip.shareCode != null && trip.shareCode!.isNotEmpty) ...[
                const SizedBox(width: 6),
                _shareCodeChip(context),
              ],
            ],
          ),

          const SizedBox(height: 14),

          // 2. Telemetry Gauges (Paired Frosted Capsules - No vertical divider sticks)
          Row(
            children: [
              // Speed Metric Capsule
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isTracking && currentSpeed > 3
                        ? const Color(0xFF10B981).withAlpha(35)
                        : Colors.white.withAlpha(14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isTracking && currentSpeed > 3
                          ? const Color(0xFF34D399).withAlpha(80)
                          : Colors.white.withAlpha(22),
                      width: 0.9,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: isTracking && currentSpeed > 3
                              ? const Color(0xFF10B981).withAlpha(50)
                              : Colors.white.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.speed_rounded,
                          size: 16,
                          color: isTracking && currentSpeed > 3
                              ? const Color(0xFF34D399)
                              : Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentSpeed.toStringAsFixed(0),
                              style: TextStyle(
                                color: isTracking && currentSpeed > 3
                                    ? const Color(0xFF34D399)
                                    : Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const Text(
                              'KM/H SPEED',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Distance Metric Capsule
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withAlpha(22),
                      width: 0.9,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.route_rounded,
                          size: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              totalDistance.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const Text(
                              'KM DISTANCE',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 3. Interactive Action: Full-Width Tactical Live Telemetry Control
          Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                color: isEnded
                    ? Colors.white.withAlpha(12)
                    : isTracking
                        ? const Color(0xFFEF4444).withAlpha(isDark ? 45 : 40)
                        : Colors.white.withAlpha(isDark ? 22 : 32),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isEnded
                      ? Colors.white.withAlpha(22)
                      : isTracking
                          ? const Color(0xFFEF4444).withAlpha(90)
                          : Colors.white.withAlpha(isDark ? 40 : 60),
                  width: 1.0,
                ),
              ),
              child: InkWell(
                onTap: (!isEnded && onToggleTracking != null)
                    ? () {
                        HapticFeedback.lightImpact();
                        onToggleTracking!();
                      }
                    : null,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9.5, horizontal: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isEnded
                            ? Icons.check_circle_outline_rounded
                            : isTracking
                                ? Icons.pause_circle_rounded
                                : Icons.play_circle_fill_rounded,
                        size: 17,
                        color: isEnded
                            ? Colors.white70
                            : isTracking
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFF34D399),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEnded
                            ? 'Trip Concluded'
                            : isTracking
                                ? 'Pause Live GPS Telemetry'
                                : 'Start Live Convoy Telemetry',
                        style: TextStyle(
                          color: isEnded ? Colors.white70 : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Hairline Divider above Footer
          Divider(color: Colors.white.withAlpha(20), height: 1, thickness: 0.8),
          const SizedBox(height: 10),

          // 4. Compact Financial Summary Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Total Spent (Tappable to open analytics)
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTapLedger();
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Total Spent: ',
                        style: TextStyle(
                          color: Colors.white.withAlpha(190),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(totalSpent,
                            currency: trip.defaultCurrency),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bills Count Pill
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTapLedger();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.white.withAlpha(35), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_rounded,
                          size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '$expenseCount bill${expenseCount == 1 ? "" : "s"}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded,
                          size: 13, color: Colors.white70),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusIndicator() {
    if (isEnded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFD97706).withAlpha(60),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Colors.white38, width: 0.8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_rounded, size: 9.5, color: Colors.white),
            SizedBox(width: 3),
            Text(
              'CONCLUDED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      );
    }
    return const PulsingLiveBeacon(
      label: 'LIVE',
      color: Color(0xFF34D399),
      dotSize: 7.0,
      labelStyle: TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _shareCodeChip(BuildContext context) {
    return InkWell(
      onTap: () => _copyShareCode(context, trip.shareCode!),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withAlpha(45), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.copy_rounded, size: 10, color: Colors.white),
            const SizedBox(width: 3.5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                trip.shareCode!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
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
}
