/// Audits corner radius consistency across all cards, containers, buttons, and sheets.
/// Recommends harmonious concentric nested corner radii where inner radius = outer radius - padding.
class AqilCornerRadiusAuditor {
  /// Standard corner radii scale tokens.
  static final Map<double, String> radiusTokens = {
    0.0: 'Radius.none',
    4.0: 'Radius.xs',
    8.0: 'Radius.sm',
    12.0: 'Radius.md',
    16.0: 'Radius.base',
    20.0: 'Radius.lg',
    24.0: 'Radius.xl',
    32.0: 'Radius.pill',
  };

  /// Calculates mathematically harmonious concentric inner corner radius:
  /// innerRadius = max(0, outerRadius - padding)
  static double calculateConcentricInnerRadius({
    required double outerRadius,
    required double padding,
  }) {
    return (outerRadius - padding).clamp(0.0, double.infinity);
  }

  /// Audits whether an inner container violates concentric radius curvature harmony.
  static String? auditNestedCornerHarmony({
    required double outerRadius,
    required double padding,
    required double actualInnerRadius,
    String context = 'Card',
  }) {
    final theoretical = calculateConcentricInnerRadius(outerRadius: outerRadius, padding: padding);
    final diff = (actualInnerRadius - theoretical).abs();

    if (diff > 4.0 && theoretical > 0) {
      return '$context has non-concentric inner radius (${actualInnerRadius.toStringAsFixed(1)}dp). For harmonious visual curvature, inner radius should equal outer radius ($outerRadius) - padding ($padding) = ${theoretical.toStringAsFixed(1)}dp.';
    }
    return null;
  }
}
