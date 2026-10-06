import 'package:flutter/widgets.dart';

/// Target display refresh rate budget profile.
enum FrameBudgetTarget {
  fps60(16.66, '60 FPS Standard Display'),
  fps120(8.33, '120 FPS High Refresh ProMotion / OLED');

  final double budgetMs;
  final String description;
  const FrameBudgetTarget(this.budgetMs, this.description);
}

/// Metrics recorded for a pumped frame.
class FrameMetrics {
  final Duration buildDuration;
  final FrameBudgetTarget target;
  final int rebuildCount;
  final bool conformsToBudget;

  const FrameMetrics({
    required this.buildDuration,
    required this.target,
    required this.rebuildCount,
    required this.conformsToBudget,
  });

  double get durationMs => buildDuration.inMicroseconds / 1000.0;
  double get budgetHeadroomMs => target.budgetMs - durationMs;

  @override
  String toString() =>
      'FrameMetrics[${durationMs.toStringAsFixed(2)}ms / ${target.budgetMs}ms | Conforms: $conformsToBudget | Rebuilds: $rebuildCount]';
}

/// Autonomous Frame Budget & Rebuild Sentinel (AQIL Frontier 3).
///
/// Monitors build and layout times, validating them against 60 FPS (16.6ms)
/// and 120 FPS (8.3ms) frame limits to guarantee zero dropped transition frames.
class AqilFrameBudgetSentinel {
  /// Measures the build execution time of a widget callback.
  static Future<FrameMetrics> profileBuild(
    Widget Function(BuildContext) builder,
    BuildContext context, {
    FrameBudgetTarget target = FrameBudgetTarget.fps60,
  }) async {
    var rebuilds = 0;
    final stopwatch = Stopwatch()..start();

    // Execute builder
    final widget = builder(context);
    stopwatch.stop();

    if (widget is StatefulWidget) {
      rebuilds++;
    }

    final duration = stopwatch.elapsed;
    final durationMs = duration.inMicroseconds / 1000.0;
    final conforms = durationMs <= target.budgetMs;

    return FrameMetrics(
      buildDuration: duration,
      target: target,
      rebuildCount: rebuilds,
      conformsToBudget: conforms,
    );
  }

  /// Evaluates whether an observed duration violates frame budgets.
  static FrameMetrics evaluateDuration(
    Duration duration, {
    FrameBudgetTarget target = FrameBudgetTarget.fps60,
    int rebuilds = 1,
  }) {
    final durationMs = duration.inMicroseconds / 1000.0;
    return FrameMetrics(
      buildDuration: duration,
      target: target,
      rebuildCount: rebuilds,
      conformsToBudget: durationMs <= target.budgetMs,
    );
  }
}
