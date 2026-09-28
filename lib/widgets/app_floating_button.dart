import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Visual composite icon for OCR bill adding: Document Scanner with lower-right plus badge
class OcrAddIcon extends StatelessWidget {
  final double size;
  final Color color;
  final Color badgeColor;
  final Color plusColor;

  const OcrAddIcon({
    super.key,
    this.size = 17,
    this.color = Colors.white,
    this.badgeColor = Colors.white,
    this.plusColor = const Color(0xFF0D9488),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 2,
      height: size + 2,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(Icons.document_scanner_rounded, size: size, color: color),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(0.6),
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: plusColor, width: 1.0),
              ),
              child: Icon(Icons.add_rounded, size: size * 0.42, color: plusColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standardized, premium Floating Action Button used across all screens
/// for uniform elevation, typography, gradients, and touch targets.
class AppFloatingActionButton extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String label;
  final VoidCallback onTap;
  final List<Color>? gradientColors;
  final Color? iconColor;
  final Color? textColor;
  final double elevation;
  final String? heroTag;

  const AppFloatingActionButton({
    super.key,
    this.icon,
    this.customIcon,
    required this.label,
    required this.onTap,
    this.gradientColors,
    this.iconColor = Colors.white,
    this.textColor = Colors.white,
    this.elevation = 4.0,
    this.heroTag,
  }) : assert(icon != null || customIcon != null, 'Either icon or customIcon must be provided');

  factory AppFloatingActionButton.extended({
    Key? key,
    IconData? icon,
    Widget? customIcon,
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
      customIcon: customIcon,
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

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44, maxHeight: 44),
      child: Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  customIcon ?? Icon(icon!, color: iconColor, size: 18),
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
      ),
    );
  }
}
