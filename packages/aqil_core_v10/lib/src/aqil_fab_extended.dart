import 'package:flutter/material.dart';

/// Semantic role of a floating action badge.
class AqilFloatingActionButtonExtended extends StatelessWidget {
  final Widget icon;
  final Widget label;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AqilFloatingActionButtonExtended({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.primary;
    final fg = foregroundColor ?? theme.colorScheme.onPrimary;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(28.0),
      elevation: 4.0,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(28.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme(
                data: IconThemeData(color: fg, size: 20),
                child: icon,
              ),
              const SizedBox(width: 10),
              DefaultTextStyle(
                style: theme.textTheme.labelLarge!.copyWith(
                  color: fg,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
                child: label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
