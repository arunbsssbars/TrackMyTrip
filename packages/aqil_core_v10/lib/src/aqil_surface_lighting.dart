import 'package:flutter/material.dart';

/// Specular rim lighting and surface depth container.
///
/// Implements top-edge ambient specular rim highlights and subtle directional
/// surface gradient lighting (Linear, Apple Pro hardware styling) to prevent
/// visual banding and lifeless flat digital surfaces.
class AqilSurfaceLighting extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? surfaceColor;
  final double specularIntensity;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const AqilSurfaceLighting({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.surfaceColor,
    this.specularIntensity = 0.15,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final baseSurface = surfaceColor ??
        (isDark ? const Color(0xFF161618) : Colors.white);

    final highlightAlpha = isDark ? (specularIntensity * 0.9) : (specularIntensity * 0.4);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: baseSurface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: highlightAlpha * 0.8)
              : Colors.black.withValues(alpha: 0.06),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 12.0,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isDark
                ? Colors.white.withValues(alpha: highlightAlpha * 0.6)
                : Colors.white,
            baseSurface,
          ],
          stops: const [0.0, 0.4],
        ),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Static and runtime auditor for surface depth and luminance layering.
///
/// Audits dark themes to verify that cards, dialogs, and sheets are elevated
/// visually above the background canvas rather than using flat 0x000000 across all tiers.
class AqilSurfaceDepthAuditor {
  /// Evaluates background vs card surface luminance delta.
  ///
  /// Returns a quality score between 0.0 and 1.0.
  static double evaluateLuminanceContrast({
    required Color background,
    required Color surface,
  }) {
    final bgLum = background.computeLuminance();
    final surfLum = surface.computeLuminance();
    final delta = (surfLum - bgLum).abs();

    if (delta < 0.005) {
      // Virtually identical: flat depth failure
      return 0.3;
    } else if (delta < 0.02) {
      // Subtle depth
      return 0.8;
    } else {
      // Clear visual layering
      return 1.0;
    }
  }

  /// Verifies if a surface uses top specular edge highlights.
  static bool hasSpecularHighlight(BoxDecoration decoration) {
    if (decoration.border == null && decoration.gradient == null) {
      return false;
    }
    return true;
  }
}
