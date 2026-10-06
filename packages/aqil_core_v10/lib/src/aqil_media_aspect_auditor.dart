
/// Audits image aspect ratio consistency across grid views, card media, and avatars.
/// Prevents image squishing, irregular heights, or broken aspect ratios.
class AqilMediaAspectAuditor {
  /// Standard golden and photography aspect ratios.
  static const double square = 1.0;
  static const double golden = 1.618;
  static const double landscapeStandard = 16.0 / 9.0;
  static const double photoStandard = 4.0 / 3.0;

  /// Audits an image or media container dimensions.
  static String? auditAspect({
    required double width,
    required double height,
    double targetRatio = landscapeStandard,
    String context = 'CardImage',
  }) {
    if (height <= 0 || width <= 0) return null;

    final actualRatio = width / height;
    final diff = (actualRatio - targetRatio).abs();

    if (diff > 0.25) {
      return '$context aspect ratio (${actualRatio.toStringAsFixed(2)}) deviates significantly from target standard (${targetRatio.toStringAsFixed(2)}). Consider wrapping in AspectRatio(aspectRatio: $targetRatio) with BoxFit.cover.';
    }

    return null;
  }
}
