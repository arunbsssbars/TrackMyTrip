import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/proximity_alert_service.dart';
import '../../models/proximity_alert.dart';

/// A simplified, eye-friendly emergency SOS badge with a calm, 
/// modern palette, clean safety iconography, tactile haptic feedback,
/// and live unread safety badge indicator.
class SosBadgeIcon extends ConsumerWidget {
  final VoidCallback onTap;
  final double size;
  final String tooltip;

  const SosBadgeIcon({
    super.key,
    required this.onTap,
    this.size = 32,
    this.tooltip = 'Emergency SOS & Safety Alerts',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertService = ref.watch(proximityAlertServiceProvider);
    final hasUnreadSos = alertService.alerts.any((a) =>
        !a.isRead &&
        (a.type == AlertType.sosEmergency || a.type == AlertType.companionStray));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2E171E) : const Color(0xFFFFF1F2);
    final borderColor = isDark ? const Color(0xFFE11D48).withAlpha(90) : const Color(0xFFFECDD3);
    final iconColor = isDark ? const Color(0xFFFDA4AF) : const Color(0xFFE11D48);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(size / 2),
          splashColor: iconColor.withAlpha(30),
          highlightColor: Colors.transparent,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bgColor,
                  border: Border.all(
                    color: borderColor,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 30 : 8),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.sos_rounded,
                  size: size * 0.62,
                  color: iconColor,
                ),
              ),
              if (hasUnreadSos)
                Positioned(
                  top: -1,
                  right: -1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
