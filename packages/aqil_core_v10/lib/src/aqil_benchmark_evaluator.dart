/// Benchmark UI conformance score across top 5 design pillars:
/// 1. Motion & Physics (Spring curves, tap bounce)
/// 2. Haptic Choreography (Discrete tactile feedback)
/// 3. Surface Optics & Glassmorphism (Frosted glass contrast)
/// 4. Typographic & Numeric Stability (Tabular figures, rolling counters)
/// 5. Ergonomics & Reachability (Thumb comfort zone >= 60%)
class AqilBenchmarkScore {
  final double motionScore; // 0.0 - 1.0
  final double hapticScore;
  final double opticsScore;
  final double typographyScore;
  final double reachabilityScore;

  const AqilBenchmarkScore({
    required this.motionScore,
    required this.hapticScore,
    required this.opticsScore,
    required this.typographyScore,
    required this.reachabilityScore,
  });

  double get compositeScore =>
      (motionScore + hapticScore + opticsScore + typographyScore + reachabilityScore) / 5.0;

  bool get passesWorldClassTier => compositeScore >= 0.85;

  Map<String, dynamic> toJson() => {
        'compositeScore': (compositeScore * 100).toStringAsFixed(1),
        'motion': (motionScore * 100).toStringAsFixed(1),
        'haptics': (hapticScore * 100).toStringAsFixed(1),
        'optics': (opticsScore * 100).toStringAsFixed(1),
        'typography': (typographyScore * 100).toStringAsFixed(1),
        'reachability': (reachabilityScore * 100).toStringAsFixed(1),
        'isWorldClass': passesWorldClassTier,
      };
}

/// Evaluator comparing any Flutter screen against the 5 world-class UI benchmarks.
class AqilBenchmarkEvaluator {
  /// Computes the benchmark score for a given screen's profile metrics.
  static AqilBenchmarkScore evaluate({
    required bool hasSpringOrBounce,
    required bool hasTactileHaptics,
    required bool passesOpticsContrast,
    required bool hasTabularNumbersOrRolling,
    required double thumbReachabilityRatio,
  }) {
    return AqilBenchmarkScore(
      motionScore: hasSpringOrBounce ? 1.0 : 0.4,
      hapticScore: hasTactileHaptics ? 1.0 : 0.3,
      opticsScore: passesOpticsContrast ? 1.0 : 0.5,
      typographyScore: hasTabularNumbersOrRolling ? 1.0 : 0.5,
      reachabilityScore: thumbReachabilityRatio.clamp(0.0, 1.0),
    );
  }
}
