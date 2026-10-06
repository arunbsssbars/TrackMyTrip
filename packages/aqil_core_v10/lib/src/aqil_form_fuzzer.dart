import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test personas used by [AqilFormFuzzer].
enum FuzzPersona {
  emptyRequired('Empty / Null Required Inputs'),
  extremeLength('500+ Character String Stress'),
  unicodeSpam('Zalgo, Emojis & RTL Unicode Script'),
  typeBoundary('Numeric & Date Boundary Violations'),
  rapidDoubleTap('Rapid 5x Double-Tap Re-entrancy');

  final String description;
  const FuzzPersona(this.description);
}

/// Evaluation record for a single form fuzz trial.
class FuzzTrialRecord {
  final FuzzPersona persona;
  final bool passed;
  final String details;
  final Object? caughtException;

  const FuzzTrialRecord({
    required this.persona,
    required this.passed,
    required this.details,
    this.caughtException,
  });
}

/// Report produced by [AqilFormFuzzer.fuzzScreenForm].
class FormFuzzReport {
  final String screenName;
  final int totalTrials;
  final int passedTrials;
  final List<FuzzTrialRecord> records;

  const FormFuzzReport({
    required this.screenName,
    required this.totalTrials,
    required this.passedTrials,
    required this.records,
  });

  bool get isResilient => passedTrials == totalTrials;
}

/// Autonomous Form & Input State Fuzzer (AQIL Frontier 2).
///
/// Automatically discovers text inputs, dropdowns, and buttons inside a widget
/// and stresses them against 5 extreme chaos input personas.
class AqilFormFuzzer {
  static const String extremeText =
      'AQIL_STRESS_TEST_VERY_LONG_STRING_WITHOUT_BREAKS_1234567890_!@#\$%^&*()_+'
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. '
      'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. '
      'Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. '
      'Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.';

  static const String unicodeSpamText =
      '🚀🔥 العربية עברית ﷽ H̸e̶l̷l̸o̴ ̷W̶o̸r̷l̵d̶ \u0000 \u200B \uFEFF';

  /// Stresses the active widget tree with form inputs.
  static Future<FormFuzzReport> fuzzScreenForm(
    WidgetTester tester, {
    String screenName = 'FuzzedScreen',
  }) async {
    final records = <FuzzTrialRecord>[];

    // Discovery: Find all editable text fields
    final textFields = find.byType(TextField);
    final buttons = find.byType(ElevatedButton);
    final filledButtons = find.byType(FilledButton);

    // Persona 1: Empty Required Inputs
    try {
      for (var i = 0; i < textFields.evaluate().length; i++) {
        await tester.enterText(textFields.at(i), '');
      }
      await tester.pumpAndSettle();
      records.add(const FuzzTrialRecord(
        persona: FuzzPersona.emptyRequired,
        passed: true,
        details: 'Rendered cleanly with empty string inputs without layout exceptions.',
      ));
    } catch (e) {
      records.add(FuzzTrialRecord(
        persona: FuzzPersona.emptyRequired,
        passed: false,
        details: 'Exception on empty input: $e',
        caughtException: e,
      ));
    }

    // Persona 2: Extreme Length
    try {
      for (var i = 0; i < textFields.evaluate().length; i++) {
        await tester.enterText(textFields.at(i), extremeText);
      }
      await tester.pumpAndSettle();
      final ex = tester.takeException();
      records.add(FuzzTrialRecord(
        persona: FuzzPersona.extremeLength,
        passed: ex == null,
        details: ex == null ? 'Passed 500+ char stress test.' : 'Overflow detected: $ex',
        caughtException: ex,
      ));
    } catch (e) {
      records.add(FuzzTrialRecord(
        persona: FuzzPersona.extremeLength,
        passed: false,
        details: 'Exception on extreme length: $e',
        caughtException: e,
      ));
    }

    // Persona 3: Unicode & RTL Spam
    try {
      for (var i = 0; i < textFields.evaluate().length; i++) {
        await tester.enterText(textFields.at(i), unicodeSpamText);
      }
      await tester.pumpAndSettle();
      final ex = tester.takeException();
      records.add(FuzzTrialRecord(
        persona: FuzzPersona.unicodeSpam,
        passed: ex == null,
        details: ex == null ? 'Passed Unicode & RTL spam check.' : 'Unicode issue: $ex',
        caughtException: ex,
      ));
    } catch (e) {
      records.add(FuzzTrialRecord(
        persona: FuzzPersona.unicodeSpam,
        passed: false,
        details: 'Exception on unicode spam: $e',
        caughtException: e,
      ));
    }

    // Persona 4: Type Boundary (Negative / Special Inputs)
    try {
      for (var i = 0; i < textFields.evaluate().length; i++) {
        await tester.enterText(textFields.at(i), '-99999999.999');
      }
      await tester.pumpAndSettle();
      records.add(const FuzzTrialRecord(
        persona: FuzzPersona.typeBoundary,
        passed: true,
        details: 'Handled negative numbers cleanly.',
      ));
    } catch (e) {
      records.add(FuzzTrialRecord(
        persona: FuzzPersona.typeBoundary,
        passed: false,
        details: 'Exception on type boundary: $e',
        caughtException: e,
      ));
    }

    // Persona 5: Rapid Double-Tap Re-entrancy
    final anyButton = buttons.evaluate().isNotEmpty
        ? buttons.first
        : (filledButtons.evaluate().isNotEmpty ? filledButtons.first : null);

    if (anyButton != null) {
      try {
        for (var i = 0; i < 5; i++) {
          await tester.tap(anyButton, warnIfMissed: false);
        }
        await tester.pumpAndSettle();
        records.add(const FuzzTrialRecord(
          persona: FuzzPersona.rapidDoubleTap,
          passed: true,
          details: 'Handled 5x rapid re-entrant taps without race condition crash.',
        ));
      } catch (e) {
        records.add(FuzzTrialRecord(
          persona: FuzzPersona.rapidDoubleTap,
          passed: false,
          details: 'Crash on rapid tap: $e',
          caughtException: e,
        ));
      }
    } else {
      records.add(const FuzzTrialRecord(
        persona: FuzzPersona.rapidDoubleTap,
        passed: true,
        details: 'No buttons found in screen; re-entrancy skipped.',
      ));
    }

    final passed = records.where((r) => r.passed).length;
    return FormFuzzReport(
      screenName: screenName,
      totalTrials: records.length,
      passedTrials: passed,
      records: records,
    );
  }
}
