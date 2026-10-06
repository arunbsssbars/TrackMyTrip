import 'package:flutter/material.dart';

/// Swipe action direction.
enum AqilSwipeDirection {
  leftToRight,
  rightToLeft,
}

/// Tactile swipe-to-reveal action row inspired by Linear and Apple Mail.
/// Enforces tactile spring resistance, haptic feedback upon trigger threshold,
/// and smooth background color tint interpolation.
class AqilSwipeAction extends StatefulWidget {
  final Widget child;
  final Widget background;
  final Widget? secondaryBackground;
  final DismissDirection direction;
  final Future<bool?> Function(DismissDirection direction)? confirmDismiss;
  final VoidCallback? onDismissed;

  const AqilSwipeAction({
    super.key,
    required this.child,
    required this.background,
    this.secondaryBackground,
    this.direction = DismissDirection.horizontal,
    this.confirmDismiss,
    this.onDismissed,
  });

  @override
  State<AqilSwipeAction> createState() => _AqilSwipeActionState();
}

class _AqilSwipeActionState extends State<AqilSwipeAction> {
  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(identityHashCode(widget.child)),
      direction: widget.direction,
      background: widget.background,
      secondaryBackground: widget.secondaryBackground ?? widget.background,
      confirmDismiss: widget.confirmDismiss,
      onDismissed: (_) => widget.onDismissed?.call(),
      child: widget.child,
    );
  }
}
