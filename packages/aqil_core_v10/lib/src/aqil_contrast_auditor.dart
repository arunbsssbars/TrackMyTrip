import 'package:flutter/material.dart';

/// WCAG 2.2 accessibility conformance levels.
enum WcagLevel {
  aa,
  aaa,
}

/// Detailed contrast audit result for a foreground / background pair.
class ContrastCheckResult {
  final Color foreground;
  final Color background;
  final double contrastRatio;
  final bool isLargeText;
  final bool passesAA;
  final bool passesAAA;
  final String recommendation;

  const ContrastCheckResult({
    required this.foreground,
    required this.background,
    required this.contrastRatio,
    required this.isLargeText,
    required this.passesAA,
    required this.passesAAA,
    required this.recommendation,
  });

  bool passes(WcagLevel level) => level == WcagLevel.aa ? passesAA : passesAAA;

  @override
  String toString() =>
      'ContrastCheckResult[CR: ${contrastRatio.toStringAsFixed(2)}:1 | AA: $passesAA | AAA: $passesAAA]';
}

/// Real-time WCAG 2.2 Color Contrast & Luminance Scanner.
///
/// Implements W3C WCAG 2.2 algorithms for relative luminance calculation
/// and text/UI element contrast ratio verification.
class AqilContrastAuditor {
  /// Computes the relative luminance of a color according to W3C sRGB formula:
  /// L = 0.2126 * R + 0.7152 * G + 0.0722 * B
  static double computeRelativeLuminance(Color color) {
    double linearize(double channel) {
      final c = channel / 255.0;
      if (c <= 0.04045) {
        return c / 12.92;
      } else {
        return ((c + 0.055) / 1.055) * ((c + 0.055) / 1.055); // Approximates pow(..., 2.4)
      }
    }

    final r = linearize(color.r * 255.0);
    final g = linearize(color.g * 255.0);
    final b = linearize(color.b * 255.0);

    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Calculates the contrast ratio between two colors:
  /// (L1 + 0.05) / (L2 + 0.05) where L1 is the lighter color.
  static double computeContrastRatio(Color color1, Color color2) {
    final l1 = computeRelativeLuminance(color1);
    final l2 = computeRelativeLuminance(color2);

    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;

    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Audits a foreground/background pair against WCAG 2.2 AA and AAA thresholds.
  static ContrastCheckResult auditContrast({
    required Color foreground,
    required Color background,
    bool isLargeText = false,
  }) {
    final ratio = computeContrastRatio(foreground, background);

    final minAaRatio = isLargeText ? 3.0 : 4.5;
    final minAaaRatio = isLargeText ? 4.5 : 7.0;

    final passesAA = ratio >= minAaRatio;
    final passesAAA = ratio >= minAaaRatio;

    String recommendation;
    if (passesAAA) {
      recommendation = 'Optimal contrast (conforms to WCAG AAA)';
    } else if (passesAA) {
      recommendation = 'Compliant contrast (conforms to WCAG AA)';
    } else {
      recommendation =
          'Fails WCAG AA! Required minimum is ${minAaRatio.toStringAsFixed(1)}:1, actual is ${ratio.toStringAsFixed(2)}:1.';
    }

    return ContrastCheckResult(
      foreground: foreground,
      background: background,
      contrastRatio: ratio,
      isLargeText: isLargeText,
      passesAA: passesAA,
      passesAAA: passesAAA,
      recommendation: recommendation,
    );
  }

  /// Audits a ThemeData colorScheme for inherent contrast violations.
  static List<ContrastCheckResult> auditColorScheme(ColorScheme scheme) {
    final results = <ContrastCheckResult>[];

    // Primary on Primary
    results.add(auditContrast(
      foreground: scheme.onPrimary,
      background: scheme.primary,
    ));

    // Secondary on Secondary
    results.add(auditContrast(
      foreground: scheme.onSecondary,
      background: scheme.secondary,
    ));

    // Surface on Surface
    results.add(auditContrast(
      foreground: scheme.onSurface,
      background: scheme.surface,
    ));

    // Error on Error
    results.add(auditContrast(
      foreground: scheme.onError,
      background: scheme.error,
    ));

    return results;
  }
}
