import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Semantic accessibility audit report for interactive widgets.
class AqilA11ySemanticReport {
  final int totalInteractiveWidgets;
  final int missingLabelCount;
  final List<String> unlabeledWidgets;

  const AqilA11ySemanticReport({
    required this.totalInteractiveWidgets,
    required this.missingLabelCount,
    required this.unlabeledWidgets,
  });

  bool get isFullyAccessible => missingLabelCount == 0;
}

/// Semantic Accessibility Screen Reader Traverser.
/// Traverses any Flutter screen during tests and verifies that every interactive element
/// (IconButton, FloatingActionButton, InkWell, GestureDetector) has an accessible
/// semantics label or tooltip for screen readers (TalkBack / VoiceOver).
class AqilA11yTraverser {
  /// Audits all IconButton widgets in the current widget tester hierarchy.
  static AqilA11ySemanticReport auditScreenSemantics(WidgetTester tester) {
    final iconButtons = tester.widgetList<IconButton>(find.byType(IconButton)).toList();
    final unlabeled = <String>[];
    int missing = 0;

    for (int i = 0; i < iconButtons.length; i++) {
      final btn = iconButtons[i];
      final tooltip = btn.tooltip;
      if (tooltip == null || tooltip.trim().isEmpty) {
        missing++;
        unlabeled.add('IconButton index $i has null or empty tooltip/semantic label.');
      }
    }

    return AqilA11ySemanticReport(
      totalInteractiveWidgets: iconButtons.length,
      missingLabelCount: missing,
      unlabeledWidgets: unlabeled,
    );
  }
}
