import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/proximity_alert_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/notification_formatter.dart';
import '../../models/proximity_alert.dart';
import '../../models/trip.dart';
import '../../providers/trip_provider.dart';
import '../trip_detail/trip_detail_screen.dart';
import '../../core/utils/page_transitions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/trip_guard_helper.dart';
import '../../providers/expense_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../trip_detail/audit_log_sheet.dart';

class NotificationCenterSheet extends ConsumerStatefulWidget {
  const NotificationCenterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationCenterSheet(),
    );
  }

  @override
  ConsumerState<NotificationCenterSheet> createState() => _NotificationCenterSheetState();
}

class _NotificationCenterSheetState extends ConsumerState<NotificationCenterSheet> {
  final ScrollController _scrollController = ScrollController();
  int _displayLimit = 15;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 150) {
      if (_displayLimit < 200) {
        setState(() {
          _displayLimit += 15;
        });
      }
    }
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
          if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
          ref.read(selectedTripIdProvider.notifier).state = matchingTrip.id;
          AppNavigator.push(context, TripDetailScreen(tripId: matchingTrip.id, initialTabIndex: 3));
          return;
        } else {
          // Bill was deleted or removed by a companion
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
          if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
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
        if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
        ref.read(selectedTripIdProvider.notifier).state = matchingTrip.id;
        AppNavigator.push(context, TripDetailScreen(tripId: matchingTrip.id, initialTabIndex: matchingTrip.isSolo ? 3 : 4));
        return;
      }
    }

    // 4. Trip Reopening Deep-Linking
    if (alert.type == AlertType.tripReopened) {
      final matchingTrip = trip ?? ref.read(tripListProvider).where((t) => t.id == alert.tripId).firstOrNull;
      if (matchingTrip != null) {
        if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
        ref.read(selectedTripIdProvider.notifier).state = matchingTrip.id;
        AppNavigator.push(context, TripDetailScreen(tripId: matchingTrip.id, initialTabIndex: 0));
        return;
      }
    }

    // 5. Memory Deep-Linking
    if (alert.itemType == 'memory' || alert.type == AlertType.memoryAdded) {
      final matchingTrip = trip ?? ref.read(tripListProvider).where((t) => t.id == alert.tripId).firstOrNull;
      if (matchingTrip != null) {
        if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
        ref.read(selectedTripIdProvider.notifier).state = matchingTrip.id;
        final memoryTabIndex = matchingTrip.isSolo ? 4 : 5;
        AppNavigator.push(context, TripDetailScreen(tripId: matchingTrip.id, initialTabIndex: memoryTabIndex));
        return;
      }
    }

    // 6. Member Join/Leave Deep-Linking
    if (alert.itemType == 'member' || alert.type == AlertType.memberJoined || alert.type == AlertType.memberLeft) {
      final matchingTrip = trip ?? ref.read(tripListProvider).where((t) => t.id == alert.tripId).firstOrNull;
      if (matchingTrip != null) {
        if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
        ref.read(selectedTripIdProvider.notifier).state = matchingTrip.id;
        AppNavigator.push(context, TripDetailScreen(tripId: matchingTrip.id, initialTabIndex: 2));
        return;
      }
    }

    // 5. Coordinates / SOS Deep-Linking
    if (alert.latitude != null && alert.longitude != null) {
      // If linked to an active trip, navigate in-app to route map tab
      if (alert.tripId.isNotEmpty && alert.tripId != 'trip_general') {
        final matchingTrip = trip ?? ref.read(tripListProvider).where((t) => t.id == alert.tripId).firstOrNull;
        if (matchingTrip != null) {
          if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop(); // dismiss sheet
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

  void _confirmSendSos(BuildContext context) async {
    final currentTrip = ref.read(currentTripProvider);
    final currentUser = UserService.getCurrentUser();

    // Guard: if trip is concluded, ask user to reopen before sending SOS
    if (currentTrip != null && currentTrip.isEnded) {
      final canProceed = await TripGuardHelper.ensureTripOpenForEdit(
        context,
        ref,
        currentTrip,
        actionLabel: 'send an Emergency SOS',
      );
      if (!canProceed || !context.mounted) return;
    }

    if (!context.mounted) return;
    _showSosConfirmDialog(context, currentTrip, currentUser);
  }

  void _showSosConfirmDialog(BuildContext context, Trip? currentTrip, dynamic currentUser) {
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
          'This will immediately send a high-urgency Emergency SOS alert with your live GPS location to all trip companions over AWS SNS/WebSockets.',
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

              final lat = currentUser.latitude ?? 28.6139;
              final lng = currentUser.longitude ?? 77.2090;

              ref.read(proximityAlertServiceProvider).triggerEmergencySos(
                tripId: currentTrip?.id ?? 'trip_general',
                memberId: currentUser.id,
                memberName: currentUser.displayName,
                lat: lat,
                lng: lng,
              );

              AppSnackBar.show(
                context,
                'SOS sent to companions',
                icon: Icons.check_circle_rounded,
                backgroundColor: const Color(0xFFDC2626),
                duration: const Duration(seconds: 4),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(45),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withAlpha(70), width: 0.8),
                  ),
                  child: Text(
                    '📍 ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getUrgencyColor(AlertUrgency urgency, [AlertType? type]) {
    if (urgency == AlertUrgency.critical) return Colors.red;
    if (type != null) {
      switch (type) {
        case AlertType.sosEmergency:
          return Colors.red;
        case AlertType.companionStray:
          return Colors.orange;
        case AlertType.invitation:
          return AppTheme.primary;
        case AlertType.invitationAccepted:
          return const Color(0xFF10B981);
        case AlertType.invitationRejected:
          return Colors.redAccent;
        case AlertType.memberJoined:
          return Colors.teal;
        case AlertType.memberLeft:
          return Colors.deepOrange;
        case AlertType.billAdded:
        case AlertType.billUpdated:
          return Colors.indigo;
        case AlertType.billDeleted:
          return Colors.red;
        case AlertType.settlementRecorded:
          return const Color(0xFF10B981);
        case AlertType.memoryAdded:
          return Colors.purple;
        case AlertType.stoppageAdded:
        case AlertType.stoppageArrival:
        case AlertType.stoppageDeparture:
          return Colors.amber.shade800;
        case AlertType.locationShared:
          return Colors.blue;
        case AlertType.tripReopened:
          return const Color(0xFF0D9488);
        default:
          break;
      }
    }
    switch (urgency) {
      case AlertUrgency.critical:
        return Colors.red;
      case AlertUrgency.high:
        return Colors.orange;
      case AlertUrgency.normal:
        return Colors.teal;
      case AlertUrgency.low:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(AlertType type) {
    switch (type) {
      case AlertType.sosEmergency:
        return Icons.emergency_rounded;
      case AlertType.companionStray:
        return Icons.radar_rounded;
      case AlertType.stoppageArrival:
        return Icons.pin_drop_rounded;
      case AlertType.stoppageDeparture:
        return Icons.directions_walk_rounded;
      case AlertType.invitation:
        return Icons.mail_outline_rounded;
      case AlertType.invitationAccepted:
        return Icons.how_to_reg_rounded;
      case AlertType.invitationRejected:
        return Icons.person_off_rounded;
      case AlertType.memberJoined:
        return Icons.person_add_alt_1_rounded;
      case AlertType.memberLeft:
        return Icons.exit_to_app_rounded;
      case AlertType.billAdded:
      case AlertType.billUpdated:
        return Icons.receipt_long_rounded;
      case AlertType.billDeleted:
        return Icons.delete_outline_rounded;
      case AlertType.settlementRecorded:
        return Icons.payments_rounded;
      case AlertType.memoryAdded:
        return Icons.photo_camera_rounded;
      case AlertType.stoppageAdded:
        return Icons.add_location_alt_rounded;
      case AlertType.locationShared:
        return Icons.my_location_rounded;
      case AlertType.tripReopened:
        return Icons.restart_alt_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertService = ref.watch(proximityAlertServiceProvider);
    final trips = ref.watch(tripListProvider);
    final allAlerts = alertService.alerts;
    // Keep only emergency SOS and companion stray safety alerts (activities are segregated into Activity Hub)
    final alerts = allAlerts.where((a) => 
      a.type == AlertType.sosEmergency || 
      a.type == AlertType.companionStray
    ).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final unreadSafetyCount = alerts.where((a) => !a.isRead).length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 14, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.sos_rounded, color: Colors.red, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Flexible(
                            child: Text(
                              'Emergency SOS & Safety',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                            ),
                          ),
                          if (unreadSafetyCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unreadSafetyCount',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Text(
                        'Live Geofencing & Companion Emergency Signals',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (alerts.isNotEmpty)
                  PopupMenuButton<String>(
                    tooltip: 'Clear notifications',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_sweep_rounded, size: 16, color: Colors.red),
                          SizedBox(width: 4),
                          Text('Clear', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    onSelected: (val) {
                      if (val == 'clear_all') {
                        alertService.clearAll();
                      } else if (val.startsWith('clear_trip_')) {
                        final tripId = val.replaceFirst('clear_trip_', '');
                        alertService.clearAlertsForTrip(tripId);
                      }
                    },
                    itemBuilder: (ctx) {
                      final items = <PopupMenuEntry<String>>[];
                      final tripIdsInAlerts = alerts
                          .map((a) => a.tripId)
                          .where((id) => id.isNotEmpty && id != 'trip_general' && id != 'general_system')
                          .toSet();
                      for (final tid in tripIdsInAlerts) {
                        final t = trips.where((tr) => tr.id == tid).firstOrNull;
                        final title = t?.title ?? 'Trip';
                        items.add(
                          PopupMenuItem<String>(
                            value: 'clear_trip_$tid',
                            child: Row(
                              children: [
                                const Icon(Icons.near_me_outlined, size: 16, color: AppTheme.primary),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Clear "$title"', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5))),
                              ],
                            ),
                          ),
                        );
                      }
                      if (items.isNotEmpty) {
                        items.add(const PopupMenuDivider());
                      }
                      items.add(
                        const PopupMenuItem<String>(
                          value: 'clear_all',
                          child: Row(
                            children: [
                              Icon(Icons.delete_forever_rounded, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Clear All Notifications', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12.5)),
                            ],
                          ),
                        ),
                      );
                      return items;
                    },
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // Emergency SOS Banner Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.shade700,
                        Colors.red.shade900,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withAlpha(60),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.sos_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Emergency SOS Broadcast',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Alert companions instantly with live GPS coordinates',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () => _confirmSendSos(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red.shade900,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('SOS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Proximity Geofence Safety Controls
                Material(
                  color: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF8FAFC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.radar_rounded, color: AppTheme.primary, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Geofence & Stray Warning Settings',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Stray alert toggle
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Companion Stray Warning', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Notify if a traveler moves too far from the group', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          value: alertService.strayAlertsEnabled,
                          onChanged: (val) => alertService.toggleStrayAlerts(val),
                        ),

                        if (alertService.strayAlertsEnabled) ...[
                          const SizedBox(height: 6),
                          const Text('Alert Threshold Distance:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildThresholdChip(alertService, 500, '500m'),
                              _buildThresholdChip(alertService, 1000, '1.0 km'),
                              _buildThresholdChip(alertService, 1500, '1.5 km'),
                              _buildThresholdChip(alertService, 2500, '2.5 km'),
                              _buildThresholdChip(alertService, 5000, '5.0 km'),
                            ],
                          ),
                        ],

                        const Divider(height: 20),

                        // Stoppage Arrival toggle
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Stop Arrival Geofence', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Auto-alert when entering within 350m of a stop', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          value: alertService.stoppageAlertsEnabled,
                          onChanged: (val) => alertService.toggleStoppageAlerts(val),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Section title: Alert History
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Recent Activity & Alerts',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (alertService.unreadCount > 0)
                      InkWell(
                        onTap: () => alertService.markAllAsRead(),
                        child: const Text('Mark all read', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (alerts.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Column(
                        children: [
                          Icon(Icons.verified_rounded, size: 48, color: Colors.green.withAlpha(140)),
                          const SizedBox(height: 10),
                          const Text(
                            'All Clear • No Active SOS Alerts',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Emergency SOS signals and companion stray alerts will appear here.\nTrip activities and updates can be found in the Activity Hub tab.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  ...alerts.take(_displayLimit).map((alert) => _buildAlertCard(context, alertService, alert, isDark)),
                  if (alerts.length > _displayLimit)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Text(
                          'Showing ${_displayLimit.clamp(0, alerts.length)} of ${alerts.length} alerts • Scroll down for more',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdChip(ProximityAlertService service, double meters, String label) {
    final isSelected = service.strayThresholdMeters == meters;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        service.setStrayThreshold(meters);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, ProximityAlertService service, ProximityAlert alert, bool isDark) {
    final urgencyColor = _getUrgencyColor(alert.urgency, alert.type);
    final icon = _getTypeIcon(alert.type);
    final currentUser = UserService.getCurrentUser();
    final isSender = alert.senderMemberId == currentUser.id;
    final trips = ref.watch(tripListProvider);
    final trip = trips.where((t) => t.id == alert.tripId).firstOrNull;
    final displayMessage = NotificationFormatter.formatMessage(
      alert,
      currentUserId: currentUser.id,
      currentUserName: currentUser.displayName,
      currentUserEmail: currentUser.email,
      currentUsername: currentUser.username,
    );

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
      key: ValueKey('sheet_alert_${alert.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade700,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
            SizedBox(width: 4),
            Text('Dismiss', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
      onDismissed: (_) {
        service.deleteAlert(alert.id, tripId: alert.tripId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alert dismissed'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: isDark
              ? (alert.isRead ? AppTheme.surfaceMutedDark : const Color(0xFF1E293B))
              : (alert.isRead ? const Color(0xFFF8FAFC) : Colors.white),
          elevation: alert.isRead ? 0 : 1.5,
          shadowColor: urgencyColor.withAlpha(isDark ? 45 : 20),
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              if (!alert.isRead) {
                service.markAsRead(alert.id);
              }
              _navigateToAlert(context, alert, trip: trip);
            },
            borderRadius: BorderRadius.circular(14),
            splashColor: urgencyColor.withAlpha(25),
            highlightColor: urgencyColor.withAlpha(15),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: alert.isRead
                      ? (isDark ? AppTheme.borderDark : AppTheme.borderLight)
                      : urgencyColor.withAlpha(120),
                  width: alert.isRead ? 1 : 1.5,
                ),
              ),
              child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: urgencyColor.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: urgencyColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  NotificationFormatter.formatTitle(alert, currentUserId: currentUser.id),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: alert.isRead ? FontWeight.w600 : FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (displayAmount != null && displayAmount > 0) ...[
                                const SizedBox(width: 6),
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
                              ],
                            ],
                          ),
                        ),
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
                                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 1.5),
                            Text(
                              DateFormatter.formatTimeOnly(alert.timestamp),
                              maxLines: 1,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      displayMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                      ),
                    ),
                  if (alert.latitude != null && alert.longitude != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: (alert.type == AlertType.sosEmergency ? Colors.red : AppTheme.primary).withAlpha(isDark ? 30 : 15),
                        borderRadius: BorderRadius.circular(6),
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
                            size: 11,
                            color: alert.type == AlertType.sosEmergency ? Colors.red : AppTheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '📍 ${alert.latitude!.toStringAsFixed(4)}, ${alert.longitude!.toStringAsFixed(4)}',
                            style: TextStyle(
                              fontSize: 10.5,
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
                    if (alert.type == AlertType.sosEmergency && alert.isResolved) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(isDark ? 30 : 15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.green.withAlpha(isDark ? 70 : 40),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 12, color: Colors.green),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'RESOLVED: ${alert.resolutionReason ?? "Issue resolved"}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  // Quick Action Buttons: Shown only to companions (never to sender)
                  if (!isSender &&
                      ((alert.type == AlertType.sosEmergency &&
                              alert.senderMemberId.isNotEmpty &&
                              alert.senderMemberId != 'system') ||
                          (alert.latitude != null && alert.longitude != null))) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        // Resolve SOS button
                        if (alert.type == AlertType.sosEmergency && !alert.isResolved)
                          InkWell(
                            onTap: () => _showResolveSosDialog(context, service, alert),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha(isDark ? 35 : 20),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.green.withAlpha(isDark ? 90 : 60),
                                  width: 0.9,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_outline_rounded, size: 13, color: Colors.green),
                                  SizedBox(width: 4),
                                  Text(
                                    'Resolve SOS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Call button: SOS emergency cards only
                        if (alert.type == AlertType.sosEmergency &&
                            alert.senderMemberId.isNotEmpty &&
                            alert.senderMemberId != 'system')
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
                        if (alert.latitude != null && alert.longitude != null)
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
            if (!alert.isRead) ...[
              const SizedBox(width: 6),
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: urgencyColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  ),
),
);
  }

  void _showResolveSosDialog(BuildContext context, ProximityAlertService service, ProximityAlert alert) {
    HapticFeedback.selectionClick();
    final reasons = ['Assistance Arrived', 'Safe with Group', 'Issue Resolved', 'False Alarm'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.green, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Resolve SOS Alert',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Select the resolution reason to clear the emergency broadcast for ${alert.senderName}:',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: reasons.map((r) {
                    return ActionChip(
                      label: Text(r, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        service.resolveSosAlert(alert.id, resolutionReason: r, tripId: alert.tripId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ Emergency SOS resolved: $r'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
