
/// One-handed thumb reach zone classification.
enum ThumbReachZone {
  /// Bottom 60% of viewport: Effortless one-handed access.
  comfortZone,

  /// Upper 40% of viewport: Requires hand stretch or two-handed shift.
  stretchZone,
}

/// Evaluates widget screen positioning and flags critical interactive elements
/// placed in the stretch zone on modern tall mobile displays (height >= 700dp).
class AqilThumbReachEnforcer {
  /// Evaluates an interactive widget's position within a viewport.
  static ThumbReachZone evaluatePosition({
    required double widgetY,
    required double viewportHeight,
  }) {
    final comfortBoundary = viewportHeight * 0.40;
    return widgetY >= comfortBoundary
        ? ThumbReachZone.comfortZone
        : ThumbReachZone.stretchZone;
  }

  /// Evaluates whether a primary CTA (submit, pay, save) should be moved to a sticky bottom bar.
  static String? auditCtaPlacement({
    required String actionName,
    required double widgetY,
    required double viewportHeight,
    bool isPrimaryAction = true,
  }) {
    if (!isPrimaryAction) return null;

    final zone = evaluatePosition(widgetY: widgetY, viewportHeight: viewportHeight);
    if (zone == ThumbReachZone.stretchZone && viewportHeight >= 700) {
      return 'Action "$actionName" is located at y=$widgetY in the stretch zone (top 40% of ${viewportHeight}dp viewport). Suggest anchoring as a sticky bottom CTA for one-handed thumb reach.';
    }
    return null;
  }
}
