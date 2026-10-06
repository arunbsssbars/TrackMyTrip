import 'package:flutter/material.dart';

/// Container with a continuous specular gradient border stroke (Vercel / Raycast / Linear standard).
class AqilBorderGradientGlow extends StatelessWidget {
  final Widget child;
  final Gradient gradient;
  final double borderWidth;
  final double borderRadius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const AqilBorderGradientGlow({
    super.key,
    required this.child,
    this.gradient = const LinearGradient(
      colors: [
        Color(0xFF6366F1), // Indigo
        Color(0xFFA855F7), // Purple
        Color(0xFF06B6D4), // Cyan
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    this.borderWidth = 1.2,
    this.borderRadius = 16.0,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = backgroundColor ??
        (isDark ? const Color(0xFF131316) : Colors.white);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 16.0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        margin: EdgeInsets.all(borderWidth),
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(
            (borderRadius - borderWidth).clamp(0.0, double.infinity),
          ),
        ),
        child: child,
      ),
    );
  }
}
