import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/proximity_alert_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/proximity_alert.dart';
import '../../providers/trip_provider.dart';

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

              ref.read(proximityAlertServiceProvider).triggerEmergencySos(
                tripId: currentTrip?.id ?? 'trip_general',
                memberId: currentUser.id,
                memberName: currentUser.displayName,
                lat: currentUser.latitude ?? 37.7749,
                lng: currentUser.longitude ?? -122.4194,
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

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _getUrgencyColor(AlertUrgency urgency) {
    switch (urgency) {
      case AlertUrgency.critical:
        return Colors.red;
      case AlertUrgency.high:
        return Colors.orange;
      case AlertUrgency.normal:
        return AppTheme.primary;
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
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertService = ref.watch(proximityAlertServiceProvider);
    final alerts = alertService.alerts;
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
                    color: AppTheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Notifications & Proximity',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                          ),
                          if (alertService.unreadCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${alertService.unreadCount}',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Text(
                        'AWS SNS Geofencing & Companion Safety',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (alerts.isNotEmpty)
                  TextButton(
                    onPressed: () => alertService.clearAll(),
                    child: const Text('Clear All', style: TextStyle(fontSize: 12, color: Colors.red)),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: ListView(
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
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.radar_rounded, color: AppTheme.primary, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Geofence & Stray Warning Settings',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                        Row(
                          children: [
                            _buildThresholdChip(alertService, 500, '500m'),
                            const SizedBox(width: 6),
                            _buildThresholdChip(alertService, 1000, '1.0 km'),
                            const SizedBox(width: 6),
                            _buildThresholdChip(alertService, 1500, '1.5 km'),
                            const SizedBox(width: 6),
                            _buildThresholdChip(alertService, 2500, '2.5 km'),
                          ],
                        ),
                      ],

                      const Divider(height: 20),

                      // Stoppage Arrival toggle
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Pitstop Arrival Geofence', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Auto-alert when entering within 350m of a stoppage', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        value: alertService.stoppageAlertsEnabled,
                        onChanged: (val) => alertService.toggleStoppageAlerts(val),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Section title: Alert History
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Activity & Alerts',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
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
                            'All Clear & Group In Range',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Proximity alerts and pitstop arrivals will appear here automatically.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...alerts.map((alert) => _buildAlertCard(context, alertService, alert, isDark)),
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
      onTap: () => service.setStrayThreshold(meters),
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
    final urgencyColor = _getUrgencyColor(alert.urgency);
    final icon = _getTypeIcon(alert.type);

    return Container(
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
                        child: Text(
                          alert.title,
                          style: TextStyle(
                            fontWeight: alert.isRead ? FontWeight.w600 : FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        _formatTimestamp(alert.timestamp),
                        style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    alert.message,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                    ),
                  ),
                  if (alert.latitude != null && alert.longitude != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${alert.latitude!.toStringAsFixed(4)}, ${alert.longitude!.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
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
);
}
}
