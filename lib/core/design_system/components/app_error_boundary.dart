import 'package:flutter/material.dart';
import 'app_error_retry.dart';

/// AQIL Resilient: Universal Error Boundary Component.
///
/// Wraps any widget subtree to capture build failures or runtime exceptions,
/// preventing unhandled crashes and presenting a recovery-oriented fallback UI.
class AppErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(BuildContext context, Object error, VoidCallback onReset)? errorBuilder;
  final void Function(Object error, StackTrace? stackTrace)? onError;
  final String fallbackTitle;
  final String fallbackMessage;

  const AppErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
    this.fallbackTitle = 'Unable to display this view',
    this.fallbackMessage = 'An unexpected issue occurred while rendering this section. Tap retry to reload.',
  });

  @override
  State<AppErrorBoundary> createState() => _AppErrorBoundaryState();
}

class _AppErrorBoundaryState extends State<AppErrorBoundary> {
  Object? _caughtError;

  @override
  void initState() {
    super.initState();
  }

  void _resetError() {
    setState(() {
      _caughtError = null;
    });
  }

  void catchError(Object error, StackTrace? stackTrace) {
    widget.onError?.call(error, stackTrace);
    if (mounted) {
      setState(() {
        _caughtError = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_caughtError != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, _caughtError!, _resetError);
      }
      return AppErrorRetry(
        title: widget.fallbackTitle,
        message: widget.fallbackMessage,
        onRetry: _resetError,
        retryLabel: 'Recover View',
      );
    }

    return _ErrorBoundaryScope(
      boundaryState: this,
      child: widget.child,
    );
  }
}

class _ErrorBoundaryScope extends InheritedWidget {
  final _AppErrorBoundaryState boundaryState;

  const _ErrorBoundaryScope({
    required this.boundaryState,
    required super.child,
  });

  @override
  bool updateShouldNotify(_ErrorBoundaryScope oldWidget) => false;
}

/// Extension helper to trigger boundary recovery or report an exception from descendant widgets.
extension AppErrorBoundaryX on BuildContext {
  void reportBoundaryError(Object error, [StackTrace? stackTrace]) {
    final scope = dependOnInheritedWidgetOfExactType<_ErrorBoundaryScope>();
    scope?.boundaryState.catchError(error, stackTrace);
  }
}
