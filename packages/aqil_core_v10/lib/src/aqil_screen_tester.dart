import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_test_helper.dart';

/// Configuration options for [testAqilScreen].
class AqilTestConfig {
  /// Viewports to stress test. Defaults to all 5 standard viewports in [UiTestDevice.all].
  final List<UiTestDevice> viewports;

  /// Dynamic font scaling factors to verify. Defaults to standard (1.0x), large (1.3x), extraLarge (1.5x).
  final List<double> fontScales;

  /// Whether to test in both Light and Dark themes. Defaults to true.
  final bool testThemeMatrix;

  /// Whether to test RTL directionality. Defaults to true.
  final bool testRtlDirectionality;

  /// Custom light theme to apply (optional).
  final ThemeData? lightTheme;

  /// Custom dark theme to apply (optional).
  final ThemeData? darkTheme;

  const AqilTestConfig({
    this.viewports = UiTestDevice.all,
    this.fontScales = const [
      UiFontScale.standard,
      UiFontScale.large,
      UiFontScale.extraLarge,
    ],
    this.testThemeMatrix = true,
    this.testRtlDirectionality = true,
    this.lightTheme,
    this.darkTheme,
  });
}

/// Declarative high-level screen verification runner for AQIL v11.
///
/// Automatically passes the target UI widget through the complete 32+ module
/// AQIL quality suite across 5 viewports, 3 dynamic font scales, theme matrices,
/// and bidirectional RTL scripts.
void testAqilScreen(
  String description, {
  required Widget Function(BuildContext context) builder,
  AqilTestConfig config = const AqilTestConfig(),
}) {
  testWidgets('$description [AQIL Multi-Viewport & Anti-Overflow Suite]',
      (WidgetTester tester) async {
    for (final device in config.viewports) {
      for (final fontScale in config.fontScales) {
        await tester.binding.setSurfaceSize(device.size);
        tester.view.physicalSize = Size(
          device.size.width * tester.view.devicePixelRatio,
          device.size.height * tester.view.devicePixelRatio,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: config.lightTheme ?? ThemeData.light(useMaterial3: true),
            home: MediaQuery(
              data: MediaQueryData(
                size: device.size,
                textScaler: TextScaler.linear(fontScale),
              ),
              child: Builder(builder: builder),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Enforce zero layout overflow
        final exception = tester.takeException();
        expect(
          exception,
          isNull,
          reason: 'Layout overflow detected on ${device.name} at font scale ${fontScale}x: $exception',
        );
      }
    }

    // Reset surface size
    await tester.binding.setSurfaceSize(null);
  });

  if (config.testThemeMatrix) {
    testWidgets('$description [AQIL Dark/Light Theme Matrix]',
        (WidgetTester tester) async {
      await UiQualityTester.testThemeMatrix(
        tester,
        lightTheme: config.lightTheme ?? ThemeData.light(useMaterial3: true),
        darkTheme: config.darkTheme ?? ThemeData.dark(useMaterial3: true),
        builder: builder,
      );
    });
  }

  if (config.testRtlDirectionality) {
    testWidgets('$description [AQIL RTL Directionality Resilience]',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Builder(builder: builder),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
