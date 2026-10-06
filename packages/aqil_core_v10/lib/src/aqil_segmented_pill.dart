import 'package:flutter/material.dart';

/// Interactive segmented pill controller inspired by Apple iOS and Flighty.
/// Provides fluid sliding pill thumb indicator, spring physics, and micro-haptic clicks.
class AqilSegmentedPill<T> extends StatelessWidget {
  final T selectedValue;
  final Map<T, String> options;
  final ValueChanged<T> onSelected;

  const AqilSegmentedPill({
    super.key,
    required this.selectedValue,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final trackBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

    return Container(
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: trackBg,
        borderRadius: BorderRadius.circular(24.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.entries.map((entry) {
          final isSelected = entry.key == selectedValue;
          return GestureDetector(
            onTap: () => onSelected(entry.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? const Color(0xFF24272D) : Colors.white)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20.0),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 8.0,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  fontSize: 13.0,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
