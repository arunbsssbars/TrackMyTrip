/// Severity level of a visual UX gap.
enum AqilGapSeverity {
  critical, // Broken UX, accidental tap hazard, severe contrast clash
  warning,  // Poor hierarchy, off-grid cadence, competitive primary CTAs
  polish,   // Subtle typographic weight or minor micro-spacing improvements
}

/// A specific visual UX gap detected by the auditing engine.
class AqilVisualGap {
  final String category; // 'Hierarchy', 'Crowding', 'SpatialRhythm', 'CognitiveLoad'
  final AqilGapSeverity severity;
  final String description;
  final String recommendation;
  final String? codeSnippetFix;

  const AqilVisualGap({
    required this.category,
    required this.severity,
    required this.description,
    required this.recommendation,
    this.codeSnippetFix,
  });

  @override
  String toString() =>
      '[${severity.name.toUpperCase()}] ($category) $description => $recommendation';
}
