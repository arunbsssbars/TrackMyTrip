import 'package:flutter/material.dart';

/// Segmented split action button (GitHub Pull Request / Apple macOS standard).
///
/// Combines a primary trigger button with an adjacent dropdown menu trigger,
/// unified within a single tactile pill container separated by a hairline divider.
class AqilSplitActionPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onAction;
  final VoidCallback onDropdown;
  final Color? color;
  final double height;

  const AqilSplitActionPill({
    super.key,
    required this.label,
    this.icon,
    required this.onAction,
    required this.onDropdown,
    this.color,
    this.height = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = color ?? theme.colorScheme.primary;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.3),
            blurRadius: 8.0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary Action Button
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(height / 2),
              bottomLeft: Radius.circular(height / 2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16.0, color: Colors.white),
                    const SizedBox(width: 6.0),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Hairline Divider
          Container(
            width: 1.0,
            height: height * 0.6,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          // Dropdown Action
          InkWell(
            onTap: onDropdown,
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(height / 2),
              bottomRight: Radius.circular(height / 2),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.0),
              child: Icon(
                Icons.arrow_drop_down,
                size: 20.0,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
