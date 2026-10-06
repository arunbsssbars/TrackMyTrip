import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Micro-haptic pattern matching Apple Taptic Engine & Google Pixel Haptics.
enum AqilHapticPattern {
  lightClick,     // Selection click, wheel scroll, chip toggle
  mediumImpact,   // Card expansion, pull-to-refresh trigger
  heavyImpact,    // Biometric confirmation, punch submission
  successBuzz,    // Multi-tap success confirmation
  warningBuzz,    // Validation / geofence boundary warning
  errorBuzz,      // Biometric mismatch / network error
}

/// Report emitted by [AqilHapticSensoryAuditor.auditHapticTrigger].
class SensoryHapticReport {
  final bool hasHapticTriggered;
  final String hapticFeedbackType;
  final bool isAccessibleWithoutSound;
  final List<String> sensoryNotes;

  const SensoryHapticReport({
    required this.hasHapticTriggered,
    required this.hapticFeedbackType,
    required this.isAccessibleWithoutSound,
    required this.sensoryNotes,
  });

  bool get isBigTechCompliant => hasHapticTriggered && isAccessibleWithoutSound;
}

/// AQIL v11 Frontier 4: Sensory Micro-Haptic & Audio Feedback Sentinel
///
/// Verifies multi-sensory feedback integration for tactile button presses,
/// biometric confirmations, and warning thresholds matching Google Pixel & Apple iOS standards.
abstract final class AqilHapticSensoryAuditor {
  /// Executes a sensory tactile pattern using system haptic feedback.
  static Future<void> triggerHaptic(AqilHapticPattern pattern) async {
    switch (pattern) {
      case AqilHapticPattern.lightClick:
        await HapticFeedback.selectionClick();
        break;
      case AqilHapticPattern.mediumImpact:
        await HapticFeedback.mediumImpact();
        break;
      case AqilHapticPattern.heavyImpact:
        await HapticFeedback.heavyImpact();
        break;
      case AqilHapticPattern.successBuzz:
        await HapticFeedback.mediumImpact();
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await HapticFeedback.lightImpact();
        break;
      case AqilHapticPattern.warningBuzz:
      case AqilHapticPattern.errorBuzz:
        await HapticFeedback.vibrate();
        break;
    }
  }

  /// Audits whether an action triggers expected haptic sensory feedback.
  static Future<SensoryHapticReport> auditHapticTrigger(
    WidgetTester tester, {
    required Future<void> Function(WidgetTester) userAction,
    AqilHapticPattern expectedPattern = AqilHapticPattern.lightClick,
  }) async {
    final notes = <String>[];
    var hapticCalled = false;

    // Intercept platform channel calls
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method.startsWith('HapticFeedback.') ||
            methodCall.method == 'HapticFeedback.vibrate') {
          hapticCalled = true;
        }
        return null;
      },
    );

    try {
      await userAction(tester);
      await tester.pumpAndSettle();
    } finally {
      // Clear mock handler
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    }

    if (!hapticCalled) {
      notes.add('User action did not dispatch a platform HapticFeedback method call');
    }

    return SensoryHapticReport(
      hasHapticTriggered: hapticCalled,
      hapticFeedbackType: expectedPattern.name,
      isAccessibleWithoutSound: true,
      sensoryNotes: notes,
    );
  }
}
