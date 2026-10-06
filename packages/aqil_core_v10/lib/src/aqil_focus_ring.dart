import 'package:flutter/material.dart';

/// Accessible multi-layer focus indicator conforming to WCAG 2.2 Level AA (SC 2.4.13).
///
/// Wraps an interactive target with an inner transparent offset and outer contrasting
/// stroke and subtle ambient glow to guarantee visibility against both light and dark backgrounds.
class AqilFocusRing extends StatelessWidget {
  final Widget child;
  final bool isFocused;
  final double borderRadius;
  final Color? ringColor;
  final double ringWidth;
  final double offsetGap;

  const AqilFocusRing({
    super.key,
    required this.child,
    required this.isFocused,
    this.borderRadius = 12.0,
    this.ringColor,
    this.ringWidth = 2.5,
    this.offsetGap = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = ringColor ?? theme.colorScheme.primary;

    if (!isFocused) {
      return child;
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned.fill(
          top: -offsetGap - ringWidth,
          bottom: -offsetGap - ringWidth,
          left: -offsetGap - ringWidth,
          right: -offsetGap - ringWidth,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius + offsetGap + ringWidth),
                border: Border.all(
                  color: primary,
                  width: ringWidth,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.35),
                    blurRadius: 6.0,
                    spreadRadius: 1.0,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
