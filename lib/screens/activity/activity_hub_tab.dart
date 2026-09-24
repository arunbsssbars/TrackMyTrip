import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../trip_detail/trip_detail_screen.dart';

class ActivityHubTab extends ConsumerStatefulWidget {
  const ActivityHubTab({super.key});

  @override
  ConsumerState<ActivityHubTab> createState() => _ActivityHubTabState();
}

class _ActivityHubTabState extends ConsumerState<ActivityHubTab> {
  int _selectedFilter = 0; // 0: All, 1: Invitations, 2: Alerts & Activity
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;
  String _searchQuery = '';
  final Set<String> _collapsedDates = {};

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
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

  void _confirmSendSos(BuildContext context) {
    final currentTrip = ref.read(currentTripProvider);
    final currentUser = UserService.getCurrentUser();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Broadcast SOS?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ],
        ),
        content: const Text(
          'This will immediately broadcast an Emergency SOS alert with your live GPS location to all trip companions.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.emergency_rounded, size: 18),
            label: const Text('SEND SOS NOW'),
            onPressed: () {
              Navigator.of(ctx).pop();

              ref.read(proximityAlertServiceProvider).triggerEmergencySos(
                tripId: currentTrip?.id ?? 'trip_general',
                memberId: currentUser.id,
                memberName: currentUser.displayName,
                lat: currentUser.latitude ?? 28.6139,
                lng: currentUser.longitude ?? 77.2090,
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🚨 Emergency SOS broadcasted to all companions!'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getDateHeader(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (itemDate == today) {
      return 'Today';
    } else if (itemDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormatter.formatShortDate(timestamp);
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
    final int totalUnread = unreadInvitesTab + unreadActivityTab;

    final listItems = _buildListItems(
      pendingInvites: pendingInvites,
      alerts: relevantAlerts,
      trips: userTrips,
      selectedFilter: _selectedFilter,
      searchQuery: _searchQuery,
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.notifications_active_rounded, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Activity & Alerts',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
          // Emergency SOS Icon with text inside (Point 12)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SosBadgeIcon(
              size: 32,
              onTap: () => _confirmSendSos(context),
            ),
          ),
          if (relevantAlerts.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(proximityAlertServiceProvider).markAllAsRead(),
              child: const Text('Read All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(width: 4),
        ],
      ),
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          // Horizontally Scrollable Filter Chips (Fixes Point 8 overflow)
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
                  _buildFilterChip('Invitations', 1, unreadInvitesTab),
                  const SizedBox(width: 8),
                  _buildFilterChip('Alerts & Activity', 2, unreadActivityTab),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Activity List with Swiping & Collapsible Date Sections
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.read(invitationProvider.notifier).fetchPendingInvitationsFromCloud();
                ref.read(tripListProvider.notifier).reload();
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: listItems.length,
                itemBuilder: (context, index) {
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
                  } else if (item is _AlertCardItem) {
                    return _buildAlertCard(context, item.alert, isDark, trip: item.trip);
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
  }) {
    final List<_ActivityListItem> items = [];

    // Filter pending invites by search
    final filteredInvites = pendingInvites.where((inv) {
      if (searchQuery.isEmpty) return true;
      return inv.tripTitle.toLowerCase().contains(searchQuery) ||
          inv.inviterName.toLowerCase().contains(searchQuery);
    }).toList();

    // Show pending invites in "All" (0) and "Invitations" (1)
    if ((selectedFilter == 0 || selectedFilter == 1) && filteredInvites.isNotEmpty) {
      items.add(_PendingInvitesHeaderItem(filteredInvites.length));
      for (final inv in filteredInvites) {
        items.add(_PendingInviteCardItem(inv));
      }
    }

    // Filter alerts by tab and search
    final filteredAlerts = alerts.where((alert) {
      final isInviteAlert = alert.type == AlertType.invitation ||
          alert.type == AlertType.invitationAccepted ||
          alert.type == AlertType.invitationRejected;

      if (selectedFilter == 1 && !isInviteAlert) {
        return false;
      }
      if (selectedFilter == 2 && isInviteAlert) {
        return false;
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

    // Strict reverse chronological order (Points 2 & 5: most recent first)
    filteredAlerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (filteredAlerts.isEmpty && filteredInvites.isEmpty) {
      if (searchQuery.isNotEmpty) {
        items.add(_EmptyStateItem(
          title: 'No matching activities',
          message: 'Try searching with another keyword or clear the search filter.',
          icon: Icons.search_off_rounded,
        ));
      } else if (selectedFilter == 1) {
        items.add(_EmptyStateItem(
          title: 'No pending trip invitations',
          message: 'When friends invite you to a journey, they will appear here.',
          icon: Icons.mark_email_read_rounded,
        ));
      } else {
        items.add(_EmptyStateItem(
          title: 'No new alerts or updates',
          message: 'Trip activity, invitations, and proximity alerts will appear here.',
          icon: Icons.notifications_none_rounded,
        ));
      }
      return items;
    }

    // Group date-wise with most recent dates first (Point 6)
    final Map<String, List<ProximityAlert>> dateGroups = {};
    final Map<String, String> dateLabels = {};

    for (final alert in filteredAlerts) {
      final dateKey = '${alert.timestamp.year}-${alert.timestamp.month.toString().padLeft(2, '0')}-${alert.timestamp.day.toString().padLeft(2, '0')}';
      if (!dateGroups.containsKey(dateKey)) {
        dateGroups[dateKey] = [];
        dateLabels[dateKey] = _getDateHeader(alert.timestamp);
      }
      dateGroups[dateKey]!.add(alert);
    }

    for (final entry in dateGroups.entries) {
      final dateKey = entry.key;
      final groupAlerts = entry.value;
      final dateLabel = dateLabels[dateKey] ?? dateKey;
      final isCollapsed = _collapsedDates.contains(dateKey);

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

  Widget _buildDateHeader(_DateHeaderItem item, bool isDark) {
    return InkWell(
      onTap: () {
        setState(() {
          if (_collapsedDates.contains(item.dateKey)) {
            _collapsedDates.remove(item.dateKey);
          } else {
            _collapsedDates.add(item.dateKey);
          }
        });
      },
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
            Text(
              item.dateLabel,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const Spacer(),
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
                      'Invited by ${inv.inviterName}',
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
        icon = Icons.receipt_long_rounded;
        color = Colors.indigo;
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
    final isAcceptedInvite = alert.type == AlertType.invitationAccepted ||
        (alert.type == AlertType.invitation && (trip?.hasMember(currentUser.id, currentUser.email) ?? false));

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
        ref.read(proximityAlertServiceProvider).deleteAlert(alert.id);
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
          if (alert.tripId.isNotEmpty && alert.tripId != 'trip_general') {
            final tripExists = ref.read(tripListProvider).any((t) => t.id == alert.tripId);
            if (tripExists) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: alert.tripId)),
              );
            }
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: alert.isRead ? (isDark ? Colors.white10 : const Color(0xFFE2E8F0)) : color.withAlpha(90),
              width: alert.isRead ? 0.8 : 1.4,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            style: TextStyle(
                              fontWeight: alert.isRead ? FontWeight.w600 : FontWeight.w800,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Status badge (Point 3: Accepted vs Received vs Sent)
                        if (isAcceptedInvite)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF10B981).withAlpha(80)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 9, color: Color(0xFF10B981)),
                                SizedBox(width: 2),
                                Text('ACCEPTED', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                              ],
                            ),
                          )
                        else if (isSender)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blueGrey.withAlpha(60)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_outward_rounded, size: 9, color: Colors.blueGrey),
                                SizedBox(width: 2),
                                Text('SENT', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.teal.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.teal.withAlpha(60)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_downward_rounded, size: 9, color: Colors.teal),
                                SizedBox(width: 2),
                                Text('RECEIVED', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.teal)),
                              ],
                            ),
                          ),
                        const SizedBox(width: 6),
                        Text(
                          _formatTime(alert.timestamp),
                          style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      displayMessage,
                      style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[300] : const Color(0xFF475569)),
                    ),
                    if (trip != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          trip.title,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          ),
                        ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60, bottom: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 52, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                item.message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}';
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

class _AlertCardItem extends _ActivityListItem {
  final ProximityAlert alert;
  final Trip? trip;
  _AlertCardItem(this.alert, [this.trip]);
}

class _EmptyStateItem extends _ActivityListItem {
  final String title;
  final String message;
  final IconData icon;
  _EmptyStateItem({required this.title, required this.message, required this.icon});
}
