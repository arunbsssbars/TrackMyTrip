import 'package:flutter/material.dart';

/// Semantic role of a toast / floating notification.
enum AqilToastType {
  info,
  success,
  warning,
  error,
}

/// A floating snackbar / toast alert banner with gentle spring entry,
/// frosted surface blur, and refined icons matching Linear and Apple iOS.
class AqilFloatingBanner extends StatelessWidget {
  final String title;
  final String? message;
  final AqilToastType type;
  final VoidCallback? onDismiss;

  const AqilFloatingBanner({
    super.key,
    required this.title,
    this.message,
    this.type = AqilToastType.info,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final (IconData icon, Color iconColor) = switch (type) {
      AqilToastType.info => (Icons.info_outline_rounded, Colors.blueAccent),
      AqilToastType.success => (Icons.check_circle_outline_rounded, Colors.greenAccent),
      AqilToastType.warning => (Icons.warning_amber_rounded, Colors.orangeAccent),
      AqilToastType.error => (Icons.error_outline_rounded, Colors.redAccent),
    };

    final bg = isDark
        ? const Color(0xFF16181C).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.92);

    final border = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    message!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16),
              tooltip: 'Dismiss notification',
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
