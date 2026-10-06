import 'package:flutter/material.dart';

/// Spring curve constants replicating Apple iOS & Linear spring physics.
class AqilSpringCurves {
  /// Bouncy micro-interaction spring (buttons, toggles, icon pops).
  static const Curve snappySpring = Cubic(0.2, 0.9, 0.2, 1.15);

  /// Damped smooth sheet/drawer transition spring.
  static const Curve smoothDamped = Cubic(0.32, 0.72, 0.0, 1.0);

  /// Expressive modal dialog pop spring.
  static const Curve popSpring = Cubic(0.34, 1.56, 0.64, 1.0);
}

/// A tactile interactive wrapper that applies subtle spring bounce scale (scale: 0.96)
/// and smooth recovery on user taps, mirroring Linear and Cash App button physics.
class AqilSpringBounce extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final Duration duration;

  const AqilSpringBounce({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
    this.duration = const Duration(milliseconds: 120),
  });

  @override
  State<AqilSpringBounce> createState() => _AqilSpringBounceState();
}

class _AqilSpringBounceState extends State<AqilSpringBounce> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? widget.pressedScale : 1.0,
        curve: _isPressed ? Curves.easeOutQuad : AqilSpringCurves.snappySpring,
        duration: widget.duration,
        child: widget.child,
      ),
    );
  }
}

/// Diagnostic report on animation curve quality.
class AqilAnimationAuditReport {
  final int totalAuditedAnimations;
  final int linearOrRigidCurvesFound;
  final List<String> warnings;

  const AqilAnimationAuditReport({
    required this.totalAuditedAnimations,
    required this.linearOrRigidCurvesFound,
    required this.warnings,
  });

  bool get isFluid => linearOrRigidCurvesFound == 0;
}

/// Audits animation curves to ensure transitions do not use mechanical linear
/// or abrupt ease-in/outs, recommending fluid damped or spring curves.
class AqilSpringAnimationAuditor {
  static const Set<Curve> rigidCurves = {
    Curves.linear,
    Curves.easeIn,
    Curves.easeOut,
  };

  /// Evaluates an animation curve and returns recommendations for natural motion.
  static String? auditCurve(Curve curve, {String context = 'transition'}) {
    if (rigidCurves.contains(curve)) {
      return 'Animation in "$context" uses mechanical curve ($curve). Suggest using AqilSpringCurves.smoothDamped or Curves.easeInOutCubic.';
    }
    return null;
  }
}
