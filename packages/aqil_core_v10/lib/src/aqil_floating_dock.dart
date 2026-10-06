import 'dart:ui';
import 'package:flutter/material.dart';

/// Navigation item model for [AqilFloatingDock].
class AqilDockItem {
  final IconData icon;
  final String label;
  final int? badgeCount;

  const AqilDockItem({
    required this.icon,
    required this.label,
    this.badgeCount,
  });
}

/// Floating pill navigation dock matching Apple macOS / iPadOS and Arc Browser.
///
/// Provides a frosted glass floating pill elevated above bottom screen content
/// with responsive safe area clearance, spring icon animations, and badge pills.
class AqilFloatingDock extends StatelessWidget {
  final List<AqilDockItem> items;
  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final double blurSigma;
  final Color? activeColor;

  const AqilFloatingDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onItemSelected,
    this.blurSigma = 16.0,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = activeColor ?? theme.colorScheme.primary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E22).withValues(alpha: 0.75)
                      : Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(32.0),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                      blurRadius: 20.0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    final isSelected = index == currentIndex;

                    return GestureDetector(
                      onTap: () => onItemSelected(index),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(
                          horizontal: isSelected ? 16.0 : 12.0,
                          vertical: 8.0,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primary.withValues(alpha: isDark ? 0.25 : 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.icon,
                                  size: 22.0,
                                  color: isSelected
                                      ? primary
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.6)
                                          : Colors.black.withValues(alpha: 0.6)),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8.0),
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      color: primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.0,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (item.badgeCount != null && item.badgeCount! > 0)
                              Positioned(
                                top: -4.0,
                                right: -4.0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4.0,
                                    vertical: 1.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 14.0,
                                    minHeight: 14.0,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${item.badgeCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
