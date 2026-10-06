import 'package:flutter/material.dart';

/// Semantic role of an informational badge or chip.
enum AqilBadgeVariant {
  neutral,
  success,
  warning,
  error,
  info,
}

/// Subtle, modern micro-badge inspired by Linear, GitHub, and Apple Developer.
/// Replaces harsh high-saturation badges with softly tinted backgrounds,
/// refined 1px matching borders, and balanced typography.
class AqilMicroBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final AqilBadgeVariant variant;

  const AqilMicroBadge({
    super.key,
    required this.label,
    this.icon,
    this.variant = AqilBadgeVariant.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final (Color baseColor, Color textColor) = switch (variant) {
      AqilBadgeVariant.neutral => (
          isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.75),
        ),
      AqilBadgeVariant.success => (
          Colors.green.withValues(alpha: 0.15),
          isDark ? Colors.greenAccent : Colors.green.shade800,
        ),
      AqilBadgeVariant.warning => (
          Colors.orange.withValues(alpha: 0.15),
          isDark ? Colors.orangeAccent : Colors.orange.shade800,
        ),
      AqilBadgeVariant.error => (
          Colors.red.withValues(alpha: 0.15),
          isDark ? Colors.redAccent : Colors.red.shade800,
        ),
      AqilBadgeVariant.info => (
          Colors.blue.withValues(alpha: 0.15),
          isDark ? Colors.blueAccent : Colors.blue.shade800,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: textColor.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: textColor,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
