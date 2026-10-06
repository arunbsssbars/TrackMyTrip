import 'aqil_visual_hierarchy_auditor.dart';

/// Audits vertical and horizontal spacing cadence between sibling layout elements.
/// Detects awkward, off-rhythm gaps that break the fluid 4-point design system cadence.
class AqilSpatialRhythmAuditor {
  /// Evaluates a sequence of vertical spacing intervals in a column or view.
  static List<AqilVisualGap> auditSpacingSequence(List<double> spacings, {String context = 'Column'}) {
    final gaps = <AqilVisualGap>[];

    for (int i = 0; i < spacings.length; i++) {
      final space = spacings[i];

      // Check 1: Micro-gap collision (spacing < 4dp between unrelated siblings)
      if (space > 0 && space < 4.0) {
        gaps.add(AqilVisualGap(
          category: 'SpatialRhythm',
          severity: AqilGapSeverity.warning,
          description:
              'Cramped micro-gap (${space.toStringAsFixed(1)}dp) between elements in $context causes visual collision.',
          recommendation:
              'Maintain at least 8dp or 12dp whitespace separation between distinct layout blocks.',
        ));
      } else if (space >= 4.0 && space % 4 != 0) {
        // Check 2: Off-grid awkward spacing (not divisible by 4)
        final nearest = (space / 4).round() * 4.0;
        gaps.add(AqilVisualGap(
          category: 'SpatialRhythm',
          severity: AqilGapSeverity.polish,
          description:
              'Spacing of ${space.toStringAsFixed(1)}dp in $context does not conform to the 4-point harmonic design grid.',
          recommendation:
              'Snap spacing to ${nearest.toStringAsFixed(0)}dp (nearest 4-pt grid token).',
          codeSnippetFix: 'SizedBox(height: ${nearest.toStringAsFixed(0)}.0)',
        ));
      }
    }

    return gaps;
  }
}
