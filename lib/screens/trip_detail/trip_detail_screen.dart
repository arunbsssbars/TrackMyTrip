import 'dart:async';
import '../common/trip_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/cloud_trip_sync_service.dart';
import '../../core/services/live_location_tracker_service.dart';
import '../../core/services/offline_sync_engine.dart';
import '../../core/services/tombstone_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/trip.dart';
import '../../providers/auth_provider.dart';
import '../../providers/audit_log_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/settlement_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../../models/stoppage.dart';
import '../../providers/trip_provider.dart';
import '../memories/add_memory_dialog.dart';
import '../stoppage/add_stoppage_dialog.dart';
import 'tabs/expenses_tab.dart';
import 'tabs/map_tab.dart';
import 'tabs/memories_tab.dart';
import 'tabs/settlement_tab.dart';
import 'tabs/timeline_tab.dart';
import 'tabs/members_tab.dart';
import 'tabs/analytics_tab.dart';
import 'tabs/audit_tab.dart';
import '../../core/services/firestore_sync_service.dart';
import '../notifications/notification_center_sheet.dart';
import '../common/sos_badge_icon.dart';
import '../common/universal_bottom_bar.dart';
import '../../widgets/app_floating_button.dart';
import '../../widgets/quick_bill_action_sheet.dart';
import '../../core/design_system/design_system.dart';

class TripDetailScreen extends ConsumerStatefulWidget {
  final String tripId;
  final int initialTabIndex;

  const TripDetailScreen({
    super.key,
    required this.tripId,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  int _tabCount = 5;
  final bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    final trips = ref.read(tripListProvider);
    Trip? trip = trips.where((t) => t.id == widget.tripId).firstOrNull;
    trip ??= ref.read(localStorageServiceProvider).getTrip(widget.tripId);
    _tabCount = (trip != null && trip.isSolo) ? 7 : 8;
    _tabController = TabController(
      length: _tabCount,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, _tabCount - 1),
    );

    // Connect to Firestore Real-Time Room (Stoppages, Expenses, Memories, Radar Locations, Alerts)
    ref.read(firestoreSyncServiceProvider).connectTripRoom(widget.tripId);

    // Start Real-Time Cloud Sync
    final roomCode = (trip != null && trip.shareCode != null)
        ? trip.shareCode!
        : CloudTripSyncService.getRoomCode(widget.tripId, trip: trip);
    CloudTripSyncService.startLiveSync(
      tripId: widget.tripId,
      roomCode: roomCode,
      onRemoteUpdateReceived: (pkg) async {
        await ref.read(tripListProvider.notifier).syncRemotePackage(pkg);
        ref.read(allStoppagesProvider.notifier).reload();
        ref.read(allExpensesProvider.notifier).reload();
        ref.read(allMemoriesProvider.notifier).reload();
        ref.read(allSettlementsProvider.notifier).reload();
        ref.read(allAuditLogsProvider.notifier).reload();
        if (mounted) setState(() {});
      },
    );

    // Auto-start live GPS journey trace tracking by default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(liveLocationTrackerProvider.notifier).startTracking(widget.tripId);
    });
  }

  @override
  void dispose() {
    ref.read(firestoreSyncServiceProvider).disconnectAll();
    CloudTripSyncService.stopLiveSync(widget.tripId);
    _tabController.dispose();
    super.dispose();
  }

  void _confirmReopenTrip(BuildContext context, Trip trip) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Reopen Journey?'),
          ],
        ),
        content: Text(
          'Reopening "${trip.title}" will allow you and all members to resume adding stoppages, logging expenses, and tracking live GPS.\n\nA notification will be sent to all members.',
          style: const TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(tripListProvider.notifier).reopenTrip(trip.id);

              if (context.mounted) {
                AppSnackBar.showSuccess(context, 'Journey reopened! Members have been notified.');
              }
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            icon: const Icon(Icons.check_circle_rounded, size: 16),
            label: const Text('Reopen Journey'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<Trip>>(tripListProvider, (previous, next) {
      if (previous != null && previous.any((t) => t.id == widget.tripId)) {
        if (!next.any((t) => t.id == widget.tripId)) {
          final stillInStorage = ref.read(localStorageServiceProvider).getTrip(widget.tripId);
          if (stillInStorage == null || stillInStorage.isDeleted || TombstoneService.isTombstoned(widget.tripId)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
                AppSnackBar.showError(context, 'This trip was deleted or removed.');
              }
            });
          }
        }
      }
    });

    final trips = ref.watch(tripListProvider);
    final currentTrip = ref.watch(currentTripProvider);

    Trip? matchedTrip;
    for (final t in trips) {
      if (t.id == widget.tripId) {
        matchedTrip = t;
        break;
      }
    }
    Trip? tripCandidate = matchedTrip ?? (currentTrip?.id == widget.tripId ? currentTrip : null);
    if (tripCandidate == null) {
      final fromStorage = ref.read(localStorageServiceProvider).getTrip(widget.tripId);
      if (fromStorage != null && !fromStorage.isDeleted && !TombstoneService.isTombstoned(widget.tripId)) {
        tripCandidate = fromStorage;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(tripListProvider.notifier).reload();
        });
      }
    }
    if (_isExiting || tripCandidate == null || tripCandidate.isDeleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          if (!_isExiting) {
            AppSnackBar.showError(context, 'This trip is no longer active or was deleted.');
          }
        }
      });
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final Trip trip = tripCandidate;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final neededCount = trip.isSolo ? 7 : 8;
    if (_tabCount != neededCount) {
      final oldIndex = _tabController.index;
      _tabCount = neededCount;
      _tabController.dispose();
      _tabController = TabController(
        length: _tabCount,
        vsync: this,
        initialIndex: oldIndex.clamp(0, _tabCount - 1),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          tooltip: 'Back to journeys',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    trip.title,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16.5, letterSpacing: -0.3),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (trip.isCompleted) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFEF4444).withAlpha(60), width: 0.8),
                    ),
                    child: const Text(
                      'CONCLUDED',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${DateFormatter.formatTripDateRange(trip.startDate, trip.endDate)} • ${trip.isSolo ? "Solo" : (trip.isFamily ? "Family" : "Group")}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trip.rating != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(isDark ? 35 : 22),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.withAlpha(isDark ? 90 : 60), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                        const SizedBox(width: 2.5),
                        Text(
                          trip.rating!.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.amber[300] : Colors.amber[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          _buildSyncStatusAction(context),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: SosBadgeIcon(
              size: 32,
              tooltip: 'Emergency SOS & Safety',
              onTap: () => NotificationCenterSheet.show(context),
            ),
          ),
          TripMenuButton(
            trip: trip,
            onTripDeleted: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(42),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
                bottom: BorderSide(
                  color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.white.withAlpha(0),
                    Colors.white,
                    Colors.white,
                    Colors.white.withAlpha(0),
                  ],
                  stops: const [0.0, 0.02, 0.98, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                physics: const BouncingScrollPhysics(),
                tabAlignment: TabAlignment.start,
                labelColor: Colors.white,
                unselectedLabelColor: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                indicator: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withAlpha(80),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorWeight: 0,
                indicatorPadding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                splashBorderRadius: BorderRadius.circular(18),
                tabs: [
                  Tab(
                    height: 34,
                    child: Semantics(
                      label: 'Timeline tab',
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timeline_rounded, size: 14),
                            SizedBox(width: 4),
                            Text('Timeline', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Tab(
                    height: 34,
                    child: Semantics(
                      label: 'Route tab',
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.map_rounded, size: 14),
                            SizedBox(width: 4),
                            Text('Route', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Tab(
                    height: 34,
                    child: Semantics(
                      label: 'Members tab',
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.groups_rounded, size: 14),
                            SizedBox(width: 4),
                            Text('Members', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Tab(
                    height: 34,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.receipt_long_rounded, size: 14),
                          const SizedBox(width: 4),
                          Text(trip.isSolo ? 'Budget' : 'Bills', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  if (!trip.isSolo)
                    const Tab(
                      height: 34,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.handshake_rounded, size: 14),
                            SizedBox(width: 4),
                            Text('Settle', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  const Tab(
                    height: 34,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_library_rounded, size: 14),
                          SizedBox(width: 4),
                          Text('Memories', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const Tab(
                    height: 34,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.insights_rounded, size: 14),
                          SizedBox(width: 4),
                          Text('Analytics', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const Tab(
                    height: 34,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, size: 14),
                          SizedBox(width: 4),
                          Text('Trip Audit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const _SyncErrorBanner(),
          if (trip.isArchivedByCreator)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              color: Colors.amber.withAlpha(isDark ? 30 : 20),
              child: Row(
                children: [
                  const Icon(Icons.archive_outlined, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Trip archived by creator • Your expenses & ledger are preserved',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.amber[200] : Colors.amber[900],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.redAccent,
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('Delete from Workspace?'),
                          content: const Text(
                            'This will remove the archived trip, expenses, and settlements from your personal workspace permanently.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        await ref.read(tripListProvider.notifier).deleteTrip(trip.id);
                        if (context.mounted && Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      }
                    },
                    child: const Text(
                      'Delete',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            )
          else if (trip.isCompleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 15, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Trip concluded • Records in read-only mode',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trip.isCreator(ref.read(authNotifierProvider).valueOrNull?.id))
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFF10B981),
                      ),
                      onPressed: () => _confirmReopenTrip(context, trip),
                      icon: const Icon(Icons.restart_alt_rounded, size: 13),
                      label: const Text(
                        'Reopen',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TabBarView(
                controller: _tabController,
                children: [
                  TimelineTab(
                    trip: trip,
                    onNavigateToMap: (stoppage) {
                      _tabController.animateTo(1);
                      ref.read(focusedStoppageProvider.notifier).state = stoppage;
                    },
                  ),
                  MapTab(trip: trip),
                  MembersTab(trip: trip),
                  ExpensesTab(trip: trip),
                  if (!trip.isSolo)
                    SettlementTab(trip: trip),
                  MemoriesTab(trip: trip),
                  AnalyticsTab(trip: trip),
                  AuditTab(trip: trip),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, child) {
          if (trip.isCompleted) {
            return const SizedBox.shrink();
          }
          final index = _tabController.index;
          // Index 1: Route tab - internal map controls
          if (index == 1) {
            return const SizedBox.shrink();
          }

          // Index 2: Members tab - dedicated header action
          if (index == 2) {
            return const SizedBox.shrink();
          }

          // Index 4: Settle tab (when not solo) - internal settle action
          if (index == 4 && !trip.isSolo) {
            return const SizedBox.shrink();
          }

          IconData? icon;
          Widget? customIcon;
          String label;
          VoidCallback onPressed;

          final memoriesIndex = trip.isSolo ? 4 : 5;

          if (index == 0) {
            // Tab 0: Timeline tab
            icon = Icons.add_location_alt_rounded;
            label = 'Add Stop';
            onPressed = () {
              AddStoppageDialog.show(context, tripId: trip.id);
            };
          } else if (index == 3) {
            // Tab 3: Bills & Splits / Budget tab
            customIcon = const OcrAddIcon();
            label = 'Quick Bill';
            onPressed = () {
              QuickBillActionSheet.show(context, trip: trip);
            };
          } else if (index == memoriesIndex) {
            // Memories tab
            icon = Icons.add_a_photo_rounded;
            label = 'Add Photo';
            onPressed = () {
              final stoppages = ref.read(tripStoppagesProvider(trip.id));
              final Stoppage targetStoppage = stoppages.isNotEmpty
                  ? stoppages.first
                  : Stoppage(
                      id: 'general_${trip.id}',
                      tripId: trip.id,
                      name: trip.title,
                      latitude: 0.0,
                      longitude: 0.0,
                      arrivedAt: DateTime.now(),
                      category: 'general',
                      createdBy: trip.createdByMemberId,
                    );
              showDialog(
                context: context,
                builder: (context) => AddMemoryDialog(tripId: trip.id, stoppage: targetStoppage),
              );
            };
          } else {
            return const SizedBox.shrink();
          }

          return AppFloatingActionButton(
            heroTag: 'trip_detail_fab_$index',
            icon: icon,
            customIcon: customIcon,
            label: label,
            onTap: onPressed,
          );
        },
      ),
      bottomNavigationBar: const UniversalBottomBar(),
    );
  }

  Widget _buildSyncStatusAction(BuildContext context) {
    final syncEngine = ref.watch(offlineSyncEngineProvider);
    final pendingCount = syncEngine.pendingCount;
    final isSyncing = syncEngine.isSyncing;

    if (!isSyncing && pendingCount == 0) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      child: Tooltip(
        message: isSyncing 
            ? 'Syncing changes to cloud...' 
            : '$pendingCount pending offline changes. Tap to sync now.',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            HapticFeedback.lightImpact();
            if (syncEngine.isSyncing) return;
            AppSnackBar.showInfo(context, 'Syncing $pendingCount pending changes to cloud...');
            final success = await syncEngine.syncPendingMutationsNow();
            if (context.mounted) {
              if (success) {
                AppSnackBar.showSuccess(context, 'All offline changes successfully synced!');
              } else {
                AppSnackBar.showError(context, syncEngine.lastSyncError ?? 'Sync paused. Changes kept safe locally.');
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isSyncing
                  ? AppTheme.primary.withAlpha(isDark ? 50 : 25)
                  : Colors.amber.withAlpha(isDark ? 50 : 25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSyncing
                    ? AppTheme.primary.withAlpha(isDark ? 120 : 80)
                    : Colors.amber.withAlpha(isDark ? 140 : 90),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSyncing) ...[
                  const SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(strokeWidth: 1.6, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Syncing',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ] else ...[
                  Icon(Icons.cloud_upload_outlined, size: 13, color: isDark ? Colors.amber[300] : Colors.amber[900]),
                  const SizedBox(width: 3),
                  Text(
                    '$pendingCount',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.amber[300] : Colors.amber[900],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Loop 44: Auto-dismissing Sync Failure Banner ─────────────────────────────

class _SyncErrorBanner extends ConsumerStatefulWidget {
  const _SyncErrorBanner();

  @override
  ConsumerState<_SyncErrorBanner> createState() => _SyncErrorBannerState();
}

class _SyncErrorBannerState extends ConsumerState<_SyncErrorBanner> {
  static const Duration _autoDismissAfter = Duration(seconds: 8);
  Timer? _dismissTimer;
  String? _scheduledFor;

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _scheduleDismiss(String error) {
    if (_scheduledFor == error) return;
    _scheduledFor = error;
    _dismissTimer?.cancel();
    _dismissTimer = Timer(_autoDismissAfter, () {
      if (!mounted) return;
      final engine = ref.read(offlineSyncEngineProvider);
      if (engine.lastSyncError == error) engine.clearLastSyncError();
    });
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(offlineSyncEngineProvider);
    final error = engine.lastSyncError;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (error == null || error.trim().isEmpty) {
      _scheduledFor = null;
      _dismissTimer?.cancel();
      return const SizedBox.shrink();
    }
    _scheduleDismiss(error);

    return Material(
      color: isDark ? const Color(0xFF451A03) : const Color(0xFFFFF7ED),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 16, color: Color(0xFFEA580C)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sync paused • Changes kept safe locally',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFFED7AA) : const Color(0xFF9A3412),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                foregroundColor: const Color(0xFFEA580C),
              ),
              onPressed: engine.isSyncing
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      engine.clearLastSyncError();
                      engine.syncPendingMutationsNow();
                    },
              child: const Text('Retry', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
            ),
            IconButton(
              tooltip: 'Dismiss',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: const Icon(Icons.close_rounded, size: 16),
              color: isDark ? Colors.white70 : const Color(0xFF9A3412),
              onPressed: engine.clearLastSyncError,
            ),
          ],
        ),
      ),
    );
  }
}
