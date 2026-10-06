import 'package:flutter/material.dart';

/// Pure obsidian dark mode tokens inspired by Linear (#08090A).
class AqilObsidianTheme {
  /// Deep pitch background surface.
  static const Color background = Color(0xFF08090A);

  /// Elevated card surface.
  static const Color surfaceElevated = Color(0xFF121417);

  /// Subtle 1px boundary line.
  static const Color borderSubtle = Color(0x14FFFFFF); // rgba(255,255,255,0.08)

  /// Accent highlight color.
  static const Color accent = Color(0xFF5E6AD2);

  /// Creates a theme data strictly adhering to obsidian dark standards.
  static ThemeData themeData() {
    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        surface: surfaceElevated,
        primary: accent,
        outline: borderSubtle,
      ),
    );
  }
}

/// Audits a dark theme's background luminance to ensure it uses true obsidian/slate
/// darks instead of muddy washed-out greys.
class AqilDarkThemeAuditor {
  /// Evaluates background luminance.
  static String? auditBackgroundLuminance(Color bgColor) {
    final luminance = bgColor.computeLuminance();
    // Muddy grey check: luminance > 0.05 in dark mode
    if (luminance > 0.05) {
      return 'Dark background luminance is ${luminance.toStringAsFixed(3)}, which may appear muddy/washed out. Suggest deeper obsidian tone (e.g. #08090A or #0F1115).';
    }
    return null;
  }
}
