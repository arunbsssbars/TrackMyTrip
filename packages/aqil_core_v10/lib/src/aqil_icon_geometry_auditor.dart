import 'package:flutter/material.dart';

/// Semantic role of an icon button.
class AqilIconGeometry {
  /// Computes whether an icon's visible size vs its bounding touch target meets WCAG 2.2 AA (>= 44x44dp).
  static bool meetsMinimumTouchTarget(Size targetSize) {
    return targetSize.width >= 44.0 && targetSize.height >= 44.0;
  }

  /// Evaluates icon visual bounding balance.
  /// Recommends consistent 20dp or 24dp inner glyph within 44dp or 48dp touch container.
  static String? auditIconProportions({
    required double glyphSize,
    required double containerSize,
    String context = 'IconButton',
  }) {
    if (containerSize < 44.0) {
      return '$context container size (${containerSize}dp) violates accessible touch target minimum (44dp).';
    }

    final ratio = glyphSize / containerSize;
    if (ratio < 0.35) {
      return '$context glyph ($glyphSize dp) is disproportionately small for its ${containerSize}dp container. Recommend 20-24dp glyph.';
    }

    if (ratio > 0.70) {
      return '$context glyph ($glyphSize dp) is cramped against container boundary ($containerSize dp). Risk of visual tension.';
    }

    return null;
  }
}
