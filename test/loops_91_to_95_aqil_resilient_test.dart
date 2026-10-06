import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/design_system/design_system.dart';

void main() {
  group('Loop 91: AppErrorBoundary Resilience Tests', () {
    testWidgets('AppErrorBoundary renders child normally when healthy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppErrorBoundary(
              child: Text('Normal Content'),
            ),
          ),
        ),
      );

      expect(find.text('Normal Content'), findsOneWidget);
      expect(find.byType(AppErrorRetry), findsNothing);
    });

    testWidgets('AppErrorBoundary presents AppErrorRetry on error report and recovers on retry', (tester) async {
      bool shouldThrow = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorBoundary(
              child: Builder(
                builder: (context) {
                  if (shouldThrow) {
                    return ElevatedButton(
                      onPressed: () {
                        context.reportBoundaryError(Exception('Simulated crash'));
                      },
                      child: const Text('Trigger Crash'),
                    );
                  }
                  return const Text('Recovered Successfully');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Trigger Crash'), findsOneWidget);

      // Trigger error reporting
      await tester.tap(find.text('Trigger Crash'));
      await tester.pumpAndSettle();

      // Fallback is rendered
      expect(find.byType(AppErrorRetry), findsOneWidget);
      expect(find.text('Unable to display this view'), findsOneWidget);
      expect(find.text('Recover View'), findsOneWidget);

      // Reset condition and tap retry
      shouldThrow = false;
      await tester.tap(find.text('Recover View'));
      await tester.pumpAndSettle();

      expect(find.text('Recovered Successfully'), findsOneWidget);
      expect(find.byType(AppErrorRetry), findsNothing);
    });

    testWidgets('AppErrorBoundary executes custom errorBuilder when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorBoundary(
              errorBuilder: (context, error, onReset) {
                return Text('Custom: $error');
              },
              child: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      context.reportBoundaryError('Custom fail');
                    },
                    child: const Text('Fail'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Fail'));
      await tester.pumpAndSettle();

      expect(find.text('Custom: Custom fail'), findsOneWidget);
    });
  });

  group('Loop 92: AppResilientText & Typography Guard Tests', () {
    test('joinMetadata joins non-empty strings with default and custom delimiters', () {
      final joined = AppResilientText.joinMetadata(['10 stops', null, '  ', '2h 15m', '']);
      expect(joined, equals('10 stops • 2h 15m'));

      final customJoined = AppResilientText.joinMetadata(['Solo', 'Paris'], delimiter: ' | ');
      expect(customJoined, equals('Solo | Paris'));
    });

    testWidgets('AppResilientText clamps excessive font scaling for badges', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(2.5),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: AppResilientText.badge('LIVE'),
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.textScaler, isNotNull);
      // Evaluates text scaling on font size 10
      final scaled = textWidget.textScaler!.scale(10.0);
      expect(scaled, lessThanOrEqualTo(12.5)); // maxScaleFactor 1.25 * 10 = 12.5
    });

    testWidgets('AppResilientText.body allows higher scaling for readability', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(2.0),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: AppResilientText.body('Long narrative text for accessibility'),
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.textScaler, isNotNull);
      final scaled = textWidget.textScaler!.scale(10.0);
      expect(scaled, equals(20.0)); // 2.0 * 10 = 20.0
    });
  });

  group('Loop 93: Ultra-Narrow 320px Viewport Scaling Resilience', () {
    testWidgets('FittedBox scales down very large currency amounts without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 80,
              height: 40,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('₹99,999,999.00'),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('₹99,999,999.00'), findsOneWidget);
    });
  });

  group('Loop 94: Sync Status Badge Accessibility & Semantics', () {
    testWidgets('Sync badge renders with tooltip and accessible semantics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                Tooltip(
                  message: 'Cloud Sync: Synced. Tap for details',
                  child: Semantics(
                    button: true,
                    label: 'Sync Status: Synced',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(25),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_done_rounded, size: 13, color: Colors.green),
                          SizedBox(width: 5),
                          AppResilientText.badge(
                            'Synced',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byTooltip('Cloud Sync: Synced. Tap for details'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Sync Status: Synced'), findsOneWidget);
      expect(find.text('Synced'), findsOneWidget);
    });
  });
}
