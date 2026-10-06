/// Canonical z-index elevation tiers (Material 3 & iOS spatial hierarchy standard).
enum AqilElevationTier {
  canvas(0.0, 0.0),
  card(1.0, 3.0),
  stickyHeader(4.0, 6.0),
  modalSheet(8.0, 16.0),
  toastTooltip(20.0, 28.0);

  final double minElevation;
  final double maxElevation;

  const AqilElevationTier(this.minElevation, this.maxElevation);
}

/// Z-index elevation hierarchy auditor.
///
/// Prevents inverted visual hierarchy where background cards cast deeper shadows
/// than foreground modals or sticky headers.
class AqilZIndexLayerAuditor {
  /// Verifies whether an elevation value conforms to its intended semantic tier.
  static bool conformsToTier({
    required double elevation,
    required AqilElevationTier tier,
  }) {
    return elevation >= tier.minElevation && elevation <= tier.maxElevation;
  }

  /// Audits a pair of elements to ensure the foreground element has strictly higher elevation.
  static String? auditLayerPair({
    required double backgroundElevation,
    required double foregroundElevation,
  }) {
    if (backgroundElevation >= foregroundElevation) {
      return 'Elevation Inversion: Background layer (elevation $backgroundElevation) is equal to or higher than foreground layer (elevation $foregroundElevation).';
    }
    return null;
  }
}
