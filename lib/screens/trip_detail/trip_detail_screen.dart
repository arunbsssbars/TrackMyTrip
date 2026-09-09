import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/cloud_trip_sync_service.dart';
import '../../core/services/live_location_tracker_service.dart';
import '../../core/services/pdf_export_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/trip.dart';
import '../../providers/expense_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/settlement_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';
import '../expense/add_expense_screen.dart';
import '../memory/add_memory_dialog.dart';
import '../stats/trip_analytics_screen.dart';
import '../stoppage/add_stoppage_dialog.dart';
import 'edit_trip_dialog.dart';
import 'share_trip_sheet.dart';
import 'tabs/expenses_tab.dart';
import 'tabs/map_tab.dart';
import 'tabs/memories_tab.dart';
import 'tabs/settlement_tab.dart';
import 'tabs/timeline_tab.dart';
import 'dart:async';
import '../../core/services/proximity_alert_service.dart';
import '../notifications/notification_center_sheet.dart';
import '../notifications/in_app_notification_banner.dart';

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
  StreamSubscription? _bannerSubscription;

  @override
  void initState() {
    super.initState();
    final trips = ref.read(tripListProvider);
    final trip = trips.where((t) => t.id == widget.tripId).firstOrNull;
    _tabCount = (trip?.isSolo ?? false) ? 4 : 5;
    _tabController = TabController(
      length: _tabCount,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, _tabCount - 1),
    );

    // Start Real-Time Cloud Sync
    final roomCode = CloudTripSyncService.generateRoomCode(widget.tripId);
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

    _bannerSubscription = ref.read(proximityAlertServiceProvider).bannerStream.listen((alert) {
      if (mounted) {
        InAppNotificationBanner.show(context, alert);
      }
    });
  }

  @override
  void dispose() {
    _bannerSubscription?.cancel();
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

  void _showSwitchPersonaDialog(Trip trip) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.switch_account_rounded, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Switch Active Traveler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select who is using this phone so new bills and memories default to this traveler:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ...trip.members.map((m) {
              final isCurrent = m.id == trip.currentUserMember?.id;
              final color = m.colorHex != null
                  ? Color(int.parse(m.colorHex!))
                  : AppTheme.primary;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: color,
                  child: Text(
                    m.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  m.name,
                  style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
                ),
                subtitle: isCurrent ? const Text('Active on this device', style: TextStyle(color: AppTheme.primary, fontSize: 11)) : null,
                trailing: isCurrent ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary) : null,
                onTap: () {
                  ref.read(tripListProvider.notifier).switchActiveMember(trip.id, m.id);
                  Navigator.of(ctx).pop();
                },
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Journey?'),
        content: Text('Are you sure you want to delete "${trip.title}" and all its recorded stops and bills?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(tripListProvider.notifier).deleteTrip(trip.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Trip "${trip.title}" deleted'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(tripListProvider);
    final currentTrip = ref.watch(currentTripProvider);

    Trip? matchedTrip;
    for (final t in trips) {
      if (t.id == widget.tripId) {
        matchedTrip = t;
        break;
      }
    }
    final trip = matchedTrip ?? currentTrip;

    if (trip == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Trip not found')),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeMember = trip.currentUserMember ?? (trip.members.isNotEmpty ? trip.members.first : null);

    final neededCount = trip.isSolo ? 4 : 5;
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
                Flexible(
                  child: Text(
                    trip.title,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17.5, letterSpacing: -0.3),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (trip.isCompleted) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.withAlpha(60), width: 0.8),
                    ),
                    child: Text(
                      trip.rating != null ? '⭐ ${trip.rating!.toStringAsFixed(1)}' : 'ENDED',
                      style: TextStyle(
                        fontSize: 9.5,
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
              '${DateFormatter.formatTripDateRange(trip.startDate, trip.endDate)} • ${trip.isSolo ? "Solo" : (trip.isFamily ? "Family" : "Group")}${activeMember != null ? " • ${activeMember.name}" : ""}',
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final unread = ref.watch(proximityAlertServiceProvider).unreadCount;
              return IconButton(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  child: const Icon(Icons.notifications_outlined),
                ),
                tooltip: 'Notifications & Safety',
                onPressed: () => NotificationCenterSheet.show(context),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 22),
            tooltip: 'Trip Menu',
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 230),
            position: PopupMenuPosition.under,
            onSelected: (val) {
              if (val == 'share') {
                _openShareSheet(trip);
              } else if (val == 'edit_trip') {
                EditTripDialog.show(context, trip);
              } else if (val == 'switch_persona') {
                _showSwitchPersonaDialog(trip);
              } else if (val == 'end_trip') {
                _showEndTripExperienceDialog(trip);
              } else if (val == 'analytics') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => TripAnalyticsScreen(tripId: trip.id)),
                );
              } else if (val == 'pdf') {
                _exportPdf();
              } else if (val == 'delete') {
                _confirmDeleteTrip(context, trip);
              }
            },
            itemBuilder: (context) => [
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

              // 3. Switch Persona (Only if group/family has multiple members)
              if (trip.members.length > 1)
                PopupMenuItem(
                  height: 40,
                  value: 'switch_persona',
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz_rounded, color: AppTheme.primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Switch Traveler (${activeMember?.name ?? "Me"})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              // 4. End Trip / Experience Review
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

              // 7. Delete Trip
              const PopupMenuItem(
                height: 38,
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                    SizedBox(width: 10),
                    Text('Delete Journey', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          TimelineTab(trip: trip),
          ExpensesTab(trip: trip),
          if (!trip.isSolo)
            SettlementTab(trip: trip),
          MapTab(trip: trip),
          MemoriesTab(trip: trip),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 30 : 8),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _tabController,
            builder: (context, child) {
              final currentIndex = _tabController.index;
              return NavigationBar(
                selectedIndex: currentIndex,
                onDestinationSelected: (idx) {
                  _tabController.animateTo(idx);
                  setState(() {});
                },
                backgroundColor: Colors.transparent,
                indicatorColor: AppTheme.primary.withAlpha(30),
                height: 64,
                elevation: 0,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.timeline_rounded, size: 22),
                    selectedIcon: Icon(Icons.timeline_rounded, color: AppTheme.primary, size: 24),
                    label: 'Timeline',
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.receipt_long_rounded, size: 22),
                    selectedIcon: const Icon(Icons.receipt_long_rounded, color: AppTheme.primary, size: 24),
                    label: trip.isSolo ? 'Budget' : 'Bills',
                  ),
                  if (!trip.isSolo)
                    const NavigationDestination(
                      icon: Icon(Icons.handshake_rounded, size: 22),
                      selectedIcon: Icon(Icons.handshake_rounded, color: AppTheme.primary, size: 24),
                      label: 'Settle',
                    ),
                  const NavigationDestination(
                    icon: Icon(Icons.map_rounded, size: 22),
                    selectedIcon: Icon(Icons.map_rounded, color: AppTheme.primary, size: 24),
                    label: 'Route',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.photo_library_rounded, size: 22),
                    selectedIcon: Icon(Icons.photo_library_rounded, color: AppTheme.primary, size: 24),
                    label: 'Memories',
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, child) {
          final index = _tabController.index;
          // Settle tab & Route tab - no screen-level FAB needed
          if (index == 2 && !trip.isSolo) {
            return const SizedBox.shrink();
          }
          final routeTabIndex = trip.isSolo ? 2 : 3;
          if (index == routeTabIndex) {
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
          } else if (index == 1) {
            // Tab 1: Bills & Splits / Budget tab
            icon = Icons.add_card_rounded;
            label = 'Add Bill';
            onPressed = () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => AddExpenseScreen(tripId: trip.id)),
              );
            };
          } else if (index == (_tabCount - 1)) {
            // Last Tab: Memories tab
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
