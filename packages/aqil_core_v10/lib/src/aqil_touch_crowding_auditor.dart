import 'dart:ui';
import 'aqil_visual_hierarchy_auditor.dart';

/// Audits spacing between adjacent interactive touch targets (buttons, icons, chips)
/// to detect accidental tap hazards (rage clicks).
class AqilTouchCrowdingAuditor {
  /// Minimum recommended buffer distance between adjacent interactive bounding boxes.
  static const double minTouchTargetBuffer = 12.0;

  /// Audits the physical gap between two adjacent interactive bounding boxes.
  static AqilVisualGap? auditDistance({
    required Rect firstTarget,
    required Rect secondTarget,
    String firstLabel = 'Target A',
    String secondLabel = 'Target B',
  }) {
    // Calculate shortest distance between two rectangles
    final dx = (firstTarget.left > secondTarget.right)
        ? firstTarget.left - secondTarget.right
        : (secondTarget.left > firstTarget.right)
            ? secondTarget.left - firstTarget.right
            : 0.0;

    final dy = (firstTarget.top > secondTarget.bottom)
        ? firstTarget.top - secondTarget.bottom
        : (secondTarget.top > firstTarget.bottom)
            ? secondTarget.top - firstTarget.bottom
            : 0.0;

    final distance = (dx > 0 && dy > 0)
        ? (dx * dx + dy * dy)
        : (dx > 0 ? dx : dy);

    if (distance < minTouchTargetBuffer) {
      final isOverlapping = distance == 0.0;
      return AqilVisualGap(
        category: 'TouchCrowding',
        severity: isOverlapping ? AqilGapSeverity.critical : AqilGapSeverity.warning,
        description:
            'Interactive elements "$firstLabel" and "$secondLabel" are spaced only ${distance.toStringAsFixed(1)}dp apart (min safe buffer is ${minTouchTargetBuffer}dp).',
        recommendation:
            'Increase margin or add SizedBox(width: 12) between touch targets to prevent accidental mis-taps on mobile touchscreens.',
        codeSnippetFix: 'const SizedBox(width: 12.0)',
      );
    }

    return null;
  }
}
