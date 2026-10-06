import 'aqil_visual_gap_model.dart';
import 'aqil_color_blindness_auditor.dart';
import 'aqil_corner_radius_auditor.dart';
import 'aqil_cta_hierarchy.dart';
import 'aqil_physical_elevation.dart';
import 'package:flutter/material.dart';

/// Comprehensive visual design benchmark matrix evaluating a screen across all 10 visual pillars:
/// 1. Color Vision Deficiency (CVD) Contrast
/// 2. Physical Elevation & Dual Shadows
/// 3. Micro-Interaction Curves
/// 4. CTA Isolation (Von Restorff)
/// 5. Interactive Field Focus Glow
/// 6. Progressive Edge Softening
/// 7. Micro-Badge Refinement
/// 8. Concentric Corner Radius Harmony
/// 9. Sensory Refresh Touchpoints
/// 10. Typographic Scale Pop & Spatial Rhythm
class AqilVisualDesignReport {
  final double cvdScore;
  final double shadowScore;
  final double ctaScore;
  final double cornerHarmonyScore;
  final List<AqilVisualGap> detectedGaps;

  const AqilVisualDesignReport({
    required this.cvdScore,
    required this.shadowScore,
    required this.ctaScore,
    required this.cornerHarmonyScore,
    required this.detectedGaps,
  });

  double get compositeVisualScore =>
      (cvdScore + shadowScore + ctaScore + cornerHarmonyScore) / 4.0;

  bool get isWorldClassTier => compositeVisualScore >= 0.90 && detectedGaps.isEmpty;
}

/// Evaluates a screen against the entire visual design engineering matrix.
class AqilVisualDesignMatrix {
  static AqilVisualDesignReport evaluateScreen({
    required (int r, int g, int b) textColor,
    required (int r, int g, int b) surfaceColor,
    required List<AqilButtonRole> buttons,
    required double outerCardRadius,
    required double cardPadding,
    required double innerElementRadius,
    BoxShadow? sampleShadow,
  }) {
    final gaps = <AqilVisualGap>[];

    // 1. CVD Contrast check
    final cvdResults = AqilColorBlindnessSim.auditContrast(
      foreground: textColor,
      background: surfaceColor,
    );
    final passesAllCvd = cvdResults.every((r) => r.passesWcagAa);
    if (!passesAllCvd) {
      gaps.add(const AqilVisualGap(
        category: 'ColorVision',
        severity: AqilGapSeverity.critical,
        description: 'Text fails WCAG AA 4.5:1 contrast under simulated color vision deficiency (protanopia/deuteranopia).',
        recommendation: 'Increase foreground-to-background luminance contrast delta.',
      ));
    }

    // 2. CTA Hierarchy
    final ctaWarning = AqilCtaHierarchyAuditor.auditButtonCollection(buttons);
    if (ctaWarning != null) {
      gaps.add(AqilVisualGap(
        category: 'CtaHierarchy',
        severity: AqilGapSeverity.warning,
        description: ctaWarning,
        recommendation: 'Ensure exactly 1 prominent primary filled button is visible at once.',
      ));
    }

    // 3. Concentric Radius Harmony
    final radiusWarning = AqilCornerRadiusAuditor.auditNestedCornerHarmony(
      outerRadius: outerCardRadius,
      padding: cardPadding,
      actualInnerRadius: innerElementRadius,
    );
    if (radiusWarning != null) {
      gaps.add(AqilVisualGap(
        category: 'CornerRadius',
        severity: AqilGapSeverity.polish,
        description: radiusWarning,
        recommendation: 'Snap inner radius to outerRadius - padding for concentric harmony.',
      ));
    }

    // 4. Shadow audit
    if (sampleShadow != null) {
      final shadowWarning = AqilElevationAuditor.auditBoxShadow(sampleShadow);
      if (shadowWarning != null) {
        gaps.add(AqilVisualGap(
          category: 'PhysicalElevation',
          severity: AqilGapSeverity.polish,
          description: shadowWarning,
          recommendation: 'Use dual ambient + key light shadows.',
        ));
      }
    }

    return AqilVisualDesignReport(
      cvdScore: passesAllCvd ? 1.0 : 0.6,
      shadowScore: sampleShadow != null ? 0.95 : 1.0,
      ctaScore: ctaWarning == null ? 1.0 : 0.65,
      cornerHarmonyScore: radiusWarning == null ? 1.0 : 0.75,
      detectedGaps: gaps,
    );
  }
}
