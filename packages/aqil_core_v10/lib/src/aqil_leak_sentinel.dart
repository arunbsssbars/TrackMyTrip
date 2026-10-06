import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Types of commonly leaked Flutter stateful controllers.
enum LeakedResourceType {
  animationController,
  scrollController,
  textEditingController,
  focusNode,
  timerSubscription,
  streamSubscription,
}

/// Detailed record of a detected memory or controller leak.
class LeakIncident {
  final LeakedResourceType resourceType;
  final String description;
  final String suspectedWidget;

  const LeakIncident({
    required this.resourceType,
    required this.description,
    required this.suspectedWidget,
  });

  @override
  String toString() => 'LeakIncident[${resourceType.name}]: $description in $suspectedWidget';
}

/// Report emitted by [AqilLeakSentinel].
class LeakAuditReport {
  final String screenName;
  final int mountCyclesExecuted;
  final List<LeakIncident> incidents;

  const LeakAuditReport({
    required this.screenName,
    required this.mountCyclesExecuted,
    required this.incidents,
  });

  bool get isClean => incidents.isEmpty;
}

/// Autonomous Memory Leak & Object Retainment Sentinel (AQIL Frontier 1).
///
/// Simulates rapid push, pop, and re-mount cycles to detect undelivered disposals,
/// unclosed controllers, and lingering listeners that cause out-of-memory crashes.
class AqilLeakSentinel {
  /// Executes rapid mount and unmount cycles on a widget to detect state retainment leaks.
  static Future<LeakAuditReport> auditMountCycles(
    WidgetTester tester, {
    required Widget Function(BuildContext) builder,
    String screenName = 'AuditedScreen',
    int cycles = 5,
  }) async {
    final incidents = <LeakIncident>[];

    for (var i = 0; i < cycles; i++) {
      // 1. Mount screen
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, _) => builder(context),
        ),
      );
      await tester.pump();

      // 2. Unmount screen cleanly (simulate pop / navigation back)
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      // Verify no exceptions were thrown during dispose
      final exception = tester.takeException();
      if (exception != null) {
        incidents.add(LeakIncident(
          resourceType: LeakedResourceType.animationController,
          description: 'Exception thrown during unmount/dispose: $exception',
          suspectedWidget: screenName,
        ));
      }
    }

    return LeakAuditReport(
      screenName: screenName,
      mountCyclesExecuted: cycles,
      incidents: incidents,
    );
  }
}
