import 'package:flutter/material.dart';

/// Shimmer bone placeholder for a single structural element (text line, avatar, badge).
class AqilSkeletonBone extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry margin;

  const AqilSkeletonBone({
    super.key,
    this.width,
    this.height = 16.0,
    this.borderRadius = 8.0,
    this.margin = EdgeInsets.zero,
  });

  const AqilSkeletonBone.avatar({
    super.key,
    double size = 48.0,
    this.margin = EdgeInsets.zero,
  })  : width = size,
        height = size,
        borderRadius = size / 2;

  const AqilSkeletonBone.line({
    super.key,
    this.width,
    this.height = 14.0,
    this.borderRadius = 4.0,
    this.margin = const EdgeInsets.symmetric(vertical: 4.0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Shimmer animation provider wrapping skeleton bones to produce a silky,
/// high-fidelity shimmer effect without layout reflows or external packages.
class AqilShimmerSweep extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color? baseColor;
  final Color? highlightColor;

  const AqilShimmerSweep({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1400),
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<AqilShimmerSweep> createState() => _AqilShimmerSweepState();
}

class _AqilShimmerSweepState extends State<AqilShimmerSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final sweep = _controller.value;
            return LinearGradient(
              begin: Alignment(-2.0 + (sweep * 3.0), -0.2),
              end: Alignment(-0.5 + (sweep * 3.0), 0.2),
              colors: [
                Colors.white.withValues(alpha: 0.3),
                Colors.white.withValues(alpha: 0.8),
                Colors.white.withValues(alpha: 0.3),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Pre-engineered skeleton templates matching standard card patterns, ensuring 0.0 CLS.
class AqilSkeletonCard extends StatelessWidget {
  final bool hasAvatar;
  final int textLines;
  final EdgeInsetsGeometry padding;

  const AqilSkeletonCard({
    super.key,
    this.hasAvatar = true,
    this.textLines = 3,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    return AqilShimmerSweep(
      child: Padding(
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasAvatar) ...[
              const AqilSkeletonBone.avatar(size: 48),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AqilSkeletonBone.line(width: 160, height: 16),
                  const SizedBox(height: 8),
                  for (int i = 0; i < textLines - 1; i++) ...[
                    AqilSkeletonBone.line(
                      width: i == textLines - 2 ? 120 : double.infinity,
                      height: 12,
                    ),
                    const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
