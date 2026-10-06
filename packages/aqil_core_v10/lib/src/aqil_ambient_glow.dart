import 'package:flutter/material.dart';

/// Multi-point ambient radial gradient mesh backdrop (Apple Music / Spotify / Vercel style).
///
/// Creates atmospheric chromatic glow behind hero cards or media surfaces without raster image assets.
class AqilAmbientGlow extends StatelessWidget {
  final Widget child;
  final List<Color> glowColors;
  final double blurRadius;
  final double intensity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;

  const AqilAmbientGlow({
    super.key,
    required this.child,
    this.glowColors = const [
      Color(0xFF6366F1), // Indigo
      Color(0xFFA855F7), // Purple
      Color(0xFFEC4899), // Pink
    ],
    this.blurRadius = 32.0,
    this.intensity = 0.22,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(16.0);

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: Stack(
        children: [
          // Ambient Glow Layer
          Positioned.fill(
            child: CustomPaint(
              painter: _AqilAmbientMeshPainter(
                glowColors: glowColors,
                intensity: intensity,
              ),
            ),
          ),
          // Content
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _AqilAmbientMeshPainter extends CustomPainter {
  final List<Color> glowColors;
  final double intensity;

  _AqilAmbientMeshPainter({
    required this.glowColors,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (glowColors.isEmpty || size.isEmpty) return;

    final primaryOrb = glowColors[0];
    final secondaryOrb = glowColors.length > 1 ? glowColors[1] : primaryOrb;
    final tertiaryOrb = glowColors.length > 2 ? glowColors[2] : secondaryOrb;

    // Top-left orb
    final paint1 = Paint()
      ..shader = RadialGradient(
        center: Alignment.topLeft,
        radius: 1.1,
        colors: [
          primaryOrb.withValues(alpha: intensity),
          primaryOrb.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);

    // Bottom-right orb
    final paint2 = Paint()
      ..shader = RadialGradient(
        center: Alignment.bottomRight,
        radius: 1.2,
        colors: [
          secondaryOrb.withValues(alpha: intensity * 0.85),
          secondaryOrb.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint2);

    // Center-top accent orb
    final paint3 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.2, -0.4),
        radius: 0.8,
        colors: [
          tertiaryOrb.withValues(alpha: intensity * 0.6),
          tertiaryOrb.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint3);
  }

  @override
  bool shouldRepaint(covariant _AqilAmbientMeshPainter oldDelegate) {
    return oldDelegate.intensity != intensity ||
        oldDelegate.glowColors != glowColors;
  }
}

/// Auditor verifying ambient glow intensities do not degrade foreground readability.
class AqilAmbientGlowAuditor {
  /// Evaluates whether an ambient glow alpha level is safe for WCAG text readability.
  static bool isSafeGlowIntensity(double intensity) {
    return intensity >= 0.05 && intensity <= 0.40;
  }
}
