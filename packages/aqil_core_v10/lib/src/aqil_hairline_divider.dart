import 'package:flutter/material.dart';

/// Semantic role of a subtle hairline divider.
enum AqilDividerOrientation {
  horizontal,
  vertical,
}

/// A subtle hairline divider inspired by Linear, Apple iOS, and GitHub.
/// Replaces heavy, opaque grey lines with soft 0.8px translucent border tints
/// that adapt naturally to light and dark theme surfaces.
class AqilHairlineDivider extends StatelessWidget {
  final double thickness;
  final double? indent;
  final double? endIndent;
  final Color? color;
  final AqilDividerOrientation orientation;

  const AqilHairlineDivider({
    super.key,
    this.thickness = 0.8,
    this.indent,
    this.endIndent,
    this.color,
    this.orientation = AqilDividerOrientation.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    final dividerColor = color ?? defaultColor;

    if (orientation == AqilDividerOrientation.vertical) {
      return Container(
        width: thickness,
        margin: EdgeInsets.only(
          top: indent ?? 0,
          bottom: endIndent ?? 0,
        ),
        color: dividerColor,
      );
    }

    return Container(
      height: thickness,
      margin: EdgeInsets.only(
        left: indent ?? 0,
        right: endIndent ?? 0,
      ),
      color: dividerColor,
    );
  }
}
