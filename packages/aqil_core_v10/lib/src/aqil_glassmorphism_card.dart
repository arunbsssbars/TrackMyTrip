import 'dart:ui';
import 'package:flutter/material.dart';

/// Next-generation glassmorphic card container (Apple iOS 18 / visionOS style).
///
/// Combines multi-stop specular gradient border strokes, backdrop blur filtering,
/// and diffuse ambient lighting to create authentic physical translucency.
class AqilGlassMorphismCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final Color? surfaceColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  const AqilGlassMorphismCard({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.blurSigma = 20.0,
    this.surfaceColor,
    this.padding = const EdgeInsets.all(18.0),
    this.margin = EdgeInsets.zero,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final baseTint = surfaceColor ??
        (isDark ? const Color(0xFF1E1E24) : Colors.white);

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: baseTint.withValues(alpha: isDark ? 0.60 : 0.70),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.65),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 24.0,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: (isDark ? Colors.white : Colors.black)
                .withValues(alpha: isDark ? 0.04 : 0.02),
            blurRadius: 4.0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      );
    }

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: content,
        ),
      ),
    );
  }
}
