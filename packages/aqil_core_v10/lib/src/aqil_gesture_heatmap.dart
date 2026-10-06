import 'package:flutter/material.dart';

/// Recorded interaction gesture event on a screen.
class AqilGesturePoint {
  final Offset position;
  final DateTime timestamp;
  final String? targetWidgetType;
  final bool hasActionHandler;

  const AqilGesturePoint({
    required this.position,
    required this.timestamp,
    this.targetWidgetType,
    this.hasActionHandler = true,
  });

  Map<String, dynamic> toJson() => {
        'dx': position.dx,
        'dy': position.dy,
        'timestamp': timestamp.toIso8601String(),
        'targetWidgetType': targetWidgetType,
        'hasActionHandler': hasActionHandler,
      };
}

/// Reachability zones and dead-click statistics.
class AqilHeatmapMetrics {
  final int totalGestures;
  final int deadClicks;
  final int thumbComfortZoneCount; // bottom 60% of viewport
  final int reachStretchZoneCount; // top 40% of viewport
  final double thumbReachabilityRatio; // % of interactive clicks within thumb reach
  final double deadClickRatio;

  const AqilHeatmapMetrics({
    required this.totalGestures,
    required this.deadClicks,
    required this.thumbComfortZoneCount,
    required this.reachStretchZoneCount,
    required this.thumbReachabilityRatio,
    required this.deadClickRatio,
  });
}

/// Tracks, collects, and visualizes touch/tap events on any Flutter screen.
/// Evaluates ergonomic thumb reachability zones (bottom 60% vs top 40%)
/// and alerts on "dead clicks" (taps on inert non-interactive widgets).
class AqilGestureHeatmap extends StatefulWidget {
  final Widget child;
  final bool enableOverlay;
  final void Function(AqilGesturePoint point)? onGestureLogged;

  const AqilGestureHeatmap({
    super.key,
    required this.child,
    this.enableOverlay = false,
    this.onGestureLogged,
  });

  @override
  State<AqilGestureHeatmap> createState() => AqilGestureHeatmapState();
}

class AqilGestureHeatmapState extends State<AqilGestureHeatmap> {
  final List<AqilGesturePoint> _gestures = [];

  List<AqilGesturePoint> get gestures => List.unmodifiable(_gestures);

  void recordGesture(Offset position, {String? targetWidget, bool hasHandler = true}) {
    final point = AqilGesturePoint(
      position: position,
      timestamp: DateTime.now(),
      targetWidgetType: targetWidget,
      hasActionHandler: hasHandler,
    );
    _gestures.add(point);
    widget.onGestureLogged?.call(point);
    if (mounted) setState(() {});
  }

  void clearGestures() {
    _gestures.clear();
    if (mounted) setState(() {});
  }

  AqilHeatmapMetrics calculateMetrics(Size viewportSize) {
    if (_gestures.isEmpty) {
      return const AqilHeatmapMetrics(
        totalGestures: 0,
        deadClicks: 0,
        thumbComfortZoneCount: 0,
        reachStretchZoneCount: 0,
        thumbReachabilityRatio: 1.0,
        deadClickRatio: 0.0,
      );
    }

    final comfortCutoff = viewportSize.height * 0.40; // Top 40% is stretch, bottom 60% is comfort
    int comfortCount = 0;
    int stretchCount = 0;
    int deadClicks = 0;

    for (final g in _gestures) {
      if (!g.hasActionHandler) {
        deadClicks++;
      }
      if (g.position.dy >= comfortCutoff) {
        comfortCount++;
      } else {
        stretchCount++;
      }
    }

    return AqilHeatmapMetrics(
      totalGestures: _gestures.length,
      deadClicks: deadClicks,
      thumbComfortZoneCount: comfortCount,
      reachStretchZoneCount: stretchCount,
      thumbReachabilityRatio: comfortCount / _gestures.length,
      deadClickRatio: deadClicks / _gestures.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        recordGesture(event.position);
      },
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (widget.enableOverlay)
            IgnorePointer(
              child: CustomPaint(
                painter: _HeatmapPainter(gestures: _gestures),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final List<AqilGesturePoint> gestures;

  _HeatmapPainter({required this.gestures});

  @override
  void paint(Canvas canvas, Size size) {
    for (final point in gestures) {
      final paint = Paint()
        ..color = point.hasActionHandler
            ? Colors.cyanAccent.withValues(alpha: 0.4)
            : Colors.redAccent.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(point.position, 16.0, paint);

      final centerPaint = Paint()
        ..color = point.hasActionHandler ? Colors.blue : Colors.red
        ..style = PaintingStyle.fill;
      canvas.drawCircle(point.position, 4.0, centerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) => true;
}
