import 'package:flutter/material.dart';

/// Report on typography hierarchy and line-height compliance across accessibility font scales.
class AqilTypeScaleAuditReport {
  final int totalAuditedStyles;
  final int insufficientLineHeightCount;
  final List<String> warnings;

  const AqilTypeScaleAuditReport({
    required this.totalAuditedStyles,
    required this.insufficientLineHeightCount,
    required this.warnings,
  });

  bool get isCompliant => insufficientLineHeightCount == 0;
}

/// Adaptive Dynamic Type Scale & Hierarchy Auditor.
/// Asserts that typography scales gracefully under OS accessibility font enlargement (1.3x - 1.5x)
/// and maintains minimum proportional line heights (>= 1.2x font size) to avoid overlapping text lines.
class AqilTypeScaleAuditor {
  /// Minimum recommended proportional line-height multiplier.
  static const double minProportionalHeight = 1.20;

  /// Audits a single TextStyle for accessibility line-height headroom.
  static String? auditStyle(TextStyle? style, {String name = 'style'}) {
    if (style == null) return null;

    final fontSize = style.fontSize ?? 14.0;
    final heightMultiplier = style.height ?? 1.2;

    if (heightMultiplier < minProportionalHeight) {
      return 'TextStyle "$name" (size ${fontSize}dp) has height multiplier of ${heightMultiplier.toStringAsFixed(2)} < $minProportionalHeight. Risk of line collision at 1.5x font scale.';
    }
    return null;
  }

  /// Audits an entire TextTheme across all Material 3 typographic tokens.
  static AqilTypeScaleAuditReport auditTheme(TextTheme theme) {
    final styles = <String, TextStyle?>{
      'displayLarge': theme.displayLarge,
      'displayMedium': theme.displayMedium,
      'displaySmall': theme.displaySmall,
      'headlineLarge': theme.headlineLarge,
      'headlineMedium': theme.headlineMedium,
      'headlineSmall': theme.headlineSmall,
      'titleLarge': theme.titleLarge,
      'titleMedium': theme.titleMedium,
      'titleSmall': theme.titleSmall,
      'bodyLarge': theme.bodyLarge,
      'bodyMedium': theme.bodyMedium,
      'bodySmall': theme.bodySmall,
      'labelLarge': theme.labelLarge,
      'labelMedium': theme.labelMedium,
      'labelSmall': theme.labelSmall,
    };

    final warnings = <String>[];
    int insufficient = 0;

    for (final entry in styles.entries) {
      final warning = auditStyle(entry.value, name: entry.key);
      if (warning != null) {
        insufficient++;
        warnings.add(warning);
      }
    }

    return AqilTypeScaleAuditReport(
      totalAuditedStyles: styles.length,
      insufficientLineHeightCount: insufficient,
      warnings: warnings,
    );
  }
}
