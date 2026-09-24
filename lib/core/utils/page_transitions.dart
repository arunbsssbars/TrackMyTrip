import 'package:flutter/cupertino.dart';

/// High-performance page route with smooth cubic easing and interactive swipe-to-back gesture
class AppPageRoute<T> extends PageRoute<T> with CupertinoRouteTransitionMixin<T> {
  final WidgetBuilder builder;
  @override
  final bool maintainState;
  final Duration customDuration;

  AppPageRoute({
    required this.builder,
    super.settings,
    this.maintainState = true,
    super.fullscreenDialog = false,
    this.customDuration = const Duration(milliseconds: 280),
  });

  @override
  Widget buildContent(BuildContext context) => builder(context);

  @override
  String? get title => null;

  @override
  Duration get transitionDuration => customDuration;

  @override
  Duration get reverseTransitionDuration => customDuration;
}

/// Convenience navigation helper for consistent smooth screen transitions across the app
class AppNavigator {
  AppNavigator._();

  /// Pushes a new screen with smooth slide transition and swipe-to-back support
  static Future<T?> push<T>(BuildContext context, Widget screen, {RouteSettings? settings}) {
    return Navigator.of(context).push<T>(
      AppPageRoute<T>(
        builder: (_) => screen,
        settings: settings,
      ),
    );
  }

  /// Replaces current screen with a new screen using smooth transition
  static Future<T?> pushReplacement<T, TO>(BuildContext context, Widget screen, {RouteSettings? settings}) {
    return Navigator.of(context).pushReplacement<T, TO>(
      AppPageRoute<T>(
        builder: (_) => screen,
        settings: settings,
      ),
    );
  }

  /// Safely pops the current screen if navigation stack allows
  static void pop<T>(BuildContext context, [T? result]) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop<T>(result);
    }
  }
}
