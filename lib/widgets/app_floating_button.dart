import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Standardized, premium Floating Action Button used across all screens
/// for uniform elevation, typography, gradients, and touch targets.
class AppFloatingActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final List<Color>? gradientColors;
  final Color? iconColor;
  final Color? textColor;
  final double elevation;
  final String? heroTag;

  const AppFloatingActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.gradientColors,
    this.iconColor = Colors.white,
    this.textColor = Colors.white,
    this.elevation = 4.0,
    this.heroTag,
  });

  factory AppFloatingActionButton.extended({
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    List<Color>? gradientColors,
    Color? iconColor,
    Color? textColor,
    double elevation = 4.0,
    String? heroTag,
  }) {
    return AppFloatingActionButton(
      key: key,
      icon: icon,
      label: label,
      onTap: onPressed,
      gradientColors: gradientColors,
      iconColor: iconColor ?? Colors.white,
      textColor: textColor ?? Colors.white,
      elevation: elevation,
      heroTag: heroTag,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColors = gradientColors ??
        const [
          Color(0xFF0D9488),
          Color(0xFF0F766E),
        ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: effectiveColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: effectiveColors.first.withAlpha(110),
            blurRadius: elevation * 3.0,
            offset: Offset(0, elevation * 0.8),
          ),
        ],
        border: Border.all(color: Colors.white.withAlpha(50), width: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(28),
          splashColor: Colors.white.withAlpha(40),
          highlightColor: Colors.white.withAlpha(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: iconColor, size: 19),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
