import 'package:flutter/material.dart';

/// Dynamic optical letter spacing calculator based on typography font size.
/// Implements Apple San Francisco / Inter dynamic tracking table:
/// Large display titles require tighter tracking (negative letter-spacing),
/// while small captions require loose tracking (positive letter-spacing) for legibility.
class AqilDynamicTracking {
  /// Computes the recommended optical letter spacing for any given font size.
  static double computeTracking(double fontSize) {
    if (fontSize >= 32.0) {
      // Display headlines: tight tracking (-0.02em to -0.015em)
      return -fontSize * 0.02;
    } else if (fontSize >= 20.0) {
      // Titles: slightly tight tracking (-0.01em)
      return -fontSize * 0.01;
    } else if (fontSize <= 12.0) {
      // Captions & Micro-text: loose tracking (+0.03em)
      return fontSize * 0.03;
    } else {
      // Standard body (14px - 18px): neutral to slight positive tracking
      return 0.0;
    }
  }

  /// Applies optical letter spacing to a TextStyle if not explicitly set.
  static TextStyle applyOpticalTracking(TextStyle style) {
    final size = style.fontSize ?? 14.0;
    final tracking = computeTracking(size);
    return style.copyWith(letterSpacing: style.letterSpacing ?? tracking);
  }
}
