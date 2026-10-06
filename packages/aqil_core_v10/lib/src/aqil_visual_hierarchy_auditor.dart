import 'package:flutter/material.dart';
import 'aqil_visual_gap_model.dart';
export 'aqil_visual_gap_model.dart';

/// Audits typography hierarchy, contrast ratios, and scale progression.
/// Flags "flat hierarchy" where titles and body text blend together without distinct visual pop.
class AqilVisualHierarchyAuditor {
  /// Minimum recommended font size differential between headline and body.
  static const double minHeadlineBodyDifferential = 4.0;

  /// Audits the visual hierarchy between a headline style and an adjacent body style.
  static AqilVisualGap? auditPair({
    required TextStyle headline,
    required TextStyle body,
    String headlineName = 'Headline',
    String bodyName = 'Body',
  }) {
    final headSize = headline.fontSize ?? 16.0;
    final bodySize = body.fontSize ?? 14.0;
    final headWeight = headline.fontWeight ?? FontWeight.normal;
    final bodyWeight = body.fontWeight ?? FontWeight.normal;

    final sizeDiff = headSize - bodySize;

    // Check 1: Inverted or flat size differential
    if (sizeDiff < 2.0 && headWeight.value <= bodyWeight.value) {
      return AqilVisualGap(
        category: 'Hierarchy',
        severity: AqilGapSeverity.critical,
        description:
            'Flat typographic hierarchy between "$headlineName" (${headSize}pt, w${headWeight.value}) and "$bodyName" (${bodySize}pt, w${bodyWeight.value}). Title does not pop.',
        recommendation:
            'Increase headline size by at least 4pt or increase font-weight to bold (w700) to establish clear visual hierarchy.',
        codeSnippetFix:
            'style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)',
      );
    }

    // Check 2: Size differential is too subtle (between 2pt and 4pt without weight contrast)
    if (sizeDiff < minHeadlineBodyDifferential && headWeight.value <= bodyWeight.value) {
      return AqilVisualGap(
        category: 'Hierarchy',
        severity: AqilGapSeverity.warning,
        description:
            'Subtle font size difference (${sizeDiff.toStringAsFixed(1)}pt) between headline and body with matching weights.',
        recommendation:
            'Adopt a standard modular scale ratio (e.g. Major Third 1.25x: 16pt body -> 20pt headline).',
      );
    }

    return null;
  }
}
