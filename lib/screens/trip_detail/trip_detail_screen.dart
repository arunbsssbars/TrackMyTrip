import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/cloud_trip_sync_service.dart';
import '../../core/services/live_location_tracker_service.dart';
import '../../core/services/pdf_export_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/trip.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/settlement_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';
import '../expense/add_expense_screen.dart';
import '../memory/add_memory_dialog.dart';
import '../stats/trip_analytics_screen.dart';
import '../stoppage/add_stoppage_dialog.dart';
import '../../core/utils/page_transitions.dart';
import 'edit_trip_dialog.dart';
import 'share_trip_sheet.dart';
import 'tabs/expenses_tab.dart';
import 'tabs/map_tab.dart';
import 'tabs/memories_tab.dart';
import 'tabs/settlement_tab.dart';
import 'tabs/timeline_tab.dart';
import 'tabs/members_tab.dart';
import '../../core/services/firestore_sync_service.dart';
import '../notifications/notification_center_sheet.dart';
import '../common/sos_badge_icon.dart';

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
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    final trips = ref.read(tripListProvider);
    Trip? trip = trips.where((t) => t.id == widget.tripId).firstOrNull;
    trip ??= ref.read(localStorageServiceProvider).getTrip(widget.tripId);
    _tabCount = (trip != null && trip.isSolo) ? 5 : 6;
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

  void _exportPdf() async {
    final trip = ref.read(currentTripProvider);
    if (trip == null) return;

    final stoppages = ref.read(currentTripStoppagesProvider);
    final expenses = ref.read(currentTripExpensesProvider);
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

  void _openShareSheet(Trip trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => ShareTripSheet(trip: trip),
    );
  }

  void _showEndTripExperienceDialog(Trip trip) {
    double rating = trip.rating ?? 5.0;
    final reviewController = TextEditingController(text: trip.experienceReview ?? '');
    final quickHighlights = [
      '⛰️ Scenic Views',
      '🍜 Delicious Food',
      '🛣️ Smooth Drive',
      '💰 Budget Friendly',
      '🏕️ Great Stay',
      '🎉 Fun Companions',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 14,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(80),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.flag_circle_rounded, color: Colors.amber, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.isCompleted ? 'Trip Experience & Memories' : 'End Expedition & Review',
                              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                            ),
                            Text(
                              trip.title,
                              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Rating Stars
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'How was your journey experience?',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            final starValue = (index + 1).toDouble();
                            final isFilled = rating >= starValue;
                            return GestureDetector(
                              onTap: () => setSheetState(() => rating = starValue),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                                  size: 34,
                                  color: isFilled ? Colors.amber[600] : Colors.grey[400],
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Quick Highlight Tags
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: quickHighlights.map((tag) {
                      final hasTag = reviewController.text.contains(tag);
                      return ChoiceChip(
                        showCheckmark: false,
                        label: Text(tag, style: const TextStyle(fontSize: 11)),
                        selected: hasTag,
                        selectedColor: Colors.amber.withAlpha(40),
                        labelStyle: TextStyle(
                          color: hasTag ? Colors.amber[900] : null,
                          fontWeight: hasTag ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          setSheetState(() {
                            if (selected) {
                              if (reviewController.text.isEmpty) {
                                reviewController.text = tag;
                              } else {
                                reviewController.text = '${reviewController.text} • $tag';
                              }
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Review Text Field
                  TextField(
                    controller: reviewController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Trip Notes / Overall Experience',
                      hintText: 'Memorable moments, highlights, recommendations...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Save & Complete Button
                  FilledButton.icon(
                    onPressed: () {
                      final updated = trip.copyWith(
                        isCompleted: true,
                        rating: rating,
                        experienceReview: reviewController.text.trim(),
                        completedAt: trip.completedAt ?? DateTime.now(),
                      );
                      ref.read(tripListProvider.notifier).updateTrip(updated);
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🎉 Trip experience recorded & journey completed!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      trip.isCompleted ? 'Update Experience' : 'Finish Trip & Save Experience',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

                  if (trip.isCompleted) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        final updated = trip.copyWith(
                          isCompleted: false,
                        );
                        ref.read(tripListProvider.notifier).updateTrip(updated);
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🔄 Trip reopened as active live journey.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: const Text('Reopen Trip as Ongoing / Live', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteTrip(BuildContext context, Trip trip) {
    final expenses = ref.read(allExpensesProvider).where((e) => e.tripId == trip.id).toList();
    final companionCount = trip.members.where((m) => m.id != trip.createdByMemberId).length;
    final hasExpenses = expenses.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Delete for Everyone?',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to permanently delete "${trip.title}"?'),
              const SizedBox(height: 12),
              if (companionCount > 0)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⚠️ This will remove the trip for you and all $companionCount companion(s). All shared logs and memories will be permanently deleted.',
                    style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500),
                  ),
                ),
              if (hasExpenses)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Note: ${expenses.length} recorded expense(s) will be erased.',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
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
          ElevatedButton(
            onPressed: () async {
              setState(() => _isExiting = true);
              Navigator.of(ctx).pop();
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              await ref.read(tripListProvider.notifier).deleteTrip(trip.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Trip "${trip.title}" deleted for everyone'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Trip', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveTrip(BuildContext context, Trip trip) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.exit_to_app_rounded, color: Colors.amber[900], size: 24),
            const SizedBox(width: 8),
            const Text('Leave Trip?'),
          ],
        ),
        content: Text(
          'You will no longer be part of "${trip.title}". Your recorded contributions will remain with the group, and this trip will be removed from your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() => _isExiting = true);
              Navigator.of(ctx).pop();
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              await ref.read(tripListProvider.notifier).leaveTrip(trip.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('You left "${trip.title}"'),
                    backgroundColor: Colors.amber[900],
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[900]),
            child: const Text('Leave Trip', style: TextStyle(color: Colors.white)),
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
          if (stillInStorage == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This trip was deleted or removed.'),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
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
      if (fromStorage != null && !fromStorage.isDeleted) {
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text('This trip is no longer active or was deleted.')),
                  ],
                ),
                backgroundColor: Color(0xFFE11D48),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 3),
              ),
            );
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

    final neededCount = trip.isSolo ? 5 : 6;
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
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.withAlpha(60), width: 0.8),
                    ),
                    child: Text(
                      trip.rating != null ? '⭐ ${trip.rating!.toStringAsFixed(1)}' : 'ENDED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.amber[900],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${DateFormatter.formatTripDateRange(trip.startDate, trip.endDate)} • ${trip.isSolo ? "Solo" : (trip.isFamily ? "Family" : "Group")}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: SosBadgeIcon(
              size: 32,
              tooltip: 'Emergency SOS & Safety',
              onTap: () => NotificationCenterSheet.show(context),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 22),
            tooltip: 'Trip Menu',
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 230),
            position: PopupMenuPosition.under,
            onSelected: (val) async {
              if (val == 'share') {
                _openShareSheet(trip);
              } else if (val == 'edit_trip') {
                EditTripDialog.show(context, trip);
              } else if (val == 'end_trip') {
                _showEndTripExperienceDialog(trip);
              } else if (val == 'analytics') {
                AppNavigator.push(
                  context,
                  TripAnalyticsScreen(tripId: trip.id),
                );
              } else if (val == 'pdf') {
                _exportPdf();
              } else if (val == 'delete') {
                _confirmDeleteTrip(context, trip);
              } else if (val == 'leave') {
                _confirmLeaveTrip(context, trip);
              } else if (val == 'signout') {
                await ref.read(authNotifierProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
                }
              }
            },
            itemBuilder: (context) {
              final authUser = ref.read(authNotifierProvider).valueOrNull;
              final isLead = trip.isCreator(authUser?.id);

              return [
                // 1. Share & Sync
                PopupMenuItem(
                  height: 42,
                  value: 'share',
                  child: Row(
                    children: [
                      const Icon(Icons.share_outlined, color: AppTheme.secondary, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Share Trip', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          CloudTripSyncService.getRoomCode(trip.id, trip: trip).replaceAll('TRIP-', ''),
                          style: const TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Edit Trip Details & Companions
                const PopupMenuItem(
                  height: 40,
                  value: 'edit_trip',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, color: AppTheme.primary, size: 18),
                      SizedBox(width: 10),
                      Text('Edit Trip & Members', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),

                // 3. End Trip / Experience Review (Creator Only)
                if (isLead)
                  PopupMenuItem(
                    height: 40,
                    value: 'end_trip',
                    child: Row(
                      children: [
                        Icon(
                          trip.isCompleted ? Icons.star_outline_rounded : Icons.flag_outlined,
                          color: Colors.amber[800],
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          trip.isCompleted ? 'Trip Review' : 'End Trip & Review',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber[900],
                          ),
                        ),
                      ],
                    ),
                  ),


                // 5. Trip Analytics
                const PopupMenuItem(
                  height: 40,
                  value: 'analytics',
                  child: Row(
                    children: [
                      Icon(Icons.insights_outlined, color: AppTheme.primary, size: 18),
                      SizedBox(width: 10),
                      Text('Trip Analytics', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),

                // 6. Export PDF
                const PopupMenuItem(
                  height: 40,
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf_outlined, color: Colors.deepOrange, size: 18),
                      SizedBox(width: 10),
                      Text('Export PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),

                const PopupMenuDivider(height: 8),

                // 7. Role-based: Delete for Everyone (Creator) vs Leave Trip (Companion)
                if (isLead)
                  const PopupMenuItem(
                    height: 38,
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever_rounded, color: Colors.red, size: 18),
                        SizedBox(width: 10),
                        Text('Delete for Everyone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red)),
                      ],
                    ),
                  )
                else
                  PopupMenuItem(
                    height: 38,
                    value: 'leave',
                    child: Row(
                      children: [
                        Icon(Icons.exit_to_app_rounded, color: Colors.amber[900], size: 18),
                        const SizedBox(width: 10),
                        Text('Leave Trip', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.amber[900])),
                      ],
                    ),
                  ),

                // 8. Sign Out
                const PopupMenuItem(
                  height: 38,
                  value: 'signout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, color: Colors.red, size: 18),
                      SizedBox(width: 10),
                      Text('Sign Out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red)),
                    ],
                  ),
                ),
              ];
            },
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
                  const Tab(
                    height: 34,
                    child: Padding(
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
                  const Tab(
                    height: 34,
                    child: Padding(
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
                  const Tab(
                    height: 34,
                    child: Padding(
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
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          TimelineTab(trip: trip),
          MapTab(trip: trip),
          MembersTab(trip: trip),
          ExpensesTab(trip: trip),
          if (!trip.isSolo)
            SettlementTab(trip: trip),
          MemoriesTab(trip: trip),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, child) {
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

          IconData icon;
          String label;
          VoidCallback onPressed;

          if (index == 0) {
            // Tab 0: Timeline tab
            icon = Icons.add_location_alt_rounded;
            label = 'Add Stop';
            onPressed = () {
              AddStoppageDialog.show(context, tripId: trip.id);
            };
          } else if (index == 3) {
            // Tab 3: Bills & Splits / Budget tab
            icon = Icons.add_card_rounded;
            label = 'Add Bill';
            onPressed = () {
              AppNavigator.push(
                context,
                AddExpenseScreen(tripId: trip.id),
              );
            };
          } else if (index == (_tabCount - 1)) {
            // Last tab: Memories tab
            icon = Icons.add_a_photo_rounded;
            label = 'Add Photo';
            onPressed = () {
              final stoppages = ref.read(currentTripStoppagesProvider);
              if (stoppages.isNotEmpty) {
                showDialog(
                  context: context,
                  builder: (context) => AddMemoryDialog(tripId: trip.id, stoppage: stoppages.first),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please tag a stoppage before adding photos.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            };
          } else {
            return const SizedBox.shrink();
          }

          return Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9488).withAlpha(110),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.white.withAlpha(45), width: 1),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(28),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 6.5),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
