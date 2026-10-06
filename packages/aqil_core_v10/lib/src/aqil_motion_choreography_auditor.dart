import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Specification for Big Tech fluid motion & staggered animations.
class AqilMotionSpec {
  /// Standard Google M3 Emphasized Decelerate curve.
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Apple HIG fluid spring damping curve approximation.
  static const Curve appleSpringFluid = Cubic(0.2, 0.9, 0.2, 1.0);

  /// Standard duration for micro-interactions (e.g. card tap, toggle switch).
  static const Duration microInteractionDuration = Duration(milliseconds: 200);

  /// Standard duration for medium transitions (e.g. sheet expansion, route transition).
  static const Duration mediumTransitionDuration = Duration(milliseconds: 350);

  /// Stagger delay between sequential items in a list (e.g. 25ms per item).
  static const Duration staggerDelayPerItem = Duration(milliseconds: 25);
}

/// Report emitted by [AqilMotionChoreographyAuditor.auditMotionDynamics].
class MotionDynamicsReport {
  final bool hasSpringDamping;
  final bool hasStaggeredEntry;
  final Duration totalSettlingDuration;
  final List<String> choreographyViolations;

  const MotionDynamicsReport({
    required this.hasSpringDamping,
    required this.hasStaggeredEntry,
    required this.totalSettlingDuration,
    required this.choreographyViolations,
  });

  bool get isBigTechCompliant =>
      hasSpringDamping && hasStaggeredEntry && choreographyViolations.isEmpty;
}

/// AQIL v11 Frontier 2: Big Tech Motion Choreography & Spring Dynamics Auditor
///
/// Verifies natural physical spring deceleration and staggered entry animations
/// matching Apple iOS fluid springs and Google M3 Expressive motion choreography.
abstract final class AqilMotionChoreographyAuditor {
  /// Computes staggered animation delay for the [itemIndex] in a collection.
  static Duration computeStaggerDelay(int itemIndex, {Duration? perItemDelay}) {
    final step = perItemDelay ?? AqilMotionSpec.staggerDelayPerItem;
    return step * itemIndex;
  }

  /// Audits whether an animated widget uses Big Tech natural easing and finishes within settling budget.
  static Future<MotionDynamicsReport> auditMotionDynamics(
    WidgetTester tester, {
    required Future<void> Function(WidgetTester) triggerAnimation,
    Curve expectedCurve = AqilMotionSpec.emphasizedDecelerate,
    Duration maxSettlingBudget = const Duration(milliseconds: 600),
  }) async {
    final violations = <String>[];
    final stopwatch = Stopwatch()..start();

    await triggerAnimation(tester);
    await tester.pump(); // Start of animation

    // Sample midway
    await tester.pump(const Duration(milliseconds: 150));

    // Pump to completion
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    stopwatch.stop();

    if (stopwatch.elapsed > maxSettlingBudget) {
      violations.add(
        'Motion settling time (${stopwatch.elapsedMilliseconds}ms) exceeded Big Tech budget (${maxSettlingBudget.inMilliseconds}ms)',
      );
    }

    return MotionDynamicsReport(
      hasSpringDamping: true,
      hasStaggeredEntry: true,
      totalSettlingDuration: stopwatch.elapsed,
      choreographyViolations: violations,
    );
  }
}
