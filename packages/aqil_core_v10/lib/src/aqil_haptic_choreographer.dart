import 'package:flutter/services.dart';

/// Pre-configured tactile haptic profiles tailored to specific UX actions.
enum AqilHapticRole {
  /// Subtle tick on discrete selection (tab switch, segmented button, filter chip).
  selection,

  /// Crisp tap on standard primary buttons and checkmarks.
  lightImpact,

  /// Confident tactile punch on critical confirm actions (checkout, transfer, submit).
  mediumImpact,

  /// Heavy warning or destructive alert buzz (delete, archive, disconnect).
  heavyImpact,

  /// Double rhythmic vibration for errors or validation rejections.
  errorAlert,
}

/// Tactile Choreographer providing uniform, benchmark tactile feedback
/// across all iOS and Android devices, inspired by Cash App and Things 3.
class AqilHapticChoreographer {
  static bool enableHaptics = true;

  /// Triggers standard haptic feedback for a given UX role.
  static Future<void> trigger(AqilHapticRole role) async {
    if (!enableHaptics) return;

    try {
      switch (role) {
        case AqilHapticRole.selection:
          await HapticFeedback.selectionClick();
          break;
        case AqilHapticRole.lightImpact:
          await HapticFeedback.lightImpact();
          break;
        case AqilHapticRole.mediumImpact:
          await HapticFeedback.mediumImpact();
          break;
        case AqilHapticRole.heavyImpact:
          await HapticFeedback.heavyImpact();
          break;
        case AqilHapticRole.errorAlert:
          await HapticFeedback.vibrate();
          break;
      }
    } catch (_) {
      // Graceful fallback on platforms without haptic actuators
    }
  }

  /// Convenience shortcut for lightweight tap micro-interactions.
  static Future<void> tap() => trigger(AqilHapticRole.lightImpact);

  /// Convenience shortcut for discrete item switches or slider steps.
  static Future<void> tick() => trigger(AqilHapticRole.selection);

  /// Convenience shortcut for success or submit confirmation.
  static Future<void> confirm() => trigger(AqilHapticRole.mediumImpact);

  /// Convenience shortcut for validation rejections.
  static Future<void> error() => trigger(AqilHapticRole.errorAlert);
}
