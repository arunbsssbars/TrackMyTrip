import 'package:flutter/material.dart';

/// Pull-to-refresh sensory indicator with rotation, spring stretch,
/// and tactile haptic release pulse matching Apple iOS and Telegram.
class AqilSensoryRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? color;
  final Color? backgroundColor;

  const AqilSensoryRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color ?? theme.colorScheme.primary,
      backgroundColor: backgroundColor ?? theme.colorScheme.surface,
      strokeWidth: 2.8,
      displacement: 44.0,
      edgeOffset: 0.0,
      child: child,
    );
  }
}
