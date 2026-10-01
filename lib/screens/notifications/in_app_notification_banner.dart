import 'package:flutter/material.dart';
import '../../models/proximity_alert.dart';
import '../../core/services/user_service.dart';
import '../../core/utils/notification_formatter.dart';

class InAppNotificationBanner {
  static OverlayEntry? _currentEntry;

  static void dismissActive() {
    try {
      if (_currentEntry != null && _currentEntry!.mounted) {
        _currentEntry!.remove();
      }
    } catch (_) {}
    _currentEntry = null;
  }

  static void show(
    BuildContext context,
    ProximityAlert alert, {
    VoidCallback? onMuteBanners,
  }) {
    if (!context.mounted) return;

    // Dismiss any active banner overlay before showing a new one
    dismissActive();

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _BannerWidget(
        alert: alert,
        onMuteBanners: onMuteBanners,
        onDismiss: () {
          if (_currentEntry == entry) {
            _currentEntry = null;
          }
          try {
            if (entry.mounted) {
              entry.remove();
            }
          } catch (_) {}
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class _BannerWidget extends StatefulWidget {
  final ProximityAlert alert;
  final VoidCallback onDismiss;
  final VoidCallback? onMuteBanners;

  const _BannerWidget({
    required this.alert,
    required this.onDismiss,
    this.onMuteBanners,
  });

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    // Auto dismiss after 5 seconds (unless critical SOS)
    if (widget.alert.urgency != AlertUrgency.critical) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && !_isDismissed) {
          _dismiss();
        }
      });
    }
  }

  void _dismiss() {
    if (_isDismissed) return;
    _isDismissed = true;
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  Color _getBgColor() {
    if (widget.alert.urgency == AlertUrgency.critical) return const Color(0xFFDC2626);
    switch (widget.alert.type) {
      case AlertType.sosEmergency:
        return const Color(0xFFDC2626);
      case AlertType.companionStray:
        return const Color(0xFFEA580C);
      case AlertType.invitation:
        return const Color(0xFF0D9488);
      case AlertType.invitationAccepted:
        return const Color(0xFF10B981);
      case AlertType.invitationRejected:
        return const Color(0xFFEF4444);
      case AlertType.memberJoined:
        return const Color(0xFF0D9488);
      case AlertType.memberLeft:
        return const Color(0xFFF97316);
      case AlertType.billAdded:
      case AlertType.billUpdated:
        return const Color(0xFF4F46E5);
      case AlertType.billDeleted:
        return const Color(0xFFEF4444);
      case AlertType.settlementRecorded:
        return const Color(0xFF10B981);
      case AlertType.memoryAdded:
        return const Color(0xFF9333EA);
      case AlertType.stoppageAdded:
      case AlertType.stoppageArrival:
      case AlertType.stoppageDeparture:
        return const Color(0xFFD97706);
      case AlertType.locationShared:
        return const Color(0xFF2563EB);
      default:
        break;
    }
    switch (widget.alert.urgency) {
      case AlertUrgency.critical:
        return const Color(0xFFDC2626); // Red
      case AlertUrgency.high:
        return const Color(0xFFEA580C); // Orange
      case AlertUrgency.normal:
        return const Color(0xFF0D9488); // Teal
      case AlertUrgency.low:
        return const Color(0xFF4B5563); // Gray
    }
  }

  IconData _getIcon() {
    switch (widget.alert.type) {
      case AlertType.sosEmergency:
        return Icons.emergency_rounded;
      case AlertType.companionStray:
        return Icons.warning_amber_rounded;
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
      default:
        return Icons.notifications_active_rounded;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = UserService.getCurrentUser();
    final displayMessage = NotificationFormatter.formatMessage(
      widget.alert,
      currentUserId: currentUser.id,
      currentUserName: currentUser.displayName,
      currentUserEmail: currentUser.email,
      currentUsername: currentUser.username,
    );

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 14,
      right: 14,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Dismissible(
          key: ValueKey('banner_${widget.alert.id}'),
          direction: DismissDirection.horizontal,
          onDismissed: (_) {
            _isDismissed = true;
            widget.onDismiss();
          },
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null && details.primaryVelocity! < -100) {
                _dismiss();
              }
            },
            onTap: _dismiss,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _getBgColor(),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(80),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_getIcon(), color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  NotificationFormatter.formatTitle(widget.alert, currentUserId: currentUser.id),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                widget.alert.urgency == AlertUrgency.critical
                                    ? 'SOS'
                                    : 'ALERT',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(200),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayMessage,
                            style: TextStyle(
                              color: Colors.white.withAlpha(230),
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.alert.type == AlertType.sosEmergency) ...[
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(40),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.done_all_rounded, size: 12, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.alert.senderMemberId == currentUser.id
                                        ? 'Emergency Broadcast • RTDB Active'
                                        : 'Priority Dispatch • Received Live',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (widget.onMuteBanners != null && widget.alert.urgency != AlertUrgency.critical)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Banner options',
                        onSelected: (val) {
                          if (val == 'mute') {
                            widget.onMuteBanners?.call();
                            _dismiss();
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'mute',
                            height: 38,
                            child: Row(
                              children: [
                                Icon(Icons.notifications_off_rounded, size: 16, color: Colors.deepOrange),
                                SizedBox(width: 8),
                                Text(
                                  'Turn off banners',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Dismiss',
                      onPressed: _dismiss,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
