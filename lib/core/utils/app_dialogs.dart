import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Centralized confirmation and alert dialog helper.
/// Unifies dialog theme styling, rounded borders (20px), responsive padding,
/// destructive alert styles, and accessible buttons across the entire app.
class AppDialogs {
  const AppDialogs._();

  /// Show a confirmation dialog returning `true` if confirmed, `false` otherwise.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
    IconData? icon,
    Widget? additionalContent,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final effectiveIcon = icon ?? (isDestructive ? Icons.warning_amber_rounded : Icons.help_outline_rounded);
        final effectiveColor = isDestructive ? AppTheme.danger : AppTheme.primary;

        return AlertDialog(
          backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: effectiveColor.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(effectiveIcon, color: effectiveColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.textMainDark : AppTheme.textMainLight,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
                ),
              ),
              if (additionalContent != null) ...[
                const SizedBox(height: 12),
                additionalContent,
              ],
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
              ),
              child: Text(cancelLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: effectiveColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// Show an informative alert dialog with a single acknowledgment button.
  static Future<void> alert(
    BuildContext context, {
    required String title,
    required String message,
    String buttonLabel = 'Understood',
    IconData icon = Icons.info_outline_rounded,
    Color? iconColor,
    Widget? additionalContent,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final color = iconColor ?? AppTheme.primary;

        return AlertDialog(
          backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.textMainDark : AppTheme.textMainLight,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
                ),
              ),
              if (additionalContent != null) ...[
                const SizedBox(height: 12),
                additionalContent,
              ],
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
