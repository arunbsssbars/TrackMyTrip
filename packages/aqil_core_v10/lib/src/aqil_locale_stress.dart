/// Stress locale profile used by [AqilLocaleStressEngine].
enum LocaleStressProfile {
  germanExpansion('Germanic Length Expansion (+35%)'),
  arabicBiDi('Arabic / Hebrew Bidirectional RTL Reversal'),
  accentDiacritics('Diacritic Accents & Descenders Stress'),
  cjkDense('CJK Dense Character Alignment');

  final String description;
  const LocaleStressProfile(this.description);
}

/// Multi-Locale Pseudo-Localization & BiDi Stress Engine (AQIL Frontier 3).
///
/// Transforms standard UI strings into linguistic stress cases to verify that
/// text containers never overflow, clip, or collide across international languages.
class AqilLocaleStressEngine {
  /// Transforms input string based on the chosen stress profile.
  static String transform(String input, {LocaleStressProfile profile = LocaleStressProfile.germanExpansion}) {
    if (input.isEmpty) return input;

    switch (profile) {
      case LocaleStressProfile.germanExpansion:
        // Expand length by ~35% with Germanic prefixes and suffixes
        return '[=== $input (verlängert) ===]';

      case LocaleStressProfile.arabicBiDi:
        // Prepend RTL marker and Arabic sample
        return '\u202E$input (عربي)\u202C';

      case LocaleStressProfile.accentDiacritics:
        // Replace vowels with accented versions to stress vertical line height
        return input
            .replaceAll('a', 'ä')
            .replaceAll('e', 'ë')
            .replaceAll('i', 'ï')
            .replaceAll('o', 'ö')
            .replaceAll('u', 'ü');

      case LocaleStressProfile.cjkDense:
        return '「$input」测试文本';
    }
  }

  /// Evaluates whether an expansion factor triggers layout strain.
  static double estimateExpansionRatio(String original, String transformed) {
    if (original.isEmpty) return 1.0;
    return transformed.length / original.length;
  }
}
