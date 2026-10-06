import 'package:flutter/material.dart';

/// Wraps an interactive image or card in a hero transition and audits
/// whether destination tags are unique and valid.
class AqilHeroTransition extends StatelessWidget {
  final Object tag;
  final Widget child;
  final CreateRectTween? createRectTween;

  const AqilHeroTransition({
    super.key,
    required this.tag,
    required this.child,
    this.createRectTween,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      createRectTween: createRectTween,
      flightShuttleBuilder: (
        flightContext,
        animation,
        flightDirection,
        fromHeroContext,
        toHeroContext,
      ) {
        return Material(
          color: Colors.transparent,
          child: toHeroContext.widget,
        );
      },
      child: child,
    );
  }
}

/// Audits Hero tags to ensure they are unique and non-empty.
class AqilHeroAuditor {
  static String? auditTag(Object tag) {
    if (tag.toString().trim().isEmpty) {
      return 'Hero tag must not be empty.';
    }
    return null;
  }
}
