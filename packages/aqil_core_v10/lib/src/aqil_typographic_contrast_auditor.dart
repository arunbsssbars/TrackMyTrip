import 'package:flutter/material.dart';

/// Diagnostic result for typographic hierarchy analysis.
class TypographicContrastResult {
  final bool isHarmonious;
  final double sizeRatio;
  final int weightDelta;
  final String recommendation;

  const TypographicContrastResult({
    required this.isHarmonious,
    required this.sizeRatio,
    required this.weightDelta,
    required this.recommendation,
  });
}

/// Evaluates typographic contrast between headings and body copy according to Apple HIG & Figma typography standards.
class AqilTypographicContrastAuditor {
  /// Evaluates contrast between a primary heading and adjacent body/caption text.
  ///
  /// Criteria for world-class visual hierarchy:
  /// - Size ratio >= 1.35x OR
  /// - Font weight delta >= 200 (e.g., w700 bold vs w400 regular)
  static TypographicContrastResult evaluateContrast({
    required TextStyle heading,
    required TextStyle body,
  }) {
    final headingSize = heading.fontSize ?? 20.0;
    final bodySize = body.fontSize ?? 14.0;

    final ratio = headingSize > 0 && bodySize > 0
        ? (headingSize / bodySize)
        : 1.0;

    final headingWeight = (heading.fontWeight ?? FontWeight.bold).value;
    final bodyWeight = (body.fontWeight ?? FontWeight.normal).value;
    final weightDelta = (headingWeight - bodyWeight).abs();

    final hasAdequateSizeContrast = ratio >= 1.35;
    final hasAdequateWeightContrast = weightDelta >= 200;

    final isHarmonious = hasAdequateSizeContrast || hasAdequateWeightContrast;

    String recommendation = 'Typography hierarchy is distinct and readable.';
    if (!isHarmonious) {
      recommendation =
          'Weak visual hierarchy: heading (${headingSize}pt) and body (${bodySize}pt) are too close in scale ($ratio:1). Increase heading size to ${(bodySize * 1.4).toStringAsFixed(1)}pt or increase weight delta.';
    }

    return TypographicContrastResult(
      isHarmonious: isHarmonious,
      sizeRatio: ratio,
      weightDelta: weightDelta,
      recommendation: recommendation,
    );
  }
}

/// Harmonious typography pair container providing pre-calibrated contrast and optical tracking.
class AqilTypeHierarchy extends StatelessWidget {
  final String title;
  final String? subtitle;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;

  const AqilTypeHierarchy({
    super.key,
    required this.title,
    this.subtitle,
    this.titleStyle,
    this.subtitleStyle,
    this.spacing = 4.0,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final effectiveTitleStyle = titleStyle ??
        theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ) ??
        const TextStyle(
          fontSize: 18.0,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        );

    final effectiveSubtitleStyle = subtitleStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ??
              Colors.grey[600],
          fontSize: 14.0,
          letterSpacing: 0.1,
        ) ??
        const TextStyle(
          fontSize: 14.0,
          color: Colors.grey,
          letterSpacing: 0.1,
        );

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: effectiveTitleStyle,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        if (subtitle != null) ...[
          SizedBox(height: spacing),
          Text(
            subtitle!,
            style: effectiveSubtitleStyle,
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
        ],
      ],
    );
  }
}
