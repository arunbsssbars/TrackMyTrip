import 'package:flutter/material.dart';

/// Inherited controller providing synchronized shimmer animation phase across all child bones.
class AqilSyncedShimmerScope extends InheritedWidget {
  final Animation<double> animation;
  final Color baseColor;
  final Color highlightColor;

  const AqilSyncedShimmerScope({
    super.key,
    required this.animation,
    required this.baseColor,
    required this.highlightColor,
    required super.child,
  });

  static AqilSyncedShimmerScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AqilSyncedShimmerScope>();
  }

  @override
  bool updateShouldNotify(AqilSyncedShimmerScope oldWidget) =>
      animation != oldWidget.animation ||
      baseColor != oldWidget.baseColor ||
      highlightColor != oldWidget.highlightColor;
}

/// Synchronized shimmer group controller (Uber, Facebook, Airbnb standard).
///
/// Ensures all child skeleton placeholders share a single unified sweeping wave
/// animation, preventing visual cognitive discord from out-of-phase loading elements.
class AqilSyncedShimmerGroup extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color? baseColor;
  final Color? highlightColor;

  const AqilSyncedShimmerGroup({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<AqilSyncedShimmerGroup> createState() => _AqilSyncedShimmerGroupState();
}

class _AqilSyncedShimmerGroupState extends State<AqilSyncedShimmerGroup>
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveBase = widget.baseColor ??
        (isDark ? const Color(0xFF26262B) : const Color(0xFFE5E7EB));
    final effectiveHighlight = widget.highlightColor ??
        (isDark ? const Color(0xFF383842) : const Color(0xFFF3F4F6));

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return AqilSyncedShimmerScope(
          animation: _controller,
          baseColor: effectiveBase,
          highlightColor: effectiveHighlight,
          child: widget.child,
        );
      },
    );
  }
}

/// Synchronized placeholder bone widget driven by [AqilSyncedShimmerScope].
class AqilSyncedBone extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry margin;

  const AqilSyncedBone({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final scope = AqilSyncedShimmerScope.of(context);

    if (scope == null) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      );
    }

    final percent = scope.animation.value;

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scope.baseColor,
            scope.highlightColor,
            scope.baseColor,
          ],
          stops: [
            (percent - 0.3).clamp(0.0, 1.0),
            percent.clamp(0.0, 1.0),
            (percent + 0.3).clamp(0.0, 1.0),
          ],
        ),
      ),
    );
  }
}

/// Shimmer wave choreography auditor.
class AqilShimmerWaveAuditor {
  /// Checks whether shimmer duration conforms to human perceptual smoothness (1200ms - 2000ms).
  static bool isSmoothDuration(Duration duration) {
    final ms = duration.inMilliseconds;
    return ms >= 1200 && ms <= 2000;
  }
}
