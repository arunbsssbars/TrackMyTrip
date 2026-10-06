import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_test_helper.dart';

/// Reusable boilerplate template for Autonomous UI Quality Iteration Loop (AQIL) tests.
/// Copy and customize this file to test any screen, dialog, or custom widget across
/// the full spectrum of enterprise device form factors and accessibility font scalers.
void main() {
  group('AQIL Template: [Screen / Widget Name]', () {
    testWidgets('Renders across all enterprise form factors without RenderFlex overflow',
        (WidgetTester tester) async {
      // 1. Build sample data or dependencies
      const sampleWidget = Scaffold(
        body: Center(
          child: Text(
            'Sample AQIL Screen',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );

      // 2. Execute multi-viewport responsive layout testing (320px to 1280px)
      await UiQualityTester.testResponsiveLayout(
        tester,
        child: sampleWidget,
        devices: UiTestDevice.all,
        fontScales: [UiFontScale.standard, UiFontScale.large, UiFontScale.extraLarge],
      );
    });

    testWidgets('Contains zero unsafe text clippings without ellipsis safeguards',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                'Sample Text With Safe Ellipsis',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final unsafeClipping = UiQualityTester.detectUnsafeClipping(tester);
      expect(
        unsafeClipping,
        isEmpty,
        reason: 'All text exceeding maximum allotted lines must have an ellipsis safeguard',
      );
    });
  });
}
