import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Unified, resilient, and responsive snackbar feedback system.
/// Protects against unmounted contexts, text clipping across narrow viewports,
/// and unifies visual styles (12px rounded borders, semantic colors, floating behavior).
class AppSnackBar {
  const AppSnackBar._();

  /// Show a green success message with a checkmark icon.
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    show(
      context,
      message,
      icon: Icons.check_circle_rounded,
      backgroundColor: AppTheme.success,
      duration: duration,
      action: action,
    );
  }

  /// Show a red error message with an error icon.
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    show(
      context,
      message,
      icon: Icons.error_rounded,
      backgroundColor: AppTheme.danger,
      duration: duration,
      action: action,
    );
  }

  /// Show an amber warning message with an alert icon.
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    show(
      context,
      message,
      icon: Icons.warning_rounded,
      backgroundColor: AppTheme.warning,
      duration: duration,
      action: action,
    );
  }

  /// Show an informative blue/teal message with an info icon.
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    show(
      context,
      message,
      icon: Icons.info_rounded,
      backgroundColor: AppTheme.primary,
      duration: duration,
      action: action,
    );
  }

  /// Core implementation with mounted check, clear previous, and defensive layout constraints.
  static void show(
    BuildContext context,
    String message, {
    IconData? icon,
    Widget? trailing,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: -0.1,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
        backgroundColor: backgroundColor ?? AppTheme.surfaceDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        duration: duration,
        action: action,
      ),
    );
  }
}
