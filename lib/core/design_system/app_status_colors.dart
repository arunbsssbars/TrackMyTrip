import 'package:flutter/material.dart';

/// Semantic status colors for enterprise status representation.
/// Conforms to Material 3 tonal palettes with high-contrast on-color pairings.
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.danger,
    required this.onDanger,
    required this.dangerContainer,
    required this.onDangerContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.neutral,
    required this.onNeutral,
    required this.neutralContainer,
    required this.onNeutralContainer,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  final Color danger;
  final Color onDanger;
  final Color dangerContainer;
  final Color onDangerContainer;

  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  final Color neutral;
  final Color onNeutral;
  final Color neutralContainer;
  final Color onNeutralContainer;

  /// High-contrast accessible Light theme status colors (WCAG 2.2 AA >= 4.5:1)
  static const light = AppStatusColors(
    success: Color(0xFF047857), // Deep emerald
    onSuccess: Colors.white,
    successContainer: Color(0xFFD1FAE5), // Mint tint
    onSuccessContainer: Color(0xFF064E3B), // Dark green text

    warning: Color(0xFFB45309), // Amber bronze
    onWarning: Colors.white,
    warningContainer: Color(0xFFFEF3C7), // Warm yellow tint
    onWarningContainer: Color(0xFF78350F), // Dark brown/amber text

    danger: Color(0xFFB91C1C), // Deep crimson red
    onDanger: Colors.white,
    dangerContainer: Color(0xFFFEE2E2), // Light red tint
    onDangerContainer: Color(0xFF7F1D1D), // Deep wine text

    info: Color(0xFF0369A1), // Deep ocean blue
    onInfo: Colors.white,
    infoContainer: Color(0xFFE0F2FE), // Sky tint
    onInfoContainer: Color(0xFF0C4A6E), // Deep sky text

    neutral: Color(0xFF475569), // Slate 600
    onNeutral: Colors.white,
    neutralContainer: Color(0xFFF1F5F9), // Slate 100
    onNeutralContainer: Color(0xFF0F172A), // Slate 900
  );

  /// High-contrast accessible Dark theme status colors (WCAG 2.2 AA >= 4.5:1)
  static const dark = AppStatusColors(
    success: Color(0xFF34D399), // Light emerald
    onSuccess: Color(0xFF064E3B),
    successContainer: Color(0xFF065F46), // Muted dark green
    onSuccessContainer: Color(0xFFA7F3D0), // Pale emerald text

    warning: Color(0xFFFBBF24), // Vibrant amber
    onWarning: Color(0xFF78350F),
    warningContainer: Color(0xFF78350F), // Deep amber container
    onWarningContainer: Color(0xFFFDE68A), // Light amber text

    danger: Color(0xFFF87171), // Vibrant coral red
    onDanger: Color(0xFF7F1D1D),
    dangerContainer: Color(0xFF7F1D1D), // Deep crimson container
    onDangerContainer: Color(0xFFFECACA), // Soft rose text

    info: Color(0xFF38BDF8), // Bright sky blue
    onInfo: Color(0xFF0C4A6E),
    infoContainer: Color(0xFF075985), // Deep navy blue
    onInfoContainer: Color(0xFFBAE6FD), // Pale ice blue

    neutral: Color(0xFF94A3B8), // Slate 400
    onNeutral: Color(0xFF0F172A),
    neutralContainer: Color(0xFF1E293B), // Slate 800
    onNeutralContainer: Color(0xFFF8FAFC), // Slate 50
  );

  @override
  AppStatusColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? danger,
    Color? onDanger,
    Color? dangerContainer,
    Color? onDangerContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? neutral,
    Color? onNeutral,
    Color? neutralContainer,
    Color? onNeutralContainer,
  }) {
    return AppStatusColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      neutral: neutral ?? this.neutral,
      onNeutral: onNeutral ?? this.onNeutral,
      neutralContainer: neutralContainer ?? this.neutralContainer,
      onNeutralContainer: onNeutralContainer ?? this.onNeutralContainer,
    );
  }

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      onDangerContainer: Color.lerp(onDangerContainer, other.onDangerContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      onNeutral: Color.lerp(onNeutral, other.onNeutral, t)!,
      neutralContainer: Color.lerp(neutralContainer, other.neutralContainer, t)!,
      onNeutralContainer: Color.lerp(onNeutralContainer, other.onNeutralContainer, t)!,
    );
  }
}
