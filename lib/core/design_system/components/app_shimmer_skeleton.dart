import 'package:flutter/material.dart';
import '../app_tokens.dart';

/// Shimmer skeleton container for data-loading placeholders.
/// Respects [MediaQuery.disableAnimationsOf(context)] by disabling animation when requested.
class AppSkeletonBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final ShapeBorder? shape;

  const AppSkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape,
  });

  const AppSkeletonBox.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = null,
        shape = const CircleBorder();

  @override
  State<AppSkeletonBox> createState() => _AppSkeletonBoxState();
}

class _AppSkeletonBoxState extends State<AppSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final highlightColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final effectiveRadius = widget.borderRadius ?? AppRadius.roundedSm;

    if (reduceMotion) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: ShapeDecoration(
          color: baseColor,
          shape: widget.shape ?? RoundedRectangleBorder(borderRadius: effectiveRadius),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: ShapeDecoration(
            shape: widget.shape ?? RoundedRectangleBorder(borderRadius: effectiveRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A standard list-item skeleton mimicking a ListTile with avatar, title, and subtitle.
class AppSkeletonListTile extends StatelessWidget {
  final bool hasAvatar;
  final bool hasTrailing;

  const AppSkeletonListTile({
    super.key,
    this.hasAvatar = true,
    this.hasTrailing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          if (hasAvatar) ...[
            const AppSkeletonBox.circle(size: 40.0),
            const SizedBox(width: AppSpacing.md),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSkeletonBox(width: 140.0, height: 14.0),
                SizedBox(height: AppSpacing.xs),
                AppSkeletonBox(width: 200.0, height: 10.0),
              ],
            ),
          ),
          if (hasTrailing) ...[
            const SizedBox(width: AppSpacing.md),
            const AppSkeletonBox(width: 48.0, height: 24.0),
          ],
        ],
      ),
    );
  }
}

/// A card skeleton placeholder.
class AppSkeletonCard extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry margin;

  const AppSkeletonCard({
    super.key,
    this.height = 100.0,
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      height: height,
      child: AppSkeletonBox(
        width: double.infinity,
        height: height,
        borderRadius: AppRadius.roundedLg,
      ),
    );
  }
}
