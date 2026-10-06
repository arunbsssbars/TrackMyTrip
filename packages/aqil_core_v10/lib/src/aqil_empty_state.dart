import 'package:flutter/material.dart';

/// Expressive empty state container matching Airbnb, Apple, and Stripe standards.
class AqilEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;
  final Color? accentColor;
  final EdgeInsetsGeometry padding;

  const AqilEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
    this.accentColor,
    this.padding = const EdgeInsets.all(32.0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = accentColor ?? theme.colorScheme.primary;

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Layered halo icon badge
            Container(
              width: 80.0,
              height: 80.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withValues(alpha: isDark ? 0.16 : 0.08),
                border: Border.all(
                  color: primary.withValues(alpha: isDark ? 0.28 : 0.16),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 38.0,
                  color: primary,
                ),
              ),
            ),
            const SizedBox(height: 20.0),
            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ) ??
                  const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
            ),
            const SizedBox(height: 8.0),
            // Description
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320.0),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.white60 : Colors.black54,
                      height: 1.45,
                    ) ??
                    const TextStyle(
                      fontSize: 14.0,
                      color: Colors.grey,
                      height: 1.45,
                    ),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 24.0),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Auditor checking if empty states meet world-class actionable criteria.
class AqilEmptyStateAuditor {
  /// Evaluates an empty state message for actionable guidance.
  ///
  /// Flags terse, unhelpful states like "Empty", "No Data", "Nothing here".
  static bool isActionableEmptyState({
    required String title,
    required String description,
    required bool hasAction,
  }) {
    if (title.trim().length < 5) return false;
    if (description.trim().split(' ').length < 3) return false;
    return hasAction;
  }
}
