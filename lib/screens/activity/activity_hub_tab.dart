import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design_system/design_system.dart';
import '../../core/services/proximity_alert_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/notification_formatter.dart';
import '../../models/proximity_alert.dart';
import '../../models/trip.dart';
import '../../models/trip_invitation.dart';
import '../../providers/invitation_provider.dart';
import '../../providers/trip_provider.dart';
import '../common/sos_badge_icon.dart';
import '../common/user_avatar.dart';
import '../notifications/notification_center_sheet.dart';
import '../trip_detail/trip_detail_screen.dart';
import '../../core/utils/page_transitions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/expense_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../trip_detail/audit_log_sheet.dart';
import '../../widgets/expense_detail_sheet.dart';

class ActivityHubTab extends ConsumerStatefulWidget {
  const ActivityHubTab({super.key});

  @override
  ConsumerState<ActivityHubTab> createState() => _ActivityHubTabState();
}

class _ActivityHubTabState extends ConsumerState<ActivityHubTab> {
  int _selectedFilter = 0; // 0: All, 1: Alerts & Activity, 2: Invitations
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;
  String _searchQuery = '';
  bool _groupByTrip = false;
  bool _unreadOnly = false;
  final Set<String> _manuallyExpandedDates = {};
  final Set<String> _manuallyCollapsedDates = {};
  final Set<String> _collapsedTrips = {};
  final Set<String> _collapsedMonths = {};
  final ScrollController _scrollController = ScrollController();
  int _displayedLimit = 25;
  bool _showJumpToLatest = false;

  bool _isDateCollapsed(String dateKey) {
    // Check if the date is within the last 7 days
    try {
      final parts = dateKey.split('-');
      if (parts.length == 3) {
        final parsedDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final diffDays = today.difference(parsedDate).inDays;
        // If within 7 days, it's expanded by default unless manually collapsed
        if (diffDays >= 0 && diffDays <= 7) {
          return _manuallyCollapsedDates.contains(dateKey);
        }
      }
    } catch (_) {}

    // Older than 7 days: collapsed by default unless manually expanded
    return !_manuallyExpandedDates.contains(dateKey);
  }

  void _toggleDate(String dateKey) {
    setState(() {
      bool isRecent = false;
      try {
        final parts = dateKey.split('-');
        if (parts.length == 3) {
          final parsedDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final diffDays = today.difference(parsedDate).inDays;
          if (diffDays >= 0 && diffDays <= 7) {
            isRecent = true;
          }
        }
      } catch (_) {}

      if (isRecent) {
        if (_manuallyCollapsedDates.contains(dateKey)) {
          _manuallyCollapsedDates.remove(dateKey);
        } else {
          _manuallyCollapsedDates.add(dateKey);
        }
      } else {
        if (_manuallyExpandedDates.contains(dateKey)) {
          _manuallyExpandedDates.remove(dateKey);
        } else {
          _manuallyExpandedDates.add(dateKey);
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      if (mounted) setState(() => _displayedLimit += 20);
    }
    final shouldShow = pos.pixels > 300;
    if (shouldShow != _showJumpToLatest && mounted) {
      setState(() => _showJumpToLatest = shouldShow);
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = value.trim().toLowerCase();
        });
      }
    });
  }

  void _confirmClearAll(BuildContext context) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Clear All Notifications?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: const Text(
          'This will clear your activity and notification inbox. All financial ledgers, trips, bills, and trust audit trail history remain permanently preserved.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(proximityAlertServiceProvider).clearAll();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✓ All notifications cleared'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _confirmClearTripAlerts(BuildContext context, String tripId, String tripTitle) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Clear $tripTitle?',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          'This will clear all notifications and activity logs for "$tripTitle". All expenses, routes, and memories remain completely intact.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(proximityAlertServiceProvider).clearAlertsForTrip(tripId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✓ Activity cleared for $tripTitle'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _callCompanion(BuildContext context, String senderId, {Trip? trip, String? senderName}) async {
    HapticFeedback.lightImpact();
    String? phone;
    if (trip != null) {
      phone = trip.members.where((m) => m.id == senderId).firstOrNull?.phoneNumber?.trim();
    }
    if (phone == null || phone.isEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(senderId).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          phone = (data['phone'] as String? ?? data['phoneNumber'] as String? ?? data['mobile'] as String?)?.trim();
        }
      } catch (_) {}
    }
    if (phone != null && phone.isNotEmpty) {
      final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
      final uri = Uri.parse('tel:$clean');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(phone != null && phone.isNotEmpty 
              ? 'Could not open phone dialer for $phone'
              : 'No phone number registered for ${senderName ?? "this member"}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _navigateToAlert(BuildContext context, ProximityAlert alert, {Trip? trip}) async {
    HapticFeedback.lightImpact();

    // 1. Bill / Expense Deep-Linking
    if (alert.itemType == 'bill' || alert.type == AlertType.billAdded || alert.type == AlertType.billUpdated) {
      final matchingTrip = trip ?? ref.read(tripListProvider).where((t) => t.id == alert.tripId).firstOrNull;
      if (matchingTrip != null) {
        final allExpenses = ref.read(allExpensesProvider);
        final billId = alert.itemId ?? (alert.id.startsWith('alert_exp_') ? alert.id.replaceFirst('alert_exp_', '') : null);
        final expense = allExpenses.where((e) => e.tripId == matchingTrip.id && (e.id == billId || (billId != null && e.id.contains(billId)))).firstOrNull;

        if (expense != null) {
          ExpenseDetailSheet.show(context, ref, matchingTrip, expense);
          return;
        } else {
          _showDeletedItemDialog(
            context: context,
            matchingTrip: matchingTrip,
            itemType: 'Bill / Expense',
            title: alert.title,
            message: 'This bill was deleted or removed from "${matchingTrip.title}" by a companion.',
          );
          return;
        }
      }
    }

    // 2. Waypoint / Stop Deep-Linking
    if (alert.itemType == 'stop' || alert.type == AlertType.stoppageAdded || alert.type == AlertType.stoppageArrival || alert.type == AlertType.stoppageDeparture) {
      final matchingTrip = trip ?? ref.read(tripListProvider).where((t) => t.id == alert.tripId).firstOrNull;
      if (matchingTrip != null) {
        final allStoppages = ref.read(allStoppagesProvider);
        final stop = allStoppages.where((s) => s.tripId == matchingTrip.id && (s.id == alert.itemId || alert.message.contains(s.name))).firstOrNull;

        if (stop != null) {
          ref.read(selectedTripIdProvider.notifier).state = matchingTrip.id;
          AppNavigator.push(context, TripDetailScreen(tripId: matchingTrip.id, initialTabIndex: 0));
          return;
        } else {
          _showDeletedItemDialog(
            context: context,
            matchingTrip: matchingTrip,
            itemType: 'Waypoint Stop',
            title: alert.title,
            message: 'This waypoint was removed from the itinerary by a companion.',
          );
          return;
        }
      }
    }

    // 3. Settlement Deep-Linking
    if (alert.itemType == 'settlement' || alert.type == AlertType.settlementRecorded) {
      final matchingTrip = trip ?? ref.read(tripListProvider).where((t) => t.id == alert.tripId).firstOrNull;
      if (matchingTrip != null) {
        ref.read(selectedTripIdProvider.notifier).state = matchingTrip.id;
        AppNavigator.push(context, TripDetailScreen(tripId: matchingTrip.id, initialTabIndex: matchingTrip.isSolo ? 3 : 4));
        return;
      }
    }

    // 4. Coordinates / SOS Deep-Linking
    if (alert.latitude != null && alert.longitude != null) {
      // If linked to an active trip, navigate in-app to route map tab
      if (alert.tripId.isNotEmpty && alert.tripId != 'trip_general') {
        final matchingTrip = trip ?? ref.read(tripListProvider).where((t) => t.id == alert.tripId).firstOrNull;
        if (matchingTrip != null) {
          ref.read(selectedTripIdProvider.notifier).state = matchingTrip.id;
          AppNavigator.push(context, TripDetailScreen(tripId: matchingTrip.id, initialTabIndex: 1));
          return;
        }
      }
      // External map fallback
      final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${alert.latitude},${alert.longitude}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _showDeletedItemDialog({
    required BuildContext context,
    Trip? matchingTrip,
    required String itemType,
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$itemType No Longer Available',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 13.5)),
            const SizedBox(height: 10),
            const Text(
              'A companion may have removed this item. You can inspect all modifications and audit records in Trust History.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
          ),
          if (matchingTrip != null)
            FilledButton.icon(
              icon: const Icon(Icons.history_rounded, size: 16),
              label: const Text('View Trust History'),
              onPressed: () {
                Navigator.of(ctx).pop();
                AuditLogSheet.show(context, matchingTrip);
              },
            ),
        ],
      ),
    );
  }

  String _getDateHeader(DateTime timestamp) {
    final local = timestamp.isUtc ? timestamp.toLocal() : timestamp;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(local.year, local.month, local.day);

    if (itemDate == today) {
      return 'Today';
    } else if (itemDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormatter.formatShortDate(local);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alertService = ref.watch(proximityAlertServiceProvider);

    // Audience-filtered relevant alerts
    final relevantAlerts = alertService.getRelevantAlerts();
    final pendingInvites = ref.watch(invitationProvider);
    final userTrips = ref.watch(tripListProvider);

    // Calculate unread counts per tab
    final invitationAlerts = relevantAlerts.where((a) =>
      a.type == AlertType.invitation ||
      a.type == AlertType.invitationAccepted ||
      a.type == AlertType.invitationRejected
    ).toList();
    final activityAlerts = relevantAlerts.where((a) =>
      a.type != AlertType.invitation &&
      a.type != AlertType.invitationAccepted &&
      a.type != AlertType.invitationRejected
    ).toList();

    final int unreadInvitesTab = pendingInvites.length + invitationAlerts.where((a) => !a.isRead).length;
    final int unreadActivityTab = activityAlerts.where((a) => !a.isRead).length;
    final int unreadBillsTab = relevantAlerts.where((a) => !a.isRead && (a.itemType == 'bill' || a.itemType == 'settlement' || a.type == AlertType.billAdded || a.type == AlertType.settlementRecorded)).length;
    final int unreadStopsTab = relevantAlerts.where((a) => !a.isRead && (a.itemType == 'stop' || a.type == AlertType.stoppageAdded)).length;
    final int unreadMemoriesTab = relevantAlerts.where((a) => !a.isRead && (a.itemType == 'memory' || a.type == AlertType.memoryAdded)).length;
    final int unreadAuditsTab = relevantAlerts.where((a) => !a.isRead && (a.itemType == 'audit' || a.itemType == 'trust' || a.type == AlertType.tripReopened || a.type == AlertType.sosEmergency)).length;
    final int totalUnread = unreadInvitesTab + unreadActivityTab;

    final listItems = _buildListItems(
      pendingInvites: pendingInvites,
      alerts: relevantAlerts,
      trips: userTrips,
      selectedFilter: _selectedFilter,
      searchQuery: _searchQuery,
      unreadOnly: _unreadOnly,
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        titleSpacing: 16,
        title: const Text(
          'Activity & Alerts',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.3),
        ),
        actions: [
          // Banner Notifications Mute / Unmute Toggle (Point 7)
          IconButton(
            tooltip: alertService.inAppBannersEnabled ? 'Banner notifications: ON' : 'Banner notifications: OFF',
            icon: Icon(
              alertService.inAppBannersEnabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
              size: 21,
              color: alertService.inAppBannersEnabled ? AppTheme.primary : Colors.grey,
            ),
            onPressed: () {
              final nextState = !alertService.inAppBannersEnabled;
              ref.read(proximityAlertServiceProvider).toggleInAppBanners(nextState);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(nextState ? 'Banner notifications enabled' : 'Banner notifications muted (silent in Activity tab)'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          // Emergency SOS Icon (Unified across all screens)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SosBadgeIcon(
              size: 30,
              onTap: () => NotificationCenterSheet.show(context),
            ),
          ),
          if (relevantAlerts.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.done_all_rounded, size: 21, color: AppTheme.primary),
              tooltip: 'Mark all as read',
              onPressed: () => ref.read(proximityAlertServiceProvider).markAllAsRead(),
            ),
            IconButton(
              icon: const Icon(Icons.playlist_remove_rounded, size: 22, color: Colors.red),
              tooltip: 'Clear all notifications',
              onPressed: () => _confirmClearAll(context),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: _showJumpToLatest
          ? FloatingActionButton.extended(
              heroTag: 'activity_jump_latest',
              onPressed: () {
                HapticFeedback.selectionClick();
                _scrollController.animateTo(
                  0,
                  duration: AppMotion.duration(context, const Duration(milliseconds: 400)),
                  curve: Curves.easeOutCubic,
                );
              },
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.keyboard_double_arrow_up_rounded, size: 18),
              label: const Text('Latest', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            )
          : null,
      body: Column(
        children: [
          // Debounced Search Bar
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search by trip, companion, or event...',
                  hintStyle: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.grey),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          // Horizontally Scrollable Filter Chips + Grouping Toggle (Points 12 & 13)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFilterChip('All', 0, totalUnread),
                  const SizedBox(width: 8),
                  _buildUnreadToggleChip(totalUnread),
                  const SizedBox(width: 8),
                  // Grouping & Sort Mode at Second Place (Point 2)
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _groupByTrip = !_groupByTrip);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(isDark ? 35 : 20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primary.withAlpha(isDark ? 150 : 100),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _groupByTrip ? Icons.near_me_rounded : Icons.calendar_month_rounded,
                            size: 13,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _groupByTrip ? 'Sort: Trip-wise' : 'Sort: Date-wise',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.swap_horiz_rounded, size: 14, color: AppTheme.primary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip('Alerts & Activity', 1, unreadActivityTab),
                  const SizedBox(width: 8),
                  _buildFilterChip('Invitations', 2, unreadInvitesTab),
                  const SizedBox(width: 8),
                  _buildFilterChip('Bills', 3, unreadBillsTab),
                  const SizedBox(width: 8),
                  _buildFilterChip('Stops', 4, unreadStopsTab),
                  const SizedBox(width: 8),
                  _buildFilterChip('Memories', 5, unreadMemoriesTab),
                  const SizedBox(width: 8),
                  _buildFilterChip('Audit Logs', 6, unreadAuditsTab),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Activity List with Swiping & Collapsible Date / Trip Sections
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.read(invitationProvider.notifier).fetchPendingInvitationsFromCloud();
                ref.read(tripListProvider.notifier).reload();
              },
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: (listItems.length > _displayedLimit) ? (_displayedLimit + 1) : listItems.length,
                itemBuilder: (context, index) {
                  if (index >= _displayedLimit) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text(
                          'Showing $_displayedLimit of ${listItems.length} activities • Scroll for more',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF94A3B8)),
                        ),
                      ),
                    );
                  }
                  final item = listItems[index];
                  if (item is _PendingInvitesHeaderItem) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.mail_rounded, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Pending Trip Invitations (${item.count})',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  } else if (item is _PendingInviteCardItem) {
                    return _buildInviteCard(context, item.invitation, isDark);
                  } else if (item is _DateHeaderItem) {
                    return _buildDateHeader(item, isDark);
                  } else if (item is _MonthHeaderItem) {
                    return _buildMonthHeader(item, isDark);
                  } else if (item is _TripHeaderItem) {
                    return _buildTripHeader(item, isDark);
                  } else if (item is _AlertCardItem) {
                    return Dismissible(
                      key: Key('alert_dismiss_${item.alert.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(220),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 18),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Dismiss',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                          ],
                        ),
                      ),
                      onDismissed: (_) {
                        HapticFeedback.mediumImpact();
                        ref.read(proximityAlertServiceProvider).deleteAlert(item.alert.id, tripId: item.alert.tripId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Dismissed: "${item.alert.title}"'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: _buildAlertCard(context, item.alert, isDark, trip: item.trip),
                    );
                  } else if (item is _EmptyStateItem) {
                    return _buildEmptyState(item, isDark);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_ActivityListItem> _buildListItems({
    required List<TripInvitation> pendingInvites,
    required List<ProximityAlert> alerts,
    required List<Trip> trips,
    required int selectedFilter,
    required String searchQuery,
    bool unreadOnly = false,
  }) {
    final List<_ActivityListItem> items = [];

    // Filter pending invites by search
    final filteredInvites = pendingInvites.where((inv) {
      if (searchQuery.isEmpty) return true;
      return inv.tripTitle.toLowerCase().contains(searchQuery) ||
          inv.inviterName.toLowerCase().contains(searchQuery);
    }).toList();

    // Show pending invites at the top under Invitations tab (2) and All tab (0)
    if ((selectedFilter == 0 || selectedFilter == 2) && filteredInvites.isNotEmpty) {
      items.add(_PendingInvitesHeaderItem(filteredInvites.length));
      for (final inv in filteredInvites) {
        items.add(_PendingInviteCardItem(inv));
      }
    }

    // Deduplicate alerts by unique id
    final seenIds = <String>{};
    final uniqueAlerts = <ProximityAlert>[];
    for (final alert in alerts) {
      if (seenIds.add(alert.id)) {
        uniqueAlerts.add(alert);
      }
    }

    // Filter generalized activities by tab and search
    final filteredAlerts = uniqueAlerts.where((alert) {
      if (unreadOnly && alert.isRead) {
        return false;
      }
      final isInviteAlert = alert.type == AlertType.invitation ||
          alert.type == AlertType.invitationAccepted ||
          alert.type == AlertType.invitationRejected;

      if (selectedFilter == 1 && isInviteAlert) {
        return false;
      }
      if (selectedFilter == 2 && !isInviteAlert) {
        return false;
      }
      if (selectedFilter == 3) {
        final isBill = alert.itemType == 'bill' ||
            alert.itemType == 'settlement' ||
            alert.type == AlertType.billAdded ||
            alert.type == AlertType.billUpdated ||
            alert.type == AlertType.billDeleted ||
            alert.type == AlertType.settlementRecorded;
        if (!isBill) return false;
      }
      if (selectedFilter == 4) {
        final isStop = alert.itemType == 'stop' ||
            alert.type == AlertType.stoppageAdded ||
            alert.type == AlertType.stoppageArrival ||
            alert.type == AlertType.stoppageDeparture;
        if (!isStop) return false;
      }
      if (selectedFilter == 5) {
        final isMemory = alert.itemType == 'memory' || alert.type == AlertType.memoryAdded;
        if (!isMemory) return false;
      }
      if (selectedFilter == 6) {
        final isAudit = alert.itemType == 'audit' ||
            alert.itemType == 'trust' ||
            alert.type == AlertType.tripReopened ||
            alert.type == AlertType.sosEmergency ||
            alert.type == AlertType.general;
        if (!isAudit) return false;
      }

      if (searchQuery.isNotEmpty) {
        final matchesTitle = alert.title.toLowerCase().contains(searchQuery);
        final matchesMessage = alert.message.toLowerCase().contains(searchQuery);
        final matchesSender = alert.senderName.toLowerCase().contains(searchQuery);

        String tripName = '';
        if (alert.tripId.isNotEmpty && alert.tripId != 'trip_general') {
          final matchTrip = trips.where((t) => t.id == alert.tripId).firstOrNull;
          if (matchTrip != null) tripName = matchTrip.title.toLowerCase();
        }
        final matchesTrip = tripName.contains(searchQuery);

        if (!matchesTitle && !matchesMessage && !matchesSender && !matchesTrip) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort in strict reverse chronological order
    filteredAlerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (filteredAlerts.isEmpty && filteredInvites.isEmpty) {
      if (searchQuery.isNotEmpty) {
        items.add(_EmptyStateItem(
          title: 'No matching activities',
          message: 'Try searching with another keyword or clear the search filter.',
          icon: Icons.search_off_rounded,
        ));
      } else if (unreadOnly) {
        items.add(_EmptyStateItem(
          title: 'No unread notifications',
          message: "You're all caught up! Toggle off 'Unread' to view all activity history.",
          icon: Icons.mark_email_read_rounded,
        ));
      } else if (selectedFilter == 2) {
        items.add(_EmptyStateItem(
          title: 'No pending trip invitations',
          message: 'When friends invite you to a journey, they will appear here.',
          icon: Icons.mark_email_read_rounded,
        ));
      } else {
        items.add(_EmptyStateItem(
          title: 'No new alerts or updates',
          message: 'Trip activity, bills, settlements, budget changes, and proximity alerts will appear here.',
          icon: Icons.notifications_none_rounded,
        ));
      }
      return items;
    }

    if (_groupByTrip) {
      // Group trip-wise (Sort trips start date descending & group under collapsible Month/Year sections)
      final Map<String, List<ProximityAlert>> tripGroups = {};
      final List<ProximityAlert> generalEntries = [];

      for (final alert in filteredAlerts) {
        if (alert.tripId.isNotEmpty && alert.tripId != 'trip_general') {
          tripGroups.putIfAbsent(alert.tripId, () => []).add(alert);
        } else {
          generalEntries.add(alert);
        }
      }

      // Collect all trips that have alerts, sorted by startDate descending
      final relevantTrips = trips.where((t) => tripGroups.containsKey(t.id)).toList()
        ..sort((a, b) => b.startDate.compareTo(a.startDate));

      for (final tripId in tripGroups.keys) {
        if (!relevantTrips.any((t) => t.id == tripId)) {
          final dummy = trips.where((t) => t.id == tripId).firstOrNull;
          if (dummy != null) relevantTrips.add(dummy);
        }
      }

      // Group trips by Month/Year
      final Map<String, List<Trip>> monthGroups = {};
      final Map<String, String> monthLabels = {};
      for (final t in relevantTrips) {
        final monthKey = '${t.startDate.year}-${t.startDate.month.toString().padLeft(2, '0')}';
        monthGroups.putIfAbsent(monthKey, () => []).add(t);
        monthLabels[monthKey] = DateFormatter.formatMonthYear(t.startDate);
      }

      for (final monthEntry in monthGroups.entries) {
        final monthKey = monthEntry.key;
        final monthTripList = monthEntry.value;
        final monthLabel = monthLabels[monthKey] ?? monthKey;
        final isMonthCollapsed = _collapsedMonths.contains(monthKey);

        final totalAlertsInMonth = monthTripList.fold<int>(
          0,
          (acc, t) => acc + (tripGroups[t.id]?.length ?? 0),
        );

        items.add(_MonthHeaderItem(
          monthLabel: monthLabel,
          monthKey: monthKey,
          tripCount: monthTripList.length,
          alertCount: totalAlertsInMonth,
          isCollapsed: isMonthCollapsed,
        ));

        if (!isMonthCollapsed) {
          for (final t in monthTripList) {
            final groupAlerts = tripGroups[t.id] ?? [];
            final isTripCollapsed = _collapsedTrips.contains(t.id);

            items.add(_TripHeaderItem(
              tripTitle: t.title,
              tripId: t.id,
              alertCount: groupAlerts.length,
              isCollapsed: isTripCollapsed,
            ));

            if (!isTripCollapsed) {
              for (final alert in groupAlerts) {
                items.add(_AlertCardItem(alert, t));
              }
            }
          }
        }
      }

      if (generalEntries.isNotEmpty) {
        final isCollapsed = _collapsedTrips.contains('general_system');
        items.add(_TripHeaderItem(
          tripTitle: 'General & System Updates',
          tripId: 'general_system',
          alertCount: generalEntries.length,
          isCollapsed: isCollapsed,
        ));

        if (!isCollapsed) {
          for (final alert in generalEntries) {
            items.add(_AlertCardItem(alert, null));
          }
        }
      }

      return items;
    }

    // Group date-wise with most recent dates first
    final Map<String, List<ProximityAlert>> dateGroups = {};
    final Map<String, String> dateLabels = {};

    for (final alert in filteredAlerts) {
      final dt = alert.timestamp.isUtc ? alert.timestamp.toLocal() : alert.timestamp;
      final dateKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      if (!dateGroups.containsKey(dateKey)) {
        dateGroups[dateKey] = [];
        dateLabels[dateKey] = _getDateHeader(dt);
      }
      dateGroups[dateKey]!.add(alert);
    }

    for (final entry in dateGroups.entries) {
      final dateKey = entry.key;
      final groupAlerts = entry.value;
      final dateLabel = dateLabels[dateKey] ?? dateKey;
      final isCollapsed = _isDateCollapsed(dateKey);

      items.add(_DateHeaderItem(
        dateLabel: dateLabel,
        dateKey: dateKey,
        alertCount: groupAlerts.length,
        isCollapsed: isCollapsed,
      ));

      if (!isCollapsed) {
        for (final alert in groupAlerts) {
          final matchTrip = trips.where((t) => t.id == alert.tripId).firstOrNull;
          items.add(_AlertCardItem(alert, matchTrip));
        }
      }
    }

    return items;
  }

  Widget _buildUnreadToggleChip(int totalUnread) {
    return FilterChip(
      selected: _unreadOnly,
      showCheckmark: false,
      avatar: Icon(
        _unreadOnly ? Icons.mark_email_unread_rounded : Icons.mark_email_unread_outlined,
        size: 14,
        color: _unreadOnly ? Colors.white : AppTheme.primary,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Unread',
            style: TextStyle(
              fontSize: 12,
              fontWeight: _unreadOnly ? FontWeight.bold : FontWeight.w600,
              color: _unreadOnly ? Colors.white : null,
            ),
          ),
          if (totalUnread > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: _unreadOnly ? Colors.white : AppTheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$totalUnread',
                style: TextStyle(
                  color: _unreadOnly ? AppTheme.primary : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
      selectedColor: AppTheme.primary,
      backgroundColor: Colors.transparent,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: _unreadOnly ? AppTheme.primary : Colors.grey.withAlpha(60),
        ),
      ),
      onSelected: (val) {
        HapticFeedback.selectionClick();
        setState(() => _unreadOnly = val);
      },
    );
  }

  Widget _buildFilterChip(String label, int index, int badgeCount) {
    final isSelected = _selectedFilter == index;
    return ChoiceChip(
      showCheckmark: false,
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedFilter = index;
        });
      },
      selectedColor: AppTheme.primary,
      backgroundColor: Colors.transparent,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppTheme.primary : Colors.grey.withAlpha(60),
        ),
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : null,
            ),
          ),
          if (badgeCount > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : AppTheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgeCount',
                style: TextStyle(
                  color: isSelected ? AppTheme.primary : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 9.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthHeader(_MonthHeaderItem item, bool isDark) {
    return InkWell(
      onTap: () {
        setState(() {
          if (_collapsedMonths.contains(item.monthKey)) {
            _collapsedMonths.remove(item.monthKey);
          } else {
            _collapsedMonths.add(item.monthKey);
          }
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(top: 14, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.date_range_rounded, size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(
              item.monthLabel,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${item.tripCount} trip${item.tripCount == 1 ? "" : "s"} • ${item.alertCount} events',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              item.isCollapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
              size: 20,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(_DateHeaderItem item, bool isDark) {
    return InkWell(
      onTap: () => _toggleDate(item.dateKey),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, size: 14, color: AppTheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (item.dateLabel.toLowerCase().contains('today'))
              Tooltip(
                message: 'Mark today as read',
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(proximityAlertServiceProvider).markAlertsAsReadForDate(DateTime.now());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✓ Marked today’s activities as read'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981).withAlpha(80), width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.done_all_rounded, size: 12, color: Color(0xFF059669)),
                        SizedBox(width: 3),
                        Text(
                          'Mark Read',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item.alertCount} events',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            Icon(
              item.isCollapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
              size: 18,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripHeader(_TripHeaderItem item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              if (_collapsedTrips.contains(item.tripId)) {
                _collapsedTrips.remove(item.tripId);
              } else {
                _collapsedTrips.add(item.tripId);
              }
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                const Icon(Icons.near_me_rounded, size: 15, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.tripTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item.alertCount} events',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                if (item.tripId != 'general_system') ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Clear ${item.tripTitle} activity',
                    child: InkWell(
                      onTap: () => _confirmClearTripAlerts(context, item.tripId, item.tripTitle),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_sweep_outlined,
                          size: 17,
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(
                  item.isCollapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                  size: 18,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInviteCard(BuildContext context, TripInvitation inv, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withAlpha(60), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withAlpha(isDark ? 30 : 15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primary.withAlpha(35),
                child: Text(
                  inv.inviterName.isNotEmpty ? inv.inviterName[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inv.tripTitle,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Invited by ${inv.inviterName} • ${DateFormatter.formatDateTime(inv.createdAt)}',
                      style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'INVITATION',
                  style: TextStyle(color: Colors.amber[800], fontSize: 9.5, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => ref.read(invitationProvider.notifier).declineInvitation(inv),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(color: Colors.grey.withAlpha(80)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Decline', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => ref.read(invitationProvider.notifier).acceptInvitation(inv),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Accept & Join', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, ProximityAlert alert, bool isDark, {Trip? trip}) {
    IconData icon;
    Color color;

    switch (alert.type) {
      case AlertType.sosEmergency:
        icon = Icons.emergency_rounded;
        color = Colors.red;
        break;
      case AlertType.companionStray:
        icon = Icons.radar_rounded;
        color = Colors.orange;
        break;
      case AlertType.stoppageArrival:
        icon = Icons.pin_drop_rounded;
        color = const Color(0xFF10B981);
        break;
      case AlertType.stoppageDeparture:
        icon = Icons.directions_walk_rounded;
        color = Colors.blue;
        break;
      case AlertType.invitation:
        icon = Icons.mail_outline_rounded;
        color = AppTheme.primary;
        break;
      case AlertType.invitationAccepted:
        icon = Icons.how_to_reg_rounded;
        color = const Color(0xFF10B981);
        break;
      case AlertType.invitationRejected:
        icon = Icons.person_off_rounded;
        color = Colors.redAccent;
        break;
      case AlertType.memberJoined:
        icon = Icons.person_add_alt_1_rounded;
        color = Colors.teal;
        break;
      case AlertType.memberLeft:
        icon = Icons.exit_to_app_rounded;
        color = Colors.deepOrange;
        break;
      case AlertType.billAdded:
      case AlertType.billUpdated:
      case AlertType.billDeleted:
        icon = alert.type == AlertType.billDeleted ? Icons.delete_outline_rounded : Icons.receipt_long_rounded;
        color = alert.type == AlertType.billDeleted ? Colors.red : Colors.indigo;
        break;
      case AlertType.settlementRecorded:
        icon = Icons.payments_rounded;
        color = const Color(0xFF10B981);
        break;
      case AlertType.memoryAdded:
        icon = Icons.photo_camera_rounded;
        color = Colors.purple;
        break;
      case AlertType.stoppageAdded:
        icon = Icons.add_location_alt_rounded;
        color = Colors.amber.shade800;
        break;
      case AlertType.locationShared:
        icon = Icons.my_location_rounded;
        color = Colors.blue;
        break;
      case AlertType.tripReopened:
        icon = Icons.restart_alt_rounded;
        color = const Color(0xFF0D9488);
        break;
      default:
        icon = Icons.notifications_rounded;
        color = AppTheme.primary;
        break;
    }

    final currentUser = UserService.getCurrentUser();
    final displayMessage = NotificationFormatter.formatMessage(
      alert,
      currentUserId: currentUser.id,
      currentUserName: currentUser.displayName,
      currentUserEmail: currentUser.email,
      currentUsername: currentUser.username,
    );

    final isSender = alert.senderMemberId == currentUser.id || alert.isOutgoing;
    final senderMember = (trip != null && alert.senderMemberId.isNotEmpty && alert.senderMemberId != 'system')
        ? trip.members.where((m) => m.id == alert.senderMemberId).firstOrNull
        : null;
    final isAcceptedInvite = alert.type == AlertType.invitationAccepted ||
        (alert.type == AlertType.invitation && (trip?.hasMember(currentUser.id, currentUser.email) ?? false));
    final nature = ActivityNature.fromAlertType(alert.type);

    double? displayAmount = alert.amount;
    String displayCurrency = alert.currency ?? trip?.defaultCurrency ?? 'INR';
    if (displayAmount == null && (alert.type == AlertType.billAdded || alert.type == AlertType.billUpdated)) {
      if (alert.itemId != null) {
        final exp = ref.read(allExpensesProvider).where((e) => e.id == alert.itemId).firstOrNull;
        if (exp != null) {
          displayAmount = exp.totalAmount;
          displayCurrency = exp.currency;
        }
      }
    }

    return Dismissible(
      key: ValueKey('activity_alert_${alert.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
            SizedBox(width: 4),
            Text('Dismiss', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
      onDismissed: (_) {
        ref.read(proximityAlertServiceProvider).deleteAlert(alert.id, tripId: alert.tripId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification dismissed'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (!alert.isRead) {
            ref.read(proximityAlertServiceProvider).markAsRead(alert.id);
          }
          final isDeleteAlert = alert.type == AlertType.billDeleted ||
              alert.title.toLowerCase().contains('delete') ||
              alert.message.toLowerCase().contains('deleted');
          if (isDeleteAlert) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.delete_forever_rounded, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Bill Deleted'),
                  ],
                ),
                content: Text(
                  '${alert.message}\n\nThis bill is no longer active in the ledger. Its historical details remain preserved in Trust History.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Understood'),
                  ),
                ],
              ),
            );
            return;
          }
          if (alert.tripId.isNotEmpty && alert.tripId != 'trip_general') {
            final matchingTrip = trip ?? ref.read(tripListProvider).where((t) => t.id == alert.tripId).firstOrNull;
            if (matchingTrip != null) {
              int targetTab = 0;
              if (alert.type == AlertType.billAdded || alert.type == AlertType.billUpdated) {
                targetTab = 3; // Bills / Budget tab
              } else if (alert.type == AlertType.tripReopened) {
                targetTab = 0; // Cockpit / Overview tab
              } else if (alert.type == AlertType.settlementRecorded) {
                targetTab = matchingTrip.isSolo ? 3 : 4; // Settle tab
              } else if (alert.type == AlertType.stoppageAdded || alert.type == AlertType.stoppageArrival || alert.type == AlertType.stoppageDeparture) {
                targetTab = 0; // Timeline / Stoppages tab
              } else if (alert.type == AlertType.locationShared || alert.type == AlertType.companionStray) {
                targetTab = 1; // Route Map tab
              } else if (alert.type == AlertType.memberJoined || alert.type == AlertType.memberLeft || alert.type == AlertType.invitationAccepted || alert.type == AlertType.invitation) {
                targetTab = 2; // Members tab
              } else if (alert.type == AlertType.memoryAdded) {
                targetTab = matchingTrip.isSolo ? 4 : 5; // Memories tab
              }
              ref.read(selectedTripIdProvider.notifier).state = matchingTrip.id;
              AppNavigator.push(context, TripDetailScreen(tripId: matchingTrip.id, initialTabIndex: targetTab));
            }
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: alert.isRead
                ? []
                : [
                    BoxShadow(
                      color: color.withAlpha(isDark ? 30 : 20),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
            border: Border.all(
              color: alert.isRead
                  ? (isDark ? Colors.white10 : const Color(0xFFE2E8F0))
                  : color.withAlpha(isDark ? 110 : 90),
              width: alert.isRead ? 0.8 : 1.4,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withAlpha(isDark ? 40 : 25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 19, color: color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 3,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: nature.color.withAlpha(25),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: nature.color.withAlpha(80), width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(nature.icon, size: 9, color: nature.color),
                                    const SizedBox(width: 2.5),
                                    Flexible(
                                      child: Text(
                                        nature.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          color: nature.color,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isAcceptedInvite)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withAlpha(25),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('ACCEPTED', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                )
                              else if (isSender)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.blueGrey.withAlpha(25),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('SENT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                ),
                              if (displayAmount != null && displayAmount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.withAlpha(isDark ? 45 : 25),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: Colors.indigo.withAlpha(isDark ? 90 : 60),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    '$displayCurrency ${displayAmount.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.indigo.shade200 : Colors.indigo.shade800,
                                    ),
                                  ),
                                ),
                              if (!isSender && senderMember != null && senderMember.name.trim().isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                                      width: 0.6,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      UserAvatar(
                                        name: senderMember.name,
                                        colorHex: senderMember.colorHex,
                                        size: 13,
                                        fontSize: 7,
                                      ),
                                      const SizedBox(width: 3.5),
                                      Flexible(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 60),
                                          child: Text(
                                            senderMember.name.split(' ').first,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (!alert.isRead) ...[
                              Container(
                                width: 6.5,
                                height: 6.5,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                            ],
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormatter.formatShortDate(alert.timestamp),
                                  maxLines: 1,
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: alert.isRead ? FontWeight.w600 : FontWeight.w700,
                                    color: alert.isRead
                                        ? (isDark ? Colors.grey[400] : const Color(0xFF94A3B8))
                                        : (isDark ? Colors.grey[200] : const Color(0xFF334155)),
                                  ),
                                ),
                                const SizedBox(height: 1.5),
                                Text(
                                  DateFormatter.formatTimeOnly(alert.timestamp),
                                  maxLines: 1,
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: alert.isRead ? FontWeight.w500 : FontWeight.w600,
                                    color: alert.isRead
                                        ? (isDark ? Colors.grey[500] : const Color(0xFF94A3B8))
                                        : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      NotificationFormatter.formatTitle(alert, currentUserId: currentUser.id),
                      style: TextStyle(
                        fontWeight: alert.isRead ? FontWeight.w600 : FontWeight.w800,
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      displayMessage,
                      style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[300] : const Color(0xFF475569)),
                    ),
                    if (alert.latitude != null && alert.longitude != null) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: (alert.type == AlertType.sosEmergency ? Colors.red : AppTheme.primary).withAlpha(isDark ? 30 : 15),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: (alert.type == AlertType.sosEmergency ? Colors.red : AppTheme.primary).withAlpha(isDark ? 60 : 35),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.my_location_rounded,
                              size: 10.5,
                              color: alert.type == AlertType.sosEmergency ? Colors.red : AppTheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '📍 ${alert.latitude!.toStringAsFixed(4)}, ${alert.longitude!.toStringAsFixed(4)}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                color: alert.type == AlertType.sosEmergency
                                    ? (isDark ? Colors.red[300] : Colors.red[800])
                                    : (isDark ? AppTheme.primaryLight : AppTheme.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (trip != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Trip: ${trip.title}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                    // Quick Action Buttons
                    if ((!isSender &&
                            ((alert.type == AlertType.sosEmergency || alert.type == AlertType.companionStray
                                    ? (alert.senderMemberId.isNotEmpty && alert.senderMemberId != 'system')
                                    : false) ||
                                (alert.latitude != null && alert.longitude != null))) ||
                        (alert.type == AlertType.stoppageAdded ||
                            alert.type == AlertType.stoppageArrival ||
                            alert.type == AlertType.stoppageDeparture ||
                            alert.type == AlertType.billAdded ||
                            alert.type == AlertType.billUpdated ||
                            alert.type == AlertType.memoryAdded)) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          // Bill Action Button
                          if (alert.type == AlertType.billAdded || alert.type == AlertType.billUpdated)
                            InkWell(
                              onTap: () {
                                if (trip != null) {
                                  ref.read(selectedTripIdProvider.notifier).state = trip.id;
                                  AppNavigator.push(context, TripDetailScreen(tripId: trip.id, initialTabIndex: 3));
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.withAlpha(isDark ? 35 : 20),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.indigo.withAlpha(isDark ? 90 : 60),
                                    width: 0.9,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.receipt_long_rounded, size: 13, color: Colors.indigo),
                                    const SizedBox(width: 4.5),
                                    Text(
                                      'View Bill',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.indigo.shade200 : Colors.indigo.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Memories Action Button
                          if (alert.type == AlertType.memoryAdded)
                            InkWell(
                              onTap: () {
                                if (trip != null) {
                                  ref.read(selectedTripIdProvider.notifier).state = trip.id;
                                  AppNavigator.push(context, TripDetailScreen(tripId: trip.id, initialTabIndex: trip.isSolo ? 4 : 5));
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withAlpha(isDark ? 35 : 20),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.purple.withAlpha(isDark ? 90 : 60),
                                    width: 0.9,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.photo_library_rounded, size: 13, color: Colors.purple),
                                    const SizedBox(width: 4.5),
                                    Text(
                                      'View Memories',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.purple.shade200 : Colors.purple.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Itinerary action button for stoppage & timeline alerts
                          if (alert.type == AlertType.stoppageAdded || alert.type == AlertType.stoppageArrival || alert.type == AlertType.stoppageDeparture)
                            InkWell(
                              onTap: () {
                                if (trip != null) {
                                  ref.read(selectedTripIdProvider.notifier).state = trip.id;
                                  AppNavigator.push(context, TripDetailScreen(tripId: trip.id, initialTabIndex: 0));
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade800.withAlpha(isDark ? 35 : 20),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.amber.shade800.withAlpha(isDark ? 90 : 60),
                                    width: 0.9,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.timeline_rounded, size: 13, color: Colors.amber.shade800),
                                    const SizedBox(width: 4.5),
                                    Text(
                                      'View Itinerary',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Call button: only for emergency-class alerts (SOS, stray)
                          if (!isSender &&
                              (alert.type == AlertType.sosEmergency || alert.type == AlertType.companionStray) &&
                              alert.senderMemberId.isNotEmpty && alert.senderMemberId != 'system')
                            InkWell(
                              onTap: () => _callCompanion(
                                context,
                                alert.senderMemberId,
                                trip: trip,
                                senderName: alert.senderName,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withAlpha(isDark ? 35 : 20),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF10B981).withAlpha(isDark ? 90 : 60),
                                    width: 0.9,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.phone_in_talk_rounded, size: 13, color: Color(0xFF10B981)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Call ${alert.senderName.isNotEmpty && alert.senderName != "Unknown Member" ? alert.senderName.split(" ").first : "Companion"}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (!isSender && alert.latitude != null && alert.longitude != null)
                            InkWell(
                              onTap: () => _navigateToAlert(context, alert, trip: trip),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0891B2).withAlpha(isDark ? 35 : 20),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF0891B2).withAlpha(isDark ? 90 : 60),
                                    width: 0.9,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.directions_rounded, size: 13, color: Color(0xFF0891B2)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Navigate',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0891B2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(_EmptyStateItem item, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 40),
      child: AppEmptyState(
        icon: item.icon,
        title: item.title,
        message: item.message,
      ),
    );
  }
}

sealed class _ActivityListItem {}

class _PendingInvitesHeaderItem extends _ActivityListItem {
  final int count;
  _PendingInvitesHeaderItem(this.count);
}

class _PendingInviteCardItem extends _ActivityListItem {
  final TripInvitation invitation;
  _PendingInviteCardItem(this.invitation);
}

class _DateHeaderItem extends _ActivityListItem {
  final String dateLabel;
  final String dateKey;
  final int alertCount;
  final bool isCollapsed;
  _DateHeaderItem({
    required this.dateLabel,
    required this.dateKey,
    required this.alertCount,
    required this.isCollapsed,
  });
}

class _TripHeaderItem extends _ActivityListItem {
  final String tripTitle;
  final String tripId;
  final int alertCount;
  final bool isCollapsed;
  _TripHeaderItem({
    required this.tripTitle,
    required this.tripId,
    required this.alertCount,
    required this.isCollapsed,
  });
}

class _AlertCardItem extends _ActivityListItem {
  final ProximityAlert alert;
  final Trip? trip;
  _AlertCardItem(this.alert, [this.trip]);
}

class _MonthHeaderItem extends _ActivityListItem {
  final String monthLabel;
  final String monthKey;
  final int tripCount;
  final int alertCount;
  final bool isCollapsed;
  _MonthHeaderItem({
    required this.monthLabel,
    required this.monthKey,
    required this.tripCount,
    required this.alertCount,
    required this.isCollapsed,
  });
}

class _EmptyStateItem extends _ActivityListItem {
  final String title;
  final String message;
  final IconData icon;
  _EmptyStateItem({required this.title, required this.message, required this.icon});
}

enum ActivityNature {
  safety('SAFETY ALERT', Icons.warning_amber_rounded, Color(0xFFEF4444)),
  finance('EXPENSE', Icons.receipt_long_rounded, Color(0xFF10B981)),
  itinerary('WAYPOINT', Icons.place_rounded, Color(0xFF3B82F6)),
  invitation('INVITATION', Icons.mail_rounded, Color(0xFF8B5CF6)),
  memory('MEMORY', Icons.photo_camera_rounded, Color(0xFFEC4899)),
  general('UPDATE', Icons.notifications_active_rounded, Color(0xFFF59E0B));

  final String label;
  final IconData icon;
  final Color color;

  const ActivityNature(this.label, this.icon, this.color);

  static ActivityNature fromAlertType(AlertType type) {
    switch (type) {
      case AlertType.sosEmergency:
      case AlertType.companionStray:
        return ActivityNature.safety;
      case AlertType.billAdded:
      case AlertType.billUpdated:
      case AlertType.billDeleted:
      case AlertType.settlementRecorded:
        return ActivityNature.finance;
      case AlertType.stoppageArrival:
      case AlertType.stoppageDeparture:
      case AlertType.stoppageAdded:
        return ActivityNature.itinerary;
      case AlertType.invitation:
      case AlertType.invitationAccepted:
      case AlertType.invitationRejected:
      case AlertType.memberJoined:
      case AlertType.memberLeft:
        return ActivityNature.invitation;
      case AlertType.memoryAdded:
        return ActivityNature.memory;
      case AlertType.locationShared:
      case AlertType.general:
      case AlertType.tripReopened:
        return ActivityNature.general;
    }
  }
}
