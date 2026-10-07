enum OutdoorDisplayMode {
  standard,
  sunlightGlareHighContrast,
  nightVisionOledRed,
  nightVisionOledAmber,
}

class OutdoorThemeProfile {
  final OutdoorDisplayMode mode;
  final bool amoledPureBlack;
  final double contrastBoost;
  final bool boldTextForced;

  const OutdoorThemeProfile({
    this.mode = OutdoorDisplayMode.standard,
    this.amoledPureBlack = false,
    this.contrastBoost = 1.0,
    this.boldTextForced = false,
  });

  bool get isSunlightHighContrast => mode == OutdoorDisplayMode.sunlightGlareHighContrast;
  bool get isNightVision =>
      mode == OutdoorDisplayMode.nightVisionOledRed || mode == OutdoorDisplayMode.nightVisionOledAmber;

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'amoledPureBlack': amoledPureBlack,
        'contrastBoost': contrastBoost,
        'boldTextForced': boldTextForced,
      };

  factory OutdoorThemeProfile.fromJson(Map<String, dynamic> json) {
    OutdoorDisplayMode parsedMode = OutdoorDisplayMode.standard;
    final modeName = json['mode'] as String?;
    if (modeName != null) {
      for (final m in OutdoorDisplayMode.values) {
        if (m.name == modeName) {
          parsedMode = m;
          break;
        }
      }
    }

    return OutdoorThemeProfile(
      mode: parsedMode,
      amoledPureBlack: json['amoledPureBlack'] as bool? ?? false,
      contrastBoost: (json['contrastBoost'] as num?)?.toDouble() ?? 1.0,
      boldTextForced: json['boldTextForced'] as bool? ?? false,
    );
  }

  OutdoorThemeProfile copyWith({
    OutdoorDisplayMode? mode,
    bool? amoledPureBlack,
    double? contrastBoost,
    bool? boldTextForced,
  }) {
    return OutdoorThemeProfile(
      mode: mode ?? this.mode,
      amoledPureBlack: amoledPureBlack ?? this.amoledPureBlack,
      contrastBoost: contrastBoost ?? this.contrastBoost,
      boldTextForced: boldTextForced ?? this.boldTextForced,
    );
  }
}
