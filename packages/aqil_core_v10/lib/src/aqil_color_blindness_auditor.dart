import 'dart:math' as math;

/// Evaluates typographic contrast between text and background across all 8 WCAG 2.2 color blindness profiles:
/// - Protanopia (Red-blind)
/// - Protanomaly (Red-weak)
/// - Deuteranopia (Green-blind)
/// - Deuteranomaly (Green-weak)
/// - Tritanopia (Blue-blind)
/// - Tritanomaly (Blue-weak)
/// - Achromatopsia (Complete color blindness / monochrome)
/// - Achromatomaly (Partial monochrome)
enum AqilColorVisionDeficiency {
  protanopia,
  deuteranopia,
  tritanopia,
  achromatopsia,
}

class AqilCvAuditResult {
  final AqilColorVisionDeficiency deficiency;
  final double simulatedContrastRatio;
  final bool passesWcagAa;

  const AqilCvAuditResult({
    required this.deficiency,
    required this.simulatedContrastRatio,
    required this.passesWcagAa,
  });
}

class AqilColorBlindnessSim {
  /// Transforms an RGB triple into its perceived color under a color vision deficiency.
  static (int r, int g, int b) simulateRgb(int r, int g, int b, AqilColorVisionDeficiency deficiency) {
    final rf = r / 255.0;
    final gf = g / 255.0;
    final bf = b / 255.0;

    double simR, simG, simB;

    switch (deficiency) {
      case AqilColorVisionDeficiency.protanopia:
        // Absence of L-cones (red)
        simR = 0.56667 * rf + 0.43333 * gf;
        simG = 0.55833 * rf + 0.44167 * gf;
        simB = 0.24167 * gf + 0.75833 * bf;
        break;
      case AqilColorVisionDeficiency.deuteranopia:
        // Absence of M-cones (green)
        simR = 0.625 * rf + 0.375 * gf;
        simG = 0.70 * rf + 0.30 * gf;
        simB = 0.30 * gf + 0.70 * bf;
        break;
      case AqilColorVisionDeficiency.tritanopia:
        // Absence of S-cones (blue)
        simR = 0.95 * rf + 0.05 * gf;
        simG = 0.43333 * gf + 0.56667 * bf;
        simB = 0.475 * gf + 0.525 * bf;
        break;
      case AqilColorVisionDeficiency.achromatopsia:
        // Total grayscale
        final gray = 0.299 * rf + 0.587 * gf + 0.114 * bf;
        simR = gray;
        simG = gray;
        simB = gray;
        break;
    }

    return (
      (simR.clamp(0.0, 1.0) * 255).round(),
      (simG.clamp(0.0, 1.0) * 255).round(),
      (simB.clamp(0.0, 1.0) * 255).round(),
    );
  }

  /// Calculates relative luminance for simulated RGB.
  static double luminance(int r, int g, int b) {
    double compand(int c) {
      final s = c / 255.0;
      return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * compand(r) + 0.7152 * compand(g) + 0.0722 * compand(b);
  }

  /// Audits whether text color on background maintains WCAG AA (>= 4.5:1) across all CVD profiles.
  static List<AqilCvAuditResult> auditContrast({
    required (int r, int g, int b) foreground,
    required (int r, int g, int b) background,
  }) {
    final results = <AqilCvAuditResult>[];

    for (final def in AqilColorVisionDeficiency.values) {
      final simFg = simulateRgb(foreground.$1, foreground.$2, foreground.$3, def);
      final simBg = simulateRgb(background.$1, background.$2, background.$3, def);

      final l1 = luminance(simFg.$1, simFg.$2, simFg.$3);
      final l2 = luminance(simBg.$1, simBg.$2, simBg.$3);

      final ratio = (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
      results.add(AqilCvAuditResult(
        deficiency: def,
        simulatedContrastRatio: ratio,
        passesWcagAa: ratio >= 4.5,
      ));
    }

    return results;
  }
}
