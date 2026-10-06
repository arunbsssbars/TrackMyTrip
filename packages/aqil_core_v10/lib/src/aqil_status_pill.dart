import 'package:flutter/material.dart';

/// Semantic status state for indicators.
enum AqilStatusVariant {
  success(
    label: 'Success',
    baseColor: Color(0xFF10B981),
  ),
  warning(
    label: 'Warning',
    baseColor: Color(0xFFF59E0B),
  ),
  error(
    label: 'Error',
    baseColor: Color(0xFFEF4444),
  ),
  info(
    label: 'Info',
    baseColor: Color(0xFF3B82F6),
  ),
  neutral(
    label: 'Neutral',
    baseColor: Color(0xFF6B7280),
  );

  final String label;
  final Color baseColor;

  const AqilStatusVariant({
    required this.label,
    required this.baseColor,
  });
}

/// Refined status badge pill with optional pulsing live beacon dot.
///
/// Follows Stripe, GitHub, and Linear status badge standards with soft
/// pastel tint surfaces and calibrated 1px borders.
class AqilStatusPill extends StatefulWidget {
  final AqilStatusVariant variant;
  final String? label;
  final bool showLivePulse;
  final EdgeInsetsGeometry padding;

  const AqilStatusPill({
    super.key,
    required this.variant,
    this.label,
    this.showLivePulse = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
  });

  @override
  State<AqilStatusPill> createState() => _AqilStatusPillState();
}

class _AqilStatusPillState extends State<AqilStatusPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    if (widget.showLivePulse) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AqilStatusPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showLivePulse && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.showLivePulse && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = widget.variant.baseColor;

    final bgColor = color.withValues(alpha: isDark ? 0.18 : 0.10);
    final borderColor = color.withValues(alpha: isDark ? 0.35 : 0.25);
    final textColor = isDark
        ? Color.lerp(color, Colors.white, 0.25)!
        : Color.lerp(color, Colors.black, 0.35)!;

    final displayText = widget.label ?? widget.variant.label;

    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showLivePulse)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 7.0,
                  height: 7.0,
                  margin: const EdgeInsets.only(right: 6.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4 * _pulseAnimation.value),
                        blurRadius: 4.0 * _pulseAnimation.value,
                        spreadRadius: 1.5 * _pulseAnimation.value,
                      ),
                    ],
                  ),
                );
              },
            )
          else
            Container(
              width: 6.0,
              height: 6.0,
              margin: const EdgeInsets.only(right: 6.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
          Text(
            displayText,
            style: TextStyle(
              color: textColor,
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Semantic color palette auditor.
///
/// Prevents harsh raw primary neons (#FF0000) that produce chromatic aberration.
class AqilSemanticPaletteAuditor {
  /// Checks if a color is overly saturated (chromatic strain).
  static bool isHarshNeon(Color color) {
    final hsv = HSVColor.fromColor(color);
    return hsv.saturation >= 0.98 && hsv.value >= 0.98;
  }

  /// Suggests calibrated pastel replacement.
  static Color softenHarmonious(Color color) {
    final hsv = HSVColor.fromColor(color);
    return hsv.withSaturation((hsv.saturation * 0.75).clamp(0.0, 1.0)).toColor();
  }
}
