import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Target display refresh rate specifications for animation frame budgets (AQIL Frontier 1).
enum RefreshRateTarget {
  fps60(16.67, '60Hz Standard Display (16.67ms)'),
  fps90(11.11, '90Hz High Refresh Display (11.11ms)'),
  fps120(8.33, '120Hz ProMotion / Gaming Display (8.33ms)');

  final double budgetMs;
  final String label;

  const RefreshRateTarget(this.budgetMs, this.label);
}

/// Metrics recorded for a single animated frame.
class SingleFrameMetric {
  final int frameIndex;
  final double durationMs;
  final bool isJank;
  final double budgetMs;

  const SingleFrameMetric({
    required this.frameIndex,
    required this.durationMs,
    required this.isJank,
    required this.budgetMs,
  });

  @override
  String toString() =>
      'Frame #$frameIndex: ${durationMs.toStringAsFixed(2)}ms ${isJank ? "[JANK > ${budgetMs.toStringAsFixed(2)}ms]" : "[OK]"}';
}

/// Comprehensive outcome report of an animation frame budget profiling pass.
class EnterpriseFrameBudgetReport {
  final RefreshRateTarget targetRate;
  final double budgetMs;
  final int totalFrames;
  final int jankFrames;
  final double averageFrameMs;
  final double p90FrameMs;
  final double p95FrameMs;
  final double p99FrameMs;
  final double maxFrameMs;
  final double jankRatio; // jankFrames / totalFrames
  final bool isSlaCompliant; // p95 <= budgetMs && jankRatio <= 0.05
  final List<SingleFrameMetric> frameMetrics;
  final List<String> optimizationTips;

  const EnterpriseFrameBudgetReport({
    required this.targetRate,
    required this.budgetMs,
    required this.totalFrames,
    required this.jankFrames,
    required this.averageFrameMs,
    required this.p90FrameMs,
    required this.p95FrameMs,
    required this.p99FrameMs,
    required this.maxFrameMs,
    required this.jankRatio,
    required this.isSlaCompliant,
    required this.frameMetrics,
    required this.optimizationTips,
  });

  String toMarkdownSummary() {
    final buffer = StringBuffer();
    buffer.writeln('### AQIL Frame Budget Profiling Report (${targetRate.label})');
    buffer.writeln('- **SLA Status**: ${isSlaCompliant ? "COMPLIANT (PASS)" : "SLA BREACH (JANK DETECTED)"}');
    buffer.writeln('- **Frame Budget**: ${budgetMs.toStringAsFixed(2)}ms');
    buffer.writeln('- **Total Frames Evaluated**: $totalFrames (Jank Frames: $jankFrames, ${(jankRatio * 100).toStringAsFixed(1)}%)');
    buffer.writeln('- **Averages & Percentiles**:');
    buffer.writeln('  - Mean: ${averageFrameMs.toStringAsFixed(2)}ms');
    buffer.writeln('  - P90: ${p90FrameMs.toStringAsFixed(2)}ms');
    buffer.writeln('  - P95: ${p95FrameMs.toStringAsFixed(2)}ms');
    buffer.writeln('  - P99: ${p99FrameMs.toStringAsFixed(2)}ms');
    buffer.writeln('  - Worst Spike: ${maxFrameMs.toStringAsFixed(2)}ms');

    if (optimizationTips.isNotEmpty) {
      buffer.writeln('- **Optimization Recommendations**:');
      for (final tip in optimizationTips) {
        buffer.writeln('  - 💡 $tip');
      }
    }

    return buffer.toString();
  }
}

/// Verification result of render tree repaint boundary isolation.
class RepaintIsolationReport {
  final bool hasRepaintBoundary;
  final bool isIsolated;
  final int ancestorBoundaryCount;
  final String diagnostic;

  const RepaintIsolationReport({
    required this.hasRepaintBoundary,
    required this.isIsolated,
    required this.ancestorBoundaryCount,
    required this.diagnostic,
  });
}

/// Frame Budget & Impeller/Skia Animation Jank Profiler (AQIL Frontier 1 / v7.0).
///
/// Profiles animated transitions against 60Hz, 90Hz, and 120Hz frame budgets,
/// calculates p90/p95/p99 latency percentiles, and detects missing RepaintBoundaries.
class AqilFrameProfiler {
  /// Computes a [EnterpriseFrameBudgetReport] from a series of observed frame durations.
  static EnterpriseFrameBudgetReport evaluateFrameMetrics(
    List<double> frameDurationsMs, {
    RefreshRateTarget target = RefreshRateTarget.fps120,
    double maxAllowedJankRatio = 0.05, // 5% max jank frames allowed
  }) {
    if (frameDurationsMs.isEmpty) {
      return EnterpriseFrameBudgetReport(
        targetRate: target,
        budgetMs: target.budgetMs,
        totalFrames: 0,
        jankFrames: 0,
        averageFrameMs: 0.0,
        p90FrameMs: 0.0,
        p95FrameMs: 0.0,
        p99FrameMs: 0.0,
        maxFrameMs: 0.0,
        jankRatio: 0.0,
        isSlaCompliant: true,
        frameMetrics: const [],
        optimizationTips: const ['No frames recorded.'],
      );
    }

    final budget = target.budgetMs;
    int jankCount = 0;
    double sum = 0.0;
    double maxMs = 0.0;
    final metrics = <SingleFrameMetric>[];

    for (int i = 0; i < frameDurationsMs.length; i++) {
      final dur = frameDurationsMs[i];
      sum += dur;
      if (dur > maxMs) maxMs = dur;

      final isJank = dur > budget;
      if (isJank) jankCount++;

      metrics.add(SingleFrameMetric(
        frameIndex: i + 1,
        durationMs: dur,
        isJank: isJank,
        budgetMs: budget,
      ));
    }

    // Sort to calculate percentiles
    final sorted = List<double>.from(frameDurationsMs)..sort();
    final p90 = _calculatePercentile(sorted, 0.90);
    final p95 = _calculatePercentile(sorted, 0.95);
    final p99 = _calculatePercentile(sorted, 0.99);

    final jankRatio = jankCount / frameDurationsMs.length;
    final isSlaCompliant = p95 <= budget && jankRatio <= maxAllowedJankRatio;

    final tips = <String>[];
    if (!isSlaCompliant) {
      tips.add('P95 latency (${p95.toStringAsFixed(2)}ms) exceeded target ${target.label} budget.');
      if (maxMs > budget * 1.5) {
        tips.add('Severe frame spike detected (${maxMs.toStringAsFixed(2)}ms). Consider wrapping animated subtrees in RepaintBoundary.');
      }
      if (jankRatio > 0.10) {
        tips.add('High jank ratio (${(jankRatio * 100).toStringAsFixed(1)}%). Profile widget build vs raster costs.');
      }
    } else {
      tips.add('Animation maintains smooth performance conforming to ${target.label} SLA.');
    }

    return EnterpriseFrameBudgetReport(
      targetRate: target,
      budgetMs: budget,
      totalFrames: frameDurationsMs.length,
      jankFrames: jankCount,
      averageFrameMs: sum / frameDurationsMs.length,
      p90FrameMs: p90,
      p95FrameMs: p95,
      p99FrameMs: p99,
      maxFrameMs: maxMs,
      jankRatio: jankRatio,
      isSlaCompliant: isSlaCompliant,
      frameMetrics: metrics,
      optimizationTips: tips,
    );
  }

  static double _calculatePercentile(List<double> sorted, double percentile) {
    if (sorted.isEmpty) return 0.0;
    final index = (percentile * (sorted.length - 1)).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  /// Profiles an active animation driving the widget tree over [frameCount] discrete intervals.
  static Future<EnterpriseFrameBudgetReport> profileAnimation(
    WidgetTester tester, {
    required Future<void> Function(WidgetTester tester) animationDriver,
    RefreshRateTarget target = RefreshRateTarget.fps120,
    int steps = 10,
    Duration stepDuration = const Duration(milliseconds: 16),
  }) async {
    final recordedDurations = <double>[];
    final stopwatch = Stopwatch();

    for (int i = 0; i < steps; i++) {
      stopwatch.reset();
      stopwatch.start();

      await tester.pump(stepDuration);
      await animationDriver(tester);

      stopwatch.stop();
      recordedDurations.add(stopwatch.elapsedMicroseconds / 1000.0);
    }

    return evaluateFrameMetrics(recordedDurations, target: target);
  }

  /// Audits whether an animated or complex target is wrapped in a [RepaintBoundary].
  static RepaintIsolationReport auditRepaintIsolation(
    WidgetTester tester, {
    required Finder targetFinder,
  }) {
    expect(targetFinder, findsAtLeastNWidgets(1));
    final element = targetFinder.evaluate().first;

    // Check if the widget itself is RepaintBoundary
    final isDirectRepaint = element.widget is RepaintBoundary;

    // Count ancestor RepaintBoundaries
    int ancestorBoundaries = 0;
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget is RepaintBoundary) {
        ancestorBoundaries++;
      }
      return true;
    });

    final isIsolated = isDirectRepaint || ancestorBoundaries > 0;
    final diagnostic = isIsolated
        ? 'Target has proper rasterization isolation (${isDirectRepaint ? "Direct" : "$ancestorBoundaries Ancestor"} RepaintBoundary).'
        : 'Target lacks RepaintBoundary isolation; animated repaints will invalidate parent render trees.';

    return RepaintIsolationReport(
      hasRepaintBoundary: isDirectRepaint,
      isIsolated: isIsolated,
      ancestorBoundaryCount: ancestorBoundaries,
      diagnostic: diagnostic,
    );
  }
}
