import 'package:flutter/material.dart';
import '../../models/outdoor_theme_profile.dart';

class OutdoorThemeService {
  static final OutdoorThemeService _instance = OutdoorThemeService._internal();
  factory OutdoorThemeService() => _instance;
  OutdoorThemeService._internal();

  OutdoorThemeProfile _profile = const OutdoorThemeProfile();
  OutdoorThemeProfile get currentProfile => _profile;

  void updateProfile(OutdoorThemeProfile newProfile) {
    _profile = newProfile;
  }

  void setMode(OutdoorDisplayMode mode) {
    _profile = _profile.copyWith(mode: mode);
  }

  /// Calculates WCAG relative luminance contrast ratio between two colors
  static double calculateContrastRatio(Color foreground, Color background) {
    final lum1 = foreground.computeLuminance();
    final lum2 = background.computeLuminance();
    final brightest = lum1 > lum2 ? lum1 : lum2;
    final darkest = lum1 > lum2 ? lum2 : lum1;
    return (brightest + 0.05) / (darkest + 0.05);
  }

  /// Returns tailored theme colors based on active outdoor profile
  ColorScheme getAdaptedColorScheme(ColorScheme baseScheme) {
    switch (_profile.mode) {
      case OutdoorDisplayMode.sunlightGlareHighContrast:
        return baseScheme.copyWith(
          surface: Colors.white,
          onSurface: Colors.black,
          primary: const Color(0xFF0038A8), // Deep saturated contrast navy
          onPrimary: Colors.white,
          surfaceContainerHighest: const Color(0xFFECEFF1),
          outline: Colors.black,
        );

      case OutdoorDisplayMode.nightVisionOledRed:
        return baseScheme.copyWith(
          surface: Colors.black,
          onSurface: const Color(0xFFFF8B80),
          primary: const Color(0xFFFF3B30),
          onPrimary: Colors.black,
          surfaceContainerHighest: const Color(0xFF2C0B0B),
          outline: const Color(0xFFFF3B30),
        );

      case OutdoorDisplayMode.nightVisionOledAmber:
        return baseScheme.copyWith(
          surface: Colors.black,
          onSurface: const Color(0xFFFFC875),
          primary: const Color(0xFFFF9F0A),
          onPrimary: Colors.black,
          surfaceContainerHighest: const Color(0xFF2C1E0A),
          outline: const Color(0xFFFF9F0A),
        );

      case OutdoorDisplayMode.standard:
        if (_profile.amoledPureBlack) {
          return baseScheme.copyWith(
            surface: Colors.black,
          );
        }
        return baseScheme;
    }
  }

  /// Label helper for UI display
  String getModeTitle(OutdoorDisplayMode mode) {
    switch (mode) {
      case OutdoorDisplayMode.standard:
        return 'Standard Dynamic';
      case OutdoorDisplayMode.sunlightGlareHighContrast:
        return 'Sunlight Glare Shield';
      case OutdoorDisplayMode.nightVisionOledRed:
        return 'Night Vision Red (OLED)';
      case OutdoorDisplayMode.nightVisionOledAmber:
        return 'Aviation Amber (OLED)';
    }
  }

  String getModeDescription(OutdoorDisplayMode mode) {
    switch (mode) {
      case OutdoorDisplayMode.standard:
        return 'Standard adaptive system colors';
      case OutdoorDisplayMode.sunlightGlareHighContrast:
        return 'Maximum contrast ratio for direct midday sunlight';
      case OutdoorDisplayMode.nightVisionOledRed:
        return 'Monochrome red phosphor preserving night-adapted vision';
      case OutdoorDisplayMode.nightVisionOledAmber:
        return 'Monochrome aviation amber minimizing retinal fatigue';
    }
  }
}
