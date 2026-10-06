import 'package:flutter/material.dart';
import 'aqil_typographic_contrast_auditor.dart';
import 'aqil_surface_lighting.dart';
import 'aqil_status_pill.dart';

/// Comprehensive scorecard summarizing adherence to world-class IT industry design standards.
class AqilWorldClassScorecard {
  final double typographyScore;
  final double surfaceDepthScore;
  final double semanticColorScore;
  final double emptyStateScore;
  final double overallScore;
  final bool isWorldClass;
  final List<String> designRecommendations;

  const AqilWorldClassScorecard({
    required this.typographyScore,
    required this.surfaceDepthScore,
    required this.semanticColorScore,
    required this.emptyStateScore,
    required this.overallScore,
    required this.isWorldClass,
    required this.designRecommendations,
  });
}

/// Evaluator benchmark assessing UI components against industry-leading visual standards
/// established by Apple, Linear, Stripe, Airbnb, and Figma.
class AqilWorldClassDesignBenchmark {
  /// Evaluates an app screen or theme configuration.
  static AqilWorldClassScorecard evaluateScreen({
    required TextStyle headingStyle,
    required TextStyle bodyStyle,
    required Color backgroundColor,
    required Color surfaceColor,
    required List<Color> semanticAlertColors,
    required bool hasActionableEmptyStates,
  }) {
    final recommendations = <String>[];

    // 1. Typography Contrast (Apple / Figma)
    final typoResult = AqilTypographicContrastAuditor.evaluateContrast(
      heading: headingStyle,
      body: bodyStyle,
    );
    final typoScore = typoResult.isHarmonious ? 100.0 : 60.0;
    if (!typoResult.isHarmonious) {
      recommendations.add('Typography: ${typoResult.recommendation}');
    }

    // 2. Surface Depth & Luminance Layering (Linear / Apple Pro)
    final depthMultiplier = AqilSurfaceDepthAuditor.evaluateLuminanceContrast(
      background: backgroundColor,
      surface: surfaceColor,
    );
    final surfaceDepthScore = depthMultiplier * 100.0;
    if (depthMultiplier < 0.8) {
      recommendations.add(
        'Surface Depth: Dark mode surfaces have insufficient luminance separation. Apply AqilSurfaceLighting or AqilGlassMorphismCard.',
      );
    }

    // 3. Semantic Color Harmonization (Stripe / GitHub)
    int harshCount = 0;
    for (final color in semanticAlertColors) {
      if (AqilSemanticPaletteAuditor.isHarshNeon(color)) {
        harshCount++;
      }
    }
    final semanticColorScore = harshCount == 0
        ? 100.0
        : (100.0 - (harshCount * 25.0)).clamp(0.0, 100.0);
    if (harshCount > 0) {
      recommendations.add(
        'Palette: $harshCount semantic colors are harsh neons. Calibrate using AqilStatusPill pastel tints.',
      );
    }

    // 4. Actionable Empty States (Airbnb / Stripe)
    final emptyStateScore = hasActionableEmptyStates ? 100.0 : 50.0;
    if (!hasActionableEmptyStates) {
      recommendations.add(
        'Zero State: Empty lists/screens lack actionable empty state guidance. Utilize AqilEmptyState.',
      );
    }

    // Composite Score
    final overall = (typoScore * 0.3) +
        (surfaceDepthScore * 0.3) +
        (semanticColorScore * 0.2) +
        (emptyStateScore * 0.2);

    final isWorldClass = overall >= 85.0;

    return AqilWorldClassScorecard(
      typographyScore: typoScore,
      surfaceDepthScore: surfaceDepthScore,
      semanticColorScore: semanticColorScore,
      emptyStateScore: emptyStateScore,
      overallScore: overall,
      isWorldClass: isWorldClass,
      designRecommendations: recommendations,
    );
  }
}
