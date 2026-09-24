import 'package:flutter/material.dart';

/// An emergency SOS badge icon showing bold 'SOS' typography centered inside
/// a vibrant emergency safety shield/badge with a pulsing red border.
class SosBadgeIcon extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  final String tooltip;

  const SosBadgeIcon({
    super.key,
    required this.onTap,
    this.size = 34,
    this.tooltip = 'Emergency SOS',
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFEF4444), // Bright Red
                Color(0xFFB91C1C), // Deep Crimson
              ],
            ),
            border: Border.all(
              color: Colors.white.withAlpha(220),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC2626).withAlpha(120),
                blurRadius: 8,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Text(
            'SOS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 10.5,
              letterSpacing: 0.6,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
