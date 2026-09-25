import '../common/trip_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/live_location_tracker_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/trip.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';
import '../common/sos_badge_icon.dart';
import '../home/create_trip_sheet.dart';
import '../main_scaffold.dart';
import '../notifications/notification_center_sheet.dart';
import '../trip_detail/trip_detail_screen.dart';
import '../../core/utils/page_transitions.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/services/pdf_export_service.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settlement_provider.dart';
import '../stats/trip_analytics_screen.dart';
import '../stoppage/add_stoppage_dialog.dart';
import '../expense/add_expense_screen.dart';

class CurrentTripTab extends ConsumerStatefulWidget {
  const CurrentTripTab({super.key});

  @override
  ConsumerState<CurrentTripTab> createState() => _CurrentTripTabState();
}

class _CurrentTripTabState extends ConsumerState<CurrentTripTab> {
  void _navigateToTripDetail(Trip trip, {int initialTabIndex = 0}) {
    ref.read(selectedTripIdProvider.notifier).state = trip.id;
    AppNavigator.push(
      context,
      TripDetailScreen(
        tripId: trip.id,
        initialTabIndex: initialTabIndex,
      ),
    );
  }

  void _exportPdf(Trip trip) async {
    final stoppages = ref.read(allStoppagesProvider).where((s) => s.tripId == trip.id).toList();
    final expenses = ref.read(allExpensesProvider).where((e) => e.tripId == trip.id).toList();
    final netBalances = ref.read(tripNetBalancesProvider);
    final transfers = ref.read(simplifiedTransfersProvider);

    await PdfExportService.exportTripSummaryPdf(
      trip: trip,
      stoppages: stoppages,
      expenses: expenses,
      netBalances: netBalances,
      transfers: transfers,
    );
  }

  void _copyShareCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Trip share code $code copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openJourneySwitcher(BuildContext context, List<Trip> trips, Trip? currentTrip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.72),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(80),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.explore_rounded, color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Switch Active Journey',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                        ),
                      ],
                    ),
                    Text(
                      '${trips.length} Total',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: trips.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, index) {
                    final t = trips[index];
                    final isSelected = t.id == currentTrip?.id;
                    return InkWell(
                      onTap: () {
                        ref.read(selectedTripIdProvider.notifier).state = t.id;
                        Navigator.pop(ctx);
                        HapticFeedback.selectionClick();
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary.withAlpha(isDark ? 35 : 20)
                              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                            width: isSelected ? 1.6 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primary
                                    : (isDark ? Colors.white12 : Colors.grey[200]),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isSelected ? Icons.check_rounded : Icons.navigation_rounded,
                                color: isSelected ? Colors.white : Colors.grey,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          t.title,
                                          style: TextStyle(
                                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          margin: const EdgeInsets.only(left: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'ACTIVE',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    DateFormatter.formatTripDateRange(t.startDate, t.endDate),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ref.read(activeMainTabProvider.notifier).state = 0;
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.dashboard_rounded, size: 16),
                        label: const Text('All Journeys', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const CreateTripSheet(),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('New Journey', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrimaryActionPill({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? AppTheme.surfaceDark : Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: isDark ? 0 : 2,
      shadowColor: Colors.black.withAlpha(isDark ? 25 : 12),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                  color: isDark ? Colors.white : AppTheme.textMainLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trips = ref.watch(tripListProvider);
    final currentTrip = ref.watch(currentTripProvider);
    final trackingState = ref.watch(liveLocationTrackerProvider);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        titleSpacing: 16,
        title: trips.isEmpty || currentTrip == null
            ? const Text(
                'Current Journey',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              )
            : InkWell(
                onTap: () => _openJourneySwitcher(context, trips, currentTrip),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primary.withAlpha(isDark ? 80 : 120),
                      width: 1.1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.explore_rounded, color: AppTheme.primary, size: 17),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          currentTrip.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: isDark ? Colors.white : AppTheme.textMainLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: (currentTrip.isSolo ? const Color(0xFF2563EB) : AppTheme.primary).withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          currentTrip.isEnded
                              ? 'Ended'
                              : (currentTrip.isSolo ? 'Solo' : (currentTrip.isFamily ? 'Family' : 'Group')),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: currentTrip.isEnded
                                ? Colors.grey
                                : (currentTrip.isSolo ? const Color(0xFF2563EB) : AppTheme.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.primary, size: 20),
                    ],
                  ),
                ),
              ),
        actions: [
          if (trackingState.isTracking)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withAlpha(isDark ? 50 : 25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withAlpha(120), width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Color(0xFF10B981), size: 6),
                    SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: SosBadgeIcon(
              size: 32,
              tooltip: 'Emergency SOS & Safety Alerts',
              onTap: () => NotificationCenterSheet.show(context),
            ),
          ),
          if (currentTrip != null)
            TripMenuButton(
              trip: currentTrip,
              onTripDeleted: () {
                ref.read(tripListProvider.notifier).reload();
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: currentTrip == null
          ? _buildEmptyState(context, isDark)
          : _buildActiveTripContent(context, currentTrip, trackingState, isDark),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(isDark ? 30 : 20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.navigation_rounded,
                size: 54,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Active Journey Selected',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Select an ongoing journey from your Journeys tab or create a new trip to track convoy telemetry, upcoming stoppages, and route navigation.',
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref.read(activeMainTabProvider.notifier).state = 0;
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.explore_rounded, size: 16),
                    label: const Text('View Journeys', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const CreateTripSheet(),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Create Trip', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTripContent(
    BuildContext context,
    Trip trip,
    LiveTrackingState trackingState,
    bool isDark,
  ) {
    final stoppages = ref.watch(currentTripStoppagesProvider);
    final allExpenses = ref.watch(allExpensesProvider);
    final tripExpenses = allExpenses.where((e) => e.tripId == trip.id).toList();
    final totalSpent = tripExpenses.fold<double>(0.0, (sum, e) => sum + e.totalAmount);
    final activeStoppages = stoppages.where((s) => s.isOngoing).toList();
    final nextStoppage = activeStoppages.isNotEmpty
        ? activeStoppages.first
        : (stoppages.isNotEmpty ? stoppages.last : null);
    final hasBudget = trip.budget != null && trip.budget! > 0;
    final budgetPercent = hasBudget ? (totalSpent / trip.budget!).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = hasBudget && totalSpent > trip.budget!;
    final isEnded = trip.isCompleted || trip.status == 'completed';

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(tripListProvider.notifier).reload();
        ref.read(allStoppagesProvider.notifier).reload();
        ref.read(allExpensesProvider.notifier).reload();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Executive Journey Cockpit Hero Card
            Container(
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
                      Expanded(
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
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
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
                                    Text(
                                      'CONCLUDED',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (trip.shareCode != null && trip.shareCode!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _copyShareCode(trip.shareCode!),
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
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Journey Title
                  Text(
                    trip.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 5),

                  // Sub-metadata: Date range and Traveler count
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
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(isDark ? 55 : 30),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withAlpha(35)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _navigateToTripDetail(trip, initialTabIndex: 3);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.account_balance_wallet_rounded, size: 14, color: Colors.white70),
                                      const SizedBox(width: 5),
                                      Text(
                                        'TOTAL EXPENDITURE',
                                        style: TextStyle(
                                          color: Colors.white.withAlpha(210),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(40),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Ledger & Splits',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (hasBudget) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: budgetPercent,
                                    minHeight: 5,
                                    backgroundColor: Colors.white24,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isOverBudget ? const Color(0xFFEF4444) : const Color(0xFF34D399),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${(budgetPercent * 100).toInt()}% of ${CurrencyFormatter.format(trip.budget!, currency: trip.defaultCurrency)}',
                                      style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600),
                                    ),
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
                                const SizedBox(height: 5),
                                Text(
                                  '${tripExpenses.length} expense entry${tripExpenses.length == 1 ? "" : "ies"} logged • Tap to view ledger & splits',
                                  style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. High-Frequency Action Launchpad (4 Thumb-Friendly Pills)
            Row(
              children: [
                Expanded(
                  child: _buildPrimaryActionPill(
                    icon: Icons.add_location_alt_rounded,
                    label: '+ Stop',
                    color: const Color(0xFF0284C7),
                    isDark: isDark,
                    onTap: () {
                      if (isEnded) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('This trip has ended. Reopen the trip from options menu to add stoppages.'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }
                      AddStoppageDialog.show(context, tripId: trip.id);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPrimaryActionPill(
                    icon: Icons.receipt_long_rounded,
                    label: '+ Bill',
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddExpenseScreen(tripId: trip.id),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPrimaryActionPill(
                    icon: Icons.radar_rounded,
                    label: 'Radar',
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                    onTap: () => _navigateToTripDetail(trip, initialTabIndex: 1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPrimaryActionPill(
                    icon: Icons.people_alt_rounded,
                    label: 'Members',
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                    onTap: () => _navigateToTripDetail(trip, initialTabIndex: 2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. Connected Convoy Telemetry Instrument Cluster
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 25 : 8),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.speed_rounded, size: 18, color: AppTheme.primary),
                          SizedBox(width: 6),
                          Text(
                            'LIVE CONVOY TELEMETRY',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: trackingState.isTracking
                              ? const Color(0xFF10B981).withAlpha(20)
                              : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: trackingState.isTracking
                                ? const Color(0xFF10B981).withAlpha(100)
                                : Colors.transparent,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 6,
                              color: trackingState.isTracking ? const Color(0xFF10B981) : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              trackingState.isTracking ? 'GPS Active' : 'GPS Standby',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: trackingState.isTracking ? const Color(0xFF10B981) : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Gauges
                  Row(
                    children: [
                      // Speed gauge
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withAlpha(6) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                trackingState.currentSpeedKmh.toStringAsFixed(0),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: trackingState.currentSpeedKmh > 5 ? const Color(0xFF10B981) : AppTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'SPEED (KM/H)',
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Distance gauge
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withAlpha(6) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                trackingState.totalDistanceKm.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'DISTANCE (KM)',
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tracking Toggle Controller
                  SizedBox(
                    width: double.infinity,
                    child: trackingState.isTracking
                        ? OutlinedButton.icon(
                            onPressed: () {
                              ref.read(liveLocationTrackerProvider.notifier).stopTracking();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red, width: 1.2),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.stop_rounded, size: 18),
                            label: const Text('Pause Live Convoy Tracking', style: TextStyle(fontWeight: FontWeight.bold)),
                          )
                        : FilledButton.icon(
                            onPressed: () {
                              ref.read(liveLocationTrackerProvider.notifier).startTracking(trip.id);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 20),
                            label: const Text('Start Live Convoy Tracking', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Next Destination / Upcoming Waypoint Card
            if (nextStoppage != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.near_me_rounded, size: 16, color: Color(0xFF0F766E)),
                            SizedBox(width: 6),
                            Text(
                              'NEXT UPCOMING STOPPAGE',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: nextStoppage.isOngoing
                                ? Colors.amber.withAlpha(25)
                                : const Color(0xFF10B981).withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            nextStoppage.isOngoing ? 'En Route' : 'Planned',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: nextStoppage.isOngoing ? Colors.amber[800] : const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            AppConstants.getStoppageIcon(nextStoppage.category),
                            color: AppTheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nextStoppage.name,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (nextStoppage.address != null && nextStoppage.address!.isNotEmpty)
                                Text(
                                  nextStoppage.address!,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _navigateToTripDetail(trip, initialTabIndex: 1),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.map_rounded, size: 16),
                        label: const Text('View Stoppage on Map', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 5. Journey Modules Hub (4 Core Pillars in 2x2 Grid)
            const Row(
              children: [
                Icon(Icons.grid_view_rounded, size: 16, color: AppTheme.primary),
                SizedBox(width: 6),
                Text(
                  'JOURNEY MODULES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.timeline_rounded,
                    title: 'Timeline',
                    subtitle: '${stoppages.length} stops',
                    color: AppTheme.primary,
                    isDark: isDark,
                    onTap: () => _navigateToTripDetail(trip, initialTabIndex: 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.map_rounded,
                    title: 'Live Route',
                    subtitle: 'Radar & Nav',
                    color: const Color(0xFF0F766E),
                    isDark: isDark,
                    onTap: () => _navigateToTripDetail(trip, initialTabIndex: 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Bills & Splits',
                    subtitle: '${tripExpenses.length} bills recorded',
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                    onTap: () => _navigateToTripDetail(trip, initialTabIndex: 3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.photo_library_rounded,
                    title: 'Memories',
                    subtitle: 'Photos & logs',
                    color: const Color(0xFFEC4899),
                    isDark: isDark,
                    onTap: () => _navigateToTripDetail(trip, initialTabIndex: trip.isSolo ? 4 : 5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 6. Executive Insights & Actions (Analytics & PDF Report)
            Row(
              children: [
                Expanded(
                  child: _buildInsightsPill(
                    icon: Icons.insights_rounded,
                    label: 'Trip Analytics',
                    color: const Color(0xFF06B6D4),
                    isDark: isDark,
                    onTap: () {
                      AppNavigator.push(
                        context,
                        TripAnalyticsScreen(tripId: trip.id),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInsightsPill(
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'Export PDF',
                    color: const Color(0xFF6366F1),
                    isDark: isDark,
                    onTap: () => _exportPdf(trip),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsPill({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? AppTheme.surfaceDark : Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: isDark ? 0 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? AppTheme.surfaceDark : Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: isDark ? 0 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withAlpha(22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
