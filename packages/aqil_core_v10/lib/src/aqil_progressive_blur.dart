import 'package:flutter/material.dart';

/// Progressive blur & fade overlay for scrollable views, cards, and bottom bars.
/// Creates a gradual fade-to-transparent edge rather than an abrupt hard cutoff.
class AqilProgressiveBlur extends StatelessWidget {
  final Widget child;
  final double blurHeight;
  final AlignmentGeometry alignment;

  const AqilProgressiveBlur({
    super.key,
    required this.child,
    this.blurHeight = 40.0,
    this.alignment = Alignment.bottomCenter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;

    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: alignment == Alignment.bottomCenter ? 0 : null,
          top: alignment == Alignment.topCenter ? 0 : null,
          height: blurHeight,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: alignment == Alignment.bottomCenter ? Alignment.topCenter : Alignment.bottomCenter,
                  end: alignment == Alignment.bottomCenter ? Alignment.bottomCenter : Alignment.topCenter,
                  colors: [
                    bg.withValues(alpha: 0.0),
                    bg.withValues(alpha: 0.8),
                    bg,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
