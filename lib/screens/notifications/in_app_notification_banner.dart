import 'package:flutter/material.dart';
import '../../models/proximity_alert.dart';

class InAppNotificationBanner {
  static void show(BuildContext context, ProximityAlert alert) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _BannerWidget(
        alert: alert,
        onDismiss: () {
          entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _BannerWidget extends StatefulWidget {
  final ProximityAlert alert;
  final VoidCallback onDismiss;

  const _BannerWidget({required this.alert, required this.onDismiss});

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

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
        if (mounted) {
          _dismiss();
        }
      });
    }
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  Color _getBgColor() {
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
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 14,
      right: 14,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: _dismiss,
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
                                widget.alert.title,
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
                                  : 'PROXIMITY',
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
                          widget.alert.message,
                          style: TextStyle(
                            color: Colors.white.withAlpha(230),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _dismiss,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
