import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Categories of chaotic user actions simulated during monkey fuzzing.
enum MonkeyActionType {
  tap,
  rapidDoubleTap,
  scrollFling,
  chaosTextEntry,
  dualSimultaneousTap,
  dragReversal,
}

/// A recorded chaotic event step in a fuzzing session.
class MonkeyEvent {
  final int step;
  final MonkeyActionType type;
  final String targetDescription;
  final String details;
  final Duration timestamp;

  const MonkeyEvent({
    required this.step,
    required this.type,
    required this.targetDescription,
    required this.details,
    required this.timestamp,
  });

  @override
  String toString() => 'Step $step [${type.name}] on "$targetDescription": $details';
}

/// Outcome of an AQIL Interactive Chaos & State-Machine Monkey Fuzzing pass.
class ChaosMonkeyReport {
  final int seed;
  final int totalActionsAttempted;
  final int successfulActions;
  final bool hasCrashes;
  final List<String> capturedExceptions;
  final List<MonkeyEvent> eventLog;
  final Duration duration;

  const ChaosMonkeyReport({
    required this.seed,
    required this.totalActionsAttempted,
    required this.successfulActions,
    required this.hasCrashes,
    required this.capturedExceptions,
    required this.eventLog,
    required this.duration,
  });

  bool get isResilient => !hasCrashes && capturedExceptions.isEmpty;

  /// Generates a step-by-step reproduction script to replay a failed session.
  String generateReproductionScript() {
    final buffer = StringBuffer();
    buffer.writeln('=== AQIL Chaos Monkey Reproduction Trace (Seed: $seed) ===');
    buffer.writeln('Total Actions: $successfulActions / $totalActionsAttempted');
    buffer.writeln('Status: ${isResilient ? "RESILIENT (PASS)" : "CRASH DETECTED (FAIL)"}');

    if (capturedExceptions.isNotEmpty) {
      buffer.writeln('\nCaptured Exceptions:');
      for (final ex in capturedExceptions) {
        buffer.writeln('  - $ex');
      }
    }

    buffer.writeln('\nAction Execution Log:');
    for (final event in eventLog) {
      buffer.writeln('  $event');
    }

    return buffer.toString();
  }
}

/// Interactive Chaos & State-Machine Monkey Fuzzing Engine (AQIL Frontier 5).
///
/// Simulates randomized, high-frequency, non-linear human interactions
/// (rapid multi-taps, violent flings, simultaneous touches, input fuzzing)
/// to discover UI deadlocks, unhandled async race conditions, and RenderFlex explosions.
class AqilChaosMonkey {
  /// Chaos text payloads designed to test input bounds and encoding safety.
  static const List<String> chaosPayloads = [
    'Normal text',
    'VERY_LONG_STRING_WITHOUT_WHITESPACE_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
    'Unicode: 🚀🔥🎉❤️💻🤖👨‍👩‍👧‍👦',
    'Special Chars: <script>alert("xss")</script> \' OR \'1\'=\'1\'; --',
    'Newlines:\n\n\n\r\n\t\t\tEnd',
    '   Leading & Trailing Spaces   ',
    'Zero Width: \u200B\u200C\u200D',
  ];

  /// Runs an automated Chaos Monkey fuzzing session against the pumped widget tree.
  static Future<ChaosMonkeyReport> runFuzzingSession(
    WidgetTester tester, {
    int seed = 42,
    int actionCount = 15,
    Duration stepInterval = const Duration(milliseconds: 50),
    bool settleBetweenSteps = true,
  }) async {
    final random = math.Random(seed);
    final stopwatch = Stopwatch()..start();
    final eventLog = <MonkeyEvent>[];
    final exceptions = <String>[];
    int successfulActions = 0;

    for (int step = 1; step <= actionCount; step++) {
      final actionType = MonkeyActionType.values[random.nextInt(MonkeyActionType.values.length)];

      try {
        switch (actionType) {
          case MonkeyActionType.tap:
            final buttons = find.byType(ElevatedButton);
            final filled = find.byType(FilledButton);
            final icons = find.byType(IconButton);
            final inkWells = find.byType(InkWell);

            final candidates = [buttons, filled, icons, inkWells];
            final available = candidates.where((f) => f.evaluate().isNotEmpty).toList();

            if (available.isNotEmpty) {
              final chosenFinder = available[random.nextInt(available.length)];
              await tester.tap(chosenFinder.first);
              eventLog.add(MonkeyEvent(
                step: step,
                type: actionType,
                targetDescription: chosenFinder.first.toString(),
                details: 'Single tap executed',
                timestamp: stopwatch.elapsed,
              ));
              successfulActions++;
            }
            break;

          case MonkeyActionType.rapidDoubleTap:
            final allInteractive = find.byType(FilledButton);
            if (allInteractive.evaluate().isNotEmpty) {
              final target = allInteractive.first;
              await tester.tap(target);
              await tester.pump(const Duration(milliseconds: 20));
              await tester.tap(target);
              eventLog.add(MonkeyEvent(
                step: step,
                type: actionType,
                targetDescription: target.toString(),
                details: 'Rapid double tap within 20ms executed',
                timestamp: stopwatch.elapsed,
              ));
              successfulActions++;
            }
            break;

          case MonkeyActionType.scrollFling:
            final scrollables = find.byType(Scrollable);
            if (scrollables.evaluate().isNotEmpty) {
              final target = scrollables.first;
              final dy = (random.nextBool() ? 1 : -1) * (150.0 + random.nextDouble() * 300.0);
              await tester.drag(target, Offset(0, dy));
              eventLog.add(MonkeyEvent(
                step: step,
                type: actionType,
                targetDescription: 'Scrollable Viewport',
                details: 'Fling offset: dy=${dy.toStringAsFixed(1)}',
                timestamp: stopwatch.elapsed,
              ));
              successfulActions++;
            }
            break;

          case MonkeyActionType.chaosTextEntry:
            final textFields = find.byType(TextField);
            if (textFields.evaluate().isNotEmpty) {
              final target = textFields.first;
              final payload = chaosPayloads[random.nextInt(chaosPayloads.length)];
              await tester.enterText(target, payload);
              eventLog.add(MonkeyEvent(
                step: step,
                type: actionType,
                targetDescription: 'TextField Form Input',
                details: 'Injected payload: "$payload"',
                timestamp: stopwatch.elapsed,
              ));
              successfulActions++;
            }
            break;

          case MonkeyActionType.dualSimultaneousTap:
            final targets = find.byType(FilledButton);
            if (targets.evaluate().length >= 2) {
              final first = tester.getCenter(targets.at(0));
              final second = tester.getCenter(targets.at(1));

              final gesture1 = await tester.startGesture(first);
              final gesture2 = await tester.startGesture(second);
              await tester.pump(const Duration(milliseconds: 10));
              await gesture1.up();
              await gesture2.up();

              eventLog.add(MonkeyEvent(
                step: step,
                type: actionType,
                targetDescription: 'Dual Targets',
                details: 'Simultaneous multi-touch at $first and $second',
                timestamp: stopwatch.elapsed,
              ));
              successfulActions++;
            }
            break;

          case MonkeyActionType.dragReversal:
            final scrollables = find.byType(Scrollable);
            if (scrollables.evaluate().isNotEmpty) {
              final target = scrollables.first;
              final gesture = await tester.startGesture(tester.getCenter(target));
              await gesture.moveBy(const Offset(0, 100));
              await tester.pump(const Duration(milliseconds: 10));
              await gesture.moveBy(const Offset(0, -200));
              await tester.pump(const Duration(milliseconds: 10));
              await gesture.up();

              eventLog.add(MonkeyEvent(
                step: step,
                type: actionType,
                targetDescription: 'Scrollable Viewport',
                details: 'Violent drag reversal down 100px then up 200px',
                timestamp: stopwatch.elapsed,
              ));
              successfulActions++;
            }
            break;
        }

        if (settleBetweenSteps) {
          await tester.pump(stepInterval);
        }

        final ex = tester.takeException();
        if (ex != null) {
          exceptions.add('Exception at step $step ($actionType): $ex');
        }
      } catch (err) {
        exceptions.add('Framework failure at step $step ($actionType): $err');
      }
    }

    stopwatch.stop();

    return ChaosMonkeyReport(
      seed: seed,
      totalActionsAttempted: actionCount,
      successfulActions: successfulActions,
      hasCrashes: exceptions.isNotEmpty,
      capturedExceptions: exceptions,
      eventLog: eventLog,
      duration: stopwatch.elapsed,
    );
  }
}
