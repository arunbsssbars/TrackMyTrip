import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Fluid Responsive Clamp Engine for Flutter (AQIL Frontier 4).
///
/// Ports the CSS `clamp(min, preferred, max)` continuous interpolation model
/// directly to Flutter. Seamlessly scales spacing, typography, and corner radii
/// between 320px compact mobile and 1280px desktop viewports.
class AqilFluid {
  /// Baseline minimum viewport boundary (Compact mobile, e.g. iPhone SE).
  static const double defaultMinViewport = 320.0;

  /// Baseline maximum viewport boundary (Desktop / Landscape kiosk).
  static const double defaultMaxViewport = 1280.0;

  /// Linearly interpolates a value between [min] and [max] clamped to [minViewport] and [maxViewport].
  ///
  /// Formula:
  /// t = (width - minVp) / (maxVp - minVp)
  /// value = min + t * (max - min)
  /// clamped = max(min, min(max, value))
  static double clampValue(
    double currentViewportWidth, {
    required double min,
    required double max,
    double minViewport = defaultMinViewport,
    double maxViewport = defaultMaxViewport,
  }) {
    if (min >= max) return min;
    if (minViewport >= maxViewport) return min;

    final clampedWidth = math.max(minViewport, math.min(maxViewport, currentViewportWidth));
    final t = (clampedWidth - minViewport) / (maxViewport - minViewport);

    return min + t * (max - min);
  }

  /// Computes fluid spacing based on current screen width.
  static double spacing(
    BuildContext context, {
    double min = 8.0,
    double max = 24.0,
    double minViewport = defaultMinViewport,
    double maxViewport = defaultMaxViewport,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    return clampValue(
      width,
      min: min,
      max: max,
      minViewport: minViewport,
      maxViewport: maxViewport,
    );
  }

  /// Computes fluid typography font size based on current screen width.
  static double fontSize(
    BuildContext context, {
    double min = 14.0,
    double max = 20.0,
    double minViewport = defaultMinViewport,
    double maxViewport = defaultMaxViewport,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    return clampValue(
      width,
      min: min,
      max: max,
      minViewport: minViewport,
      maxViewport: maxViewport,
    );
  }

  /// Computes fluid corner radius based on current screen width.
  static double radius(
    BuildContext context, {
    double min = 8.0,
    double max = 16.0,
    double minViewport = defaultMinViewport,
    double maxViewport = defaultMaxViewport,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    return clampValue(
      width,
      min: min,
      max: max,
      minViewport: minViewport,
      maxViewport: maxViewport,
    );
  }
}
