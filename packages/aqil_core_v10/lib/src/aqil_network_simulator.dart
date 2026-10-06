import 'package:flutter/widgets.dart';

/// Simulated network profiles.
enum SimulatedNetworkState {
  online('Full Broadband WiFi / 5G (0ms delay)'),
  flaky2G('Degraded 2G / Edge (1500ms delay + 25% drop)'),
  offline('Airplane Mode / Disconnected (No connection)'),
  serverError('HTTP 500 / Gateway Timeout Chaos');

  final String description;
  const SimulatedNetworkState(this.description);
}

/// Inherited provider for mocking network states in UI subtrees.
class AqilNetworkScope extends InheritedWidget {
  final SimulatedNetworkState state;
  final Duration simulatedDelay;
  final bool shouldSimulateFailure;

  const AqilNetworkScope({
    super.key,
    required this.state,
    this.simulatedDelay = Duration.zero,
    this.shouldSimulateFailure = false,
    required super.child,
  });

  static AqilNetworkScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AqilNetworkScope>();
  }

  static SimulatedNetworkState stateOf(BuildContext context) {
    return maybeOf(context)?.state ?? SimulatedNetworkState.online;
  }

  static bool isOffline(BuildContext context) {
    final s = stateOf(context);
    return s == SimulatedNetworkState.offline;
  }

  @override
  bool updateShouldNotify(covariant AqilNetworkScope oldWidget) {
    return state != oldWidget.state ||
        simulatedDelay != oldWidget.simulatedDelay ||
        shouldSimulateFailure != oldWidget.shouldSimulateFailure;
  }
}

/// Autonomous Network Degradation Simulator (AQIL Frontier 2).
///
/// Wraps widgets with controlled network profiles to test loading spinners,
/// error banners, offline caching, and retry actions without external dependencies.
class AqilNetworkSimulator {
  /// Wraps a widget with offline airplane mode conditions.
  static Widget offline({required Widget child}) {
    return AqilNetworkScope(
      state: SimulatedNetworkState.offline,
      shouldSimulateFailure: true,
      child: child,
    );
  }

  /// Wraps a widget with high-latency flaky connection conditions.
  static Widget flaky2G({required Widget child, Duration delay = const Duration(milliseconds: 1500)}) {
    return AqilNetworkScope(
      state: SimulatedNetworkState.flaky2G,
      simulatedDelay: delay,
      shouldSimulateFailure: false,
      child: child,
    );
  }

  /// Wraps a widget with HTTP 500 server error chaos.
  static Widget serverError({required Widget child}) {
    return AqilNetworkScope(
      state: SimulatedNetworkState.serverError,
      shouldSimulateFailure: true,
      child: child,
    );
  }
}
