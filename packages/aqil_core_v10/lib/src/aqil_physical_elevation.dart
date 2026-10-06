import 'package:flutter/material.dart';

/// Elevation level of design surfaces.
enum AqilElevationLevel {
  level0, // Flat surface / Canvas background
  level1, // Subtle card / Tile
  level2, // Dropdown / Popover / Tooltip
  level3, // Floating Action Button / Sticky bar
  level4, // Modal dialog / Bottom sheet
}

/// A multi-stop ambient + key light shadow token for physically realistic elevations.
class AqilPhysicalShadow {
  final List<BoxShadow> shadows;

  const AqilPhysicalShadow(this.shadows);

  /// Key light (crisp directional shadow) + Ambient light (soft surrounding penumbra).
  static List<BoxShadow> realistic({
    required double elevation,
    Color shadowColor = Colors.black,
    double ambientOpacity = 0.04,
    double keyOpacity = 0.12,
  }) {
    if (elevation <= 0) return const [];

    return [
      // 1. Ambient light penumbra
      BoxShadow(
        color: shadowColor.withValues(alpha: ambientOpacity * (elevation / 2.0).clamp(0.5, 2.0)),
        blurRadius: elevation * 2.5,
        spreadRadius: 0.0,
        offset: Offset(0, elevation * 0.5),
      ),
      // 2. Direct key light umbra
      BoxShadow(
        color: shadowColor.withValues(alpha: keyOpacity * (elevation / 3.0).clamp(0.5, 2.0)),
        blurRadius: elevation * 1.2,
        spreadRadius: -elevation * 0.2,
        offset: Offset(0, elevation * 0.8),
      ),
    ];
  }
}

/// Audits box shadows to detect muddy or pitch-black single-offset shadows
/// (e.g. BoxShadow(color: Colors.black, blurRadius: 4)) and recommends multi-stop physical shadows.
class AqilElevationAuditor {
  static String? auditBoxShadow(BoxShadow shadow) {
    if (shadow.color.a > 0.40 && shadow.blurRadius < 10.0) {
      return 'Single-stop shadow has harsh opacity (${shadow.color.a.toStringAsFixed(2)}) and low blur (${shadow.blurRadius}dp). Suggest using dual ambient+key light physical shadows (AqilPhysicalShadow.realistic).';
    }
    return null;
  }
}
