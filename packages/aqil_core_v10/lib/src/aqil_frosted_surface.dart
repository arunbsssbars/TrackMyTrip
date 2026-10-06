import 'dart:ui';
import 'package:flutter/material.dart';

/// Optics and contrast audit result for frosted glass / blurred surfaces.
class AqilSurfaceOpticsResult {
  final double blurSigma;
  final double surfaceOpacity;
  final bool hasBackdropFilter;
  final double estimatedContrastRatio;
  final bool passesWcagAa;

  const AqilSurfaceOpticsResult({
    required this.blurSigma,
    required this.surfaceOpacity,
    required this.hasBackdropFilter,
    required this.estimatedContrastRatio,
    required this.passesWcagAa,
  });

  @override
  String toString() =>
      'Optics: sigma=$blurSigma, opacity=$surfaceOpacity, contrast=${estimatedContrastRatio.toStringAsFixed(1)}:1, passesAa=$passesWcagAa';
}

/// A drop-in frosted glass / glassmorphic container inspired by Flighty & Amie.
/// Automatically applies balanced blur, translucent tint, and subtle 1px border.
class AqilFrostedGlass extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final double borderRadius;
  final Color? tintColor;
  final double borderOpacity;
  final EdgeInsetsGeometry padding;

  const AqilFrostedGlass({
    super.key,
    required this.child,
    this.blurSigma = 16.0,
    this.borderRadius = 16.0,
    this.tintColor,
    this.borderOpacity = 0.12,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultTint = isDark
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.65);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: borderOpacity)
        : Colors.black.withValues(alpha: borderOpacity);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tintColor ?? defaultTint,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: child,
        ),
      ),
    );
  }

  /// Audits the optics of this frosted container.
  AqilSurfaceOpticsResult auditOptics({Color textColor = Colors.white}) {
    // Standard baseline evaluation
    final effectiveOpacity = tintColor?.a ?? 0.55;
    // Estimated contrast ratio on dynamic background:
    final estimatedRatio = 3.0 + (effectiveOpacity * 5.0);
    return AqilSurfaceOpticsResult(
      blurSigma: blurSigma,
      surfaceOpacity: effectiveOpacity,
      hasBackdropFilter: true,
      estimatedContrastRatio: estimatedRatio,
      passesWcagAa: estimatedRatio >= 4.5,
    );
  }
}
