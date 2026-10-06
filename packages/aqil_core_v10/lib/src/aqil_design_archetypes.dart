import 'package:flutter/material.dart';

/// Pre-engineered aesthetic design system themes adhering to world-class standards:
/// - Obsidian Elite (Linear & Superhuman)
/// - Pure Minimalist (Things 3 & Apple Store)
/// - Vibrant FinTech (Cash App & Revolut)
class AqilDesignArchetypes {
  /// Linear-inspired obsidian dark theme.
  static ThemeData obsidian() {
    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xFF08090A),
      cardColor: const Color(0xFF13151A),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF5E6AD2),
        surface: Color(0xFF13151A),
        outline: Color(0x14FFFFFF),
      ),
    );
  }

  /// Things 3 inspired clean minimalist light theme.
  static ThemeData minimalist() {
    return ThemeData.light(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      cardColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF0A84FF),
        surface: Colors.white,
        outline: Color(0x0F000000),
      ),
    );
  }

  /// Cash App inspired vibrant fintech dark theme.
  static ThemeData fintechVibrant() {
    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xFF000000),
      cardColor: const Color(0xFF111111),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00D632),
        surface: Color(0xFF111111),
        outline: Color(0x1AFFFFFF),
      ),
    );
  }
}
