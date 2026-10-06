import '../common/trip_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/live_location_tracker_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../widgets/current_trip_hero_card.dart';
import '../../widgets/app_floating_button.dart';
import '../../models/trip.dart';
import '../../models/stoppage.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';
import '../common/sos_badge_icon.dart';
import '../common/pulsing_live_beacon.dart';
import '../home/create_trip_sheet.dart';
import '../main_scaffold.dart';
import '../notifications/notification_center_sheet.dart';
import '../trip_detail/trip_detail_screen.dart';
import '../trip_detail/audit_log_sheet.dart';
import '../../core/utils/page_transitions.dart';
import '../../core/services/pdf_export_service.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settlement_provider.dart';
import '../stats/trip_analytics_screen.dart';
import '../../core/utils/trip_guard_helper.dart';
import '../../models/trip_audit_log.dart';
import '../../providers/audit_log_provider.dart';
import '../../widgets/quick_bill_action_sheet.dart';

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

  /// Conclude trip: stops live location broadcasts (closing room), optionally captures final stoppage, updates state and redirects to Review screen (Items 3, 8, 17, 18)
  Future<void> _confirmConcludeTrip(BuildContext context, Trip trip) async {
    bool captureFinalLocation = true;

    final shouldConclude = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.flag_rounded, color: Color(0xFFD97706), size: 26),
              SizedBox(width: 8),
              Text('Conclude Journey?', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Are you sure you want to conclude "${trip.title}"?\n\n'
                  '• Live convoy tracking room will be closed.\n'
                  '• Journey will be marked concluded.\n'
                  '• You will be redirected to the Review & Analytics screen.',
                  textAlign: TextAlign.justify,
                  style: const TextStyle(fontSize: 13, height: 1.45),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () {
                    setDialogState(() {
                      captureFinalLocation = !captureFinalLocation;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: captureFinalLocation,
                          onChanged: (v) {
                            setDialogState(() {
                              captureFinalLocation = v ?? true;
                            });
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Capture current GPS position as final destination stop',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text(
                'Conclude Journey',
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );

    if (shouldConclude != true || !context.mounted) return;

    // 1. Capture final stoppage if requested (Item 8)
    if (captureFinalLocation) {
      try {
        final trackingState = ref.read(liveLocationTrackerProvider);
        double? lat = trackingState.currentPosition?.latitude;
        double? lng = trackingState.currentPosition?.longitude;
        if (lat == null || lng == null) {
          try {
            final pos = await Geolocator.getCurrentPosition();
            lat = pos.latitude;
            lng = pos.longitude;
          } catch (_) {}
        }
        if (lat != null && lng != null) {
          final finalStop = Stoppage(
            id: 'stop_${const Uuid().v4().substring(0, 8)}',
            tripId: trip.id,
            name: 'Final Destination (${trip.title})',
            category: 'Destination',
            latitude: lat,
            longitude: lng,
            arrivedAt: DateTime.now(),
            departedAt: DateTime.now(),
            createdBy: UserService.getCurrentUser().id,
          );
          await ref.read(allStoppagesProvider.notifier).addStoppage(finalStop, broadcast: false);
        }
      } catch (_) {}
    }

    // 2. Stop live tracking (Item 3: Close room)
    ref.read(liveLocationTrackerProvider.notifier).stopTracking();

    // 3. Mark completed
    final updatedTrip = trip.copyWith(
      isCompleted: true,
      status: 'completed',
      endDate: DateTime.now(),
    );
    await ref.read(tripListProvider.notifier).updateTrip(updatedTrip);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🏁 Journey concluded! Room closed and saved.'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // 4. Redirect to Review Screen (Item 17)
    AppNavigator.push(
      context,
      TripAnalyticsScreen(tripId: trip.id),
    );
  }

  /// Reopen concluded journey: re-enables edits, live tracking, and notifies companions (Item 7 & 18)
  Future<void> _confirmReopenTrip(BuildContext context, Trip trip) async {
    final shouldReopen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.replay_rounded, color: AppTheme.primary, size: 26),
            SizedBox(width: 8),
            Text('Reopen Journey?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Do you want to reopen "${trip.title}"?\n\n'
          '• Real-time synchronization will resume.\n'
          '• Members can add bills, stops, and share live location.\n'
          '• Companions will receive a reopening notification.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            icon: const Icon(Icons.lock_open_rounded, size: 18),
            label: const Text('Reopen Journey'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (shouldReopen != true || !context.mounted) return;

    await ref.read(tripListProvider.notifier).reopenTrip(trip.id);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔓 Journey reopened! Edits and tracking re-enabled.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showTripReviewDialog(BuildContext context, Trip trip) {
    double currentRating = trip.rating ?? 5.0;
    final reviewController = TextEditingController(text: trip.experienceReview ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.star_rate_rounded, color: Color(0xFFF59E0B), size: 22),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Trip Experience Review',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rate your experience on "${trip.title}"',
                    style: TextStyle(fontSize: 12.5, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (index) {
                        final starValue = index + 1.0;
                        final isFilled = currentRating >= starValue;
                        return InkResponse(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setDialogState(() {
                              currentRating = starValue;
                            });
                          },
                          radius: 20,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Icon(
                              isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                              color: const Color(0xFFF59E0B),
                              size: 32,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  Center(
                    child: Text(
                      '${currentRating.toStringAsFixed(1)} of 5.0 Stars',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFF59E0B)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reviewController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Experience Feedback / Notes',
                      hintText: 'Share highlights, challenges, or travel notes...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Save Review'),
                onPressed: () async {
                  final text = reviewController.text.trim();
                  final updatedTrip = trip.copyWith(
                    rating: currentRating,
                    experienceReview: text.isNotEmpty ? text : null,
                  );
                  await ref.read(tripListProvider.notifier).updateTrip(updatedTrip);

                  final currentUser = UserService.getCurrentUser();
                  ref.read(allAuditLogsProvider.notifier).logAction(TripAuditLog(
                    id: 'rev_${const Uuid().v4().substring(0, 8)}',
                    tripId: trip.id,
                    actionType: 'trip_review',
                    itemTitle: 'Trip Rated ${currentRating.toStringAsFixed(1)}★',
                    performedByMemberId: currentUser.id,
                    performedByName: currentUser.displayName,
                    timestamp: DateTime.now(),
                    changeDetails: text.isNotEmpty ? text : null,
                  ));

                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✓ Experience review saved (${currentRating.toStringAsFixed(1)}★)'),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }



  Widget _buildSwitcherFilterChip(
    String label,
    String key,
    String selectedKey,
    bool isDark,
    ValueChanged<String> onSelect,
  ) {
    final isSelected = key == selectedKey;
    return InkWell(
      onTap: () => onSelect(key),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primary : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  void _openJourneySwitcher(BuildContext context, List<Trip> trips, Trip? currentTrip) {
    String searchQuery = '';
    String selectedFilter = 'all'; // 'all', 'active', 'concluded'
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final activeTrips = trips.where((t) => !t.isCompleted && t.status != 'completed').toList();
            final concludedTrips = trips.where((t) => t.isCompleted || t.status == 'completed').toList();

            final filtered = trips.where((t) {
              if (selectedFilter == 'active' && (t.isCompleted || t.status == 'completed')) {
                return false;
              }
              if (selectedFilter == 'concluded' && (!t.isCompleted && t.status != 'completed')) {
                return false;
              }
              if (searchQuery.isNotEmpty) {
                final q = searchQuery.toLowerCase();
                return t.title.toLowerCase().contains(q) ||
                    (t.description != null && t.description!.toLowerCase().contains(q));
              }
              return true;
            }).toList();

            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.88),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 90 : 35),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  // Drag Handle
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header with Title, Subtitle & Close Action
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Select Live Journey',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: -0.2),
                                ),
                                Text(
                                  'Switch active convoy telemetry & controls',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(ctx),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded, size: 18, color: isDark ? Colors.grey[300] : const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Search Box with instant Clear ('x') button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: searchController,
                        onChanged: (val) {
                          setModalState(() {
                            searchQuery = val.trim();
                          });
                        },
                        style: const TextStyle(fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'Search journey by title or note...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                          ),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.primary),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                  tooltip: 'Clear Search',
                                  onPressed: () {
                                    searchController.clear();
                                    setModalState(() {
                                      searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Segment Filter Chips
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        _buildSwitcherFilterChip('All (${trips.length})', 'all', selectedFilter, isDark, (f) {
                          setModalState(() => selectedFilter = f);
                        }),
                        const SizedBox(width: 8),
                        _buildSwitcherFilterChip('🟢 Live (${activeTrips.length})', 'active', selectedFilter, isDark, (f) {
                          setModalState(() => selectedFilter = f);
                        }),
                        const SizedBox(width: 8),
                        _buildSwitcherFilterChip('🏁 Concluded (${concludedTrips.length})', 'concluded', selectedFilter, isDark, (f) {
                          setModalState(() => selectedFilter = f);
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Divider(height: 1, color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),

                  // Trip Cards in Modal
                  Flexible(
                    child: filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withAlpha(20),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.search_off_rounded, size: 36, color: AppTheme.primary),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  searchQuery.isNotEmpty ? 'No journeys matching "$searchQuery"' : 'No journeys found in this filter',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  searchQuery.isNotEmpty ? 'Check for spelling mistakes or clear your search query.' : 'Try switching categories to view other expeditions.',
                                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                                  textAlign: TextAlign.center,
                                ),
                                if (searchQuery.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: () {
                                      searchController.clear();
                                      setModalState(() => searchQuery = '');
                                    },
                                    icon: const Icon(Icons.refresh_rounded, size: 16),
                                    label: const Text('Clear Search', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 9),
                            itemBuilder: (ctx, index) {
                              final t = filtered[index];
                              final isSelected = t.id == currentTrip?.id;
                              final isConcluded = t.isCompleted || t.status == 'completed';

                              Color modeColor;
                              String modeLabel;
                              IconData modeIcon;
                              if (t.isSolo) {
                                modeColor = const Color(0xFF2563EB);
                                modeLabel = 'Solo';
                                modeIcon = Icons.person_rounded;
                              } else if (t.isFamily) {
                                modeColor = const Color(0xFFD97706);
                                modeLabel = 'Family';
                                modeIcon = Icons.family_restroom_rounded;
                              } else {
                                modeColor = AppTheme.primary;
                                modeLabel = 'Group';
                                modeIcon = Icons.group_rounded;
                              }

                              return InkWell(
                                onTap: () {
                                  ref.read(selectedTripIdProvider.notifier).state = t.id;
                                  Navigator.pop(ctx);
                                  HapticFeedback.selectionClick();
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(13),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.primary.withAlpha(isDark ? 35 : 18)
                                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppTheme.primary
                                          : (isConcluded
                                              ? (isDark ? const Color(0xFFF59E0B).withAlpha(150) : const Color(0xFFD97706).withAlpha(140))
                                              : (isDark ? const Color(0xFF10B981).withAlpha(120) : const Color(0xFF10B981).withAlpha(90))),
                                      width: isSelected ? 1.8 : 1.1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppTheme.primary.withAlpha(30),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      // Status icon container
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppTheme.primary
                                              : (isConcluded
                                                  ? (isDark ? Colors.white10 : Colors.grey[200])
                                                  : const Color(0xFF10B981).withAlpha(isDark ? 35 : 22)),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isSelected
                                              ? Icons.check_rounded
                                              : (isConcluded ? Icons.flag_rounded : Icons.navigation_rounded),
                                          color: isSelected
                                              ? Colors.white
                                              : (isConcluded ? const Color(0xFF64748B) : const Color(0xFF10B981)),
                                          size: 20,
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
                                                      fontSize: 14.5,
                                                      letterSpacing: -0.2,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                // Active / Concluded Status Badge
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                  decoration: BoxDecoration(
                                                    color: isConcluded
                                                        ? const Color(0xFF64748B).withAlpha(isDark ? 40 : 25)
                                                        : const Color(0xFF10B981).withAlpha(isDark ? 40 : 25),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: isConcluded
                                                          ? const Color(0xFF64748B).withAlpha(90)
                                                          : const Color(0xFF10B981).withAlpha(100),
                                                      width: 0.8,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    isConcluded ? 'CONCLUDED' : 'LIVE',
                                                    style: TextStyle(
                                                      fontSize: 8.5,
                                                      fontWeight: FontWeight.w900,
                                                      color: isConcluded
                                                          ? (isDark ? Colors.grey[300] : const Color(0xFF475569))
                                                          : const Color(0xFF10B981),
                                                      letterSpacing: 0.4,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                // Mode Tag
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: modeColor.withAlpha(20),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(modeIcon, size: 9.5, color: modeColor),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        modeLabel,
                                                        style: TextStyle(fontSize: 9.5, color: modeColor, fontWeight: FontWeight.bold),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '•  ${t.members.length} member${t.members.length == 1 ? "" : "s"}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Text(
                                                    '•  ${DateFormatter.formatTripDateRange(t.startDate, t.endDate)}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
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

                  Divider(height: 1, color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                              ),
                              icon: const Icon(Icons.dashboard_rounded, size: 16),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('All Expeditions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.add_location_alt_rounded, size: 17),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('New Journey', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
        titleSpacing: 10,
        title: trips.isEmpty || currentTrip == null
            ? const Row(
                children: [
                  Icon(Icons.explore_rounded, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Current Trip',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ],
              )
            : InkWell(
                onTap: () => _openJourneySwitcher(context, trips, currentTrip),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primary.withAlpha(isDark ? 80 : 120),
                      width: 1.1,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (currentTrip.isRunning) ...[
                        PulsingLiveBeacon(
                          dotSize: 7.5,
                          showLabel: false,
                          color: currentTrip.isSolo ? const Color(0xFF2563EB) : const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 6),
                      ] else ...[
                        const Icon(Icons.flag_rounded, color: Color(0xFFD97706), size: 15),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
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
                        padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: (currentTrip.isCompleted
                                  ? Colors.grey
                                  : (currentTrip.isSolo ? const Color(0xFF2563EB) : AppTheme.primary))
                              .withAlpha(isDark ? 40 : 25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (currentTrip.isCompleted
                                    ? Colors.grey
                                    : (currentTrip.isSolo ? const Color(0xFF2563EB) : AppTheme.primary))
                                .withAlpha(80),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          currentTrip.isCompleted
                              ? 'DONE'
                              : (currentTrip.isSolo ? 'SOLO' : (currentTrip.isFamily ? 'FAMILY' : 'GROUP')),
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: currentTrip.isCompleted
                                ? (isDark ? Colors.grey[300] : const Color(0xFF475569))
                                : (currentTrip.isSolo ? const Color(0xFF2563EB) : AppTheme.primary),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 1),
                      const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.primary, size: 18),
                    ],
                  ),
                ),
              ),
        actions: [
          if (trackingState.isTracking && currentTrip != null && !currentTrip.isCompleted && currentTrip.status != 'completed')
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
      floatingActionButton: (currentTrip != null && !currentTrip.isCompleted && MediaQuery.of(context).viewInsets.bottom == 0)
          ? AppFloatingActionButton(
              heroTag: 'current_trip_ocr_fab',
              onTap: () => QuickBillActionSheet.show(context, trip: currentTrip),
              customIcon: const OcrAddIcon(),
              label: 'Quick Bill',
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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

    final categoryBreakdown = <String, double>{};
    for (final exp in tripExpenses) {
      final cat = exp.category.toString().split('.').last;
      final label = AppConstants.expenseCategories.contains(cat)
          ? '${cat[0].toUpperCase()}${cat.substring(1)}'
          : 'General';
      categoryBreakdown[label] = (categoryBreakdown[label] ?? 0.0) + exp.totalAmount;
    }

    // Item 19: Accurate upcoming stoppage - only show if genuinely ongoing or scheduled in future
    Stoppage? nextStoppage;
    if (!trip.isCompleted) {
      final activeStoppages = stoppages.where((s) => s.isOngoing).toList();
      if (activeStoppages.isNotEmpty) {
        nextStoppage = activeStoppages.first;
      } else {
        final futureStops = stoppages
            .where((s) => s.arrivedAt.isAfter(DateTime.now()))
            .toList();
        if (futureStops.isNotEmpty) {
          futureStops.sort((a, b) => a.arrivedAt.compareTo(b.arrivedAt));
          nextStoppage = futureStops.first;
        }
      }
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(tripListProvider.notifier).reload();
        ref.read(allStoppagesProvider.notifier).reload();
        ref.read(allExpensesProvider.notifier).reload();
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Concluded Journey Status Alert Banner
            if (trip.isCompleted) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(isDark ? 28 : 18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.withAlpha(isDark ? 80 : 55)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.flag_rounded, color: Colors.amber, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This journey has concluded. Live telemetry is locked and room is closed. You can review stats or reopen below.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 1. Executive Journey Cockpit Hero Card with Live Telemetry
            CurrentTripHeroCard(
              trip: trip,
              isDark: isDark,
              totalSpent: totalSpent,
              expenseCount: tripExpenses.length,
              trackingState: trackingState,
              onToggleTracking: () async {
                if (trackingState.isTracking) {
                  ref.read(liveLocationTrackerProvider.notifier).stopTracking();
                } else {
                  final canProceed = await TripGuardHelper.ensureTripOpenForEdit(
                    context,
                    ref,
                    trip,
                    actionLabel: 'broadcast live convoy telemetry',
                  );
                  if (!canProceed || !context.mounted) return;
                  ref.read(liveLocationTrackerProvider.notifier).startTracking(trip.id);
                }
              },
              onTapPieChart: () {
                HapticFeedback.lightImpact();
                AppNavigator.push(context, TripAnalyticsScreen(tripId: trip.id, initialTabIndex: 0));
              },
              onTapLedger: () {
                HapticFeedback.selectionClick();
                AppNavigator.push(context, TripAnalyticsScreen(tripId: trip.id, initialTabIndex: 1));
              },
              onTapCard: () {
                HapticFeedback.lightImpact();
                _navigateToTripDetail(trip, initialTabIndex: 0);
              },
            ),
            const SizedBox(height: 10),

            // Full-Width Audit Trail & Trust History Action Button (Between Top Card and Journey Modules)
            _buildAuditTrailAndTrustHistoryButton(context, trip, isDark),
            const SizedBox(height: 14),

            // 2. Journey Modules Hub (All 6 Core Modules in Clean 3x2 Grid)
            const Row(
              children: [
                Icon(Icons.grid_view_rounded, size: 16, color: AppTheme.primary),
                SizedBox(width: 6),
                Text(
                  'JOURNEY MODULES (6)',
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
                    icon: Icons.groups_rounded,
                    title: 'Members',
                    subtitle: '${trip.members.length} members',
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                    onTap: () => _navigateToTripDetail(trip, initialTabIndex: 2),
                  ),
                ),
                const SizedBox(width: 10),
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
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
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
                const SizedBox(width: 10),
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.analytics_rounded,
                    title: 'Analytics',
                    subtitle: 'Charts & ledger',
                    color: const Color(0xFF06B6D4),
                    isDark: isDark,
                    onTap: () {
                      AppNavigator.push(context, TripAnalyticsScreen(tripId: trip.id));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

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
                        const Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.near_me_rounded, size: 16, color: Color(0xFF0F766E)),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'NEXT UPCOMING STOPPAGE',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
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

            // 6. Journey Lifecycle & Executive Summary Actions (Items 17 & 18)
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.flag_rounded, size: 16, color: AppTheme.primary),
                SizedBox(width: 6),
                Text(
                  'LIFECYCLE & SUMMARY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // 1st place: Analytics & Metrics
                Expanded(
                  child: _buildInsightsPill(
                    icon: Icons.analytics_rounded,
                    label: 'Analytics & Metrics',
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
                // 2nd place: Trip Audit Trail
                Expanded(
                  child: _buildInsightsPill(
                    icon: Icons.history_rounded,
                    label: 'Trip Audit Trail',
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                    onTap: () => AuditLogSheet.show(context, trip),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // 3rd place: End Journey or Reopen Journey
                Expanded(
                  child: _buildInsightsPill(
                    icon: trip.isCompleted ? Icons.replay_rounded : Icons.flag_rounded,
                    label: trip.isCompleted ? 'Reopen Journey' : 'End Journey',
                    color: trip.isCompleted ? const Color(0xFF10B981) : const Color(0xFFD97706),
                    isDark: isDark,
                    onTap: () {
                      if (trip.isCompleted) {
                        _confirmReopenTrip(context, trip);
                      } else {
                        _confirmConcludeTrip(context, trip);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // 4th place: Trip Review (1-5 Star Rating & Notes)
                Expanded(
                  child: _buildInsightsPill(
                    icon: Icons.star_rate_rounded,
                    label: trip.rating != null
                        ? 'Trip Review (${trip.rating!.toStringAsFixed(1)}★)'
                        : 'Trip Review',
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                    onTap: () => _showTripReviewDialog(context, trip),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Export Trip Summary PDF
            _buildInsightsPill(
              icon: Icons.picture_as_pdf_rounded,
              label: 'Export Complete Trip Summary PDF',
              color: const Color(0xFF6366F1),
              isDark: isDark,
              onTap: () => _exportPdf(trip),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildAuditTrailAndTrustHistoryButton(BuildContext context, Trip trip, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 30 : 12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            AuditLogSheet.show(context, trip);
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: const Color(0xFF8B5CF6).withAlpha(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withAlpha(isDark ? 35 : 18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    size: 18,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Audit Trail & Trust History',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Tamper-evident activity logs & ledger transparency',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
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
