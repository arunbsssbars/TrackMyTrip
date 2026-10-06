import 'package:flutter/material.dart';

/// Interactive filter metadata badge pill (Linear, GitHub, Vercel standard).
///
/// Features selectable active state, counter badge, optional dismiss button,
/// and accessible >= 44x44dp hit area wrapping compact visual design.
class AqilInteractiveBadgePill extends StatelessWidget {
  final String label;
  final int? count;
  final IconData? leadingIcon;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final Color? activeColor;

  const AqilInteractiveBadgePill({
    super.key,
    required this.label,
    this.count,
    this.leadingIcon,
    this.isSelected = false,
    this.onTap,
    this.onDismiss,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = activeColor ?? theme.colorScheme.primary;

    final bgColor = isSelected
        ? primary.withValues(alpha: isDark ? 0.22 : 0.12)
        : (isDark ? const Color(0xFF222228) : const Color(0xFFF3F4F6));

    final borderColor = isSelected
        ? primary.withValues(alpha: isDark ? 0.6 : 0.4)
        : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08));

    final textColor = isSelected
        ? (isDark ? Color.lerp(primary, Colors.white, 0.4)! : primary)
        : (isDark ? Colors.white70 : Colors.black87);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label${count != null ? ', $count items' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44.0, minWidth: 44.0),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(color: borderColor, width: 1.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leadingIcon != null) ...[
                  Icon(
                    leadingIcon,
                    size: 14.0,
                    color: textColor,
                  ),
                  const SizedBox(width: 5.0),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12.0,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primary.withValues(alpha: 0.25)
                          : (isDark ? Colors.white12 : Colors.black12),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10.0,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
                if (onDismiss != null) ...[
                  const SizedBox(width: 4.0),
                  GestureDetector(
                    onTap: onDismiss,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Icon(
                        Icons.close,
                        size: 13.0,
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
