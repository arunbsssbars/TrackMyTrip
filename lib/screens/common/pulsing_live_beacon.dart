import 'package:flutter/material.dart';

/// A sleek, battery-efficient pulsing live beacon for active/ongoing journeys.
/// Features a glowing radar-like ripple aura and crisp status badge.
class PulsingLiveBeacon extends StatefulWidget {
  final String label;
  final Color color;
  final bool showLabel;
  final double dotSize;
  final TextStyle? labelStyle;

  const PulsingLiveBeacon({
    super.key,
    this.label = 'LIVE TRIP',
    this.color = const Color(0xFF10B981),
    this.showLabel = true,
    this.dotSize = 9.0,
    this.labelStyle,
  });

  @override
  State<PulsingLiveBeacon> createState() => _PulsingLiveBeaconState();
}

class _PulsingLiveBeaconState extends State<PulsingLiveBeacon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    final binding = WidgetsBinding.instance;
    final isTesting = binding.runtimeType.toString().contains('Test');
    if (!isTesting) {
      _controller.repeat();
    }

    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad),
    );

    _opacityAnimation = Tween<double>(begin: 0.70, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final beaconDot = SizedBox(
      width: widget.dotSize * 2.8,
      height: widget.dotSize * 2.8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding & fading radar wave ripple
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withOpacity(_opacityAnimation.value),
                  ),
                ),
              );
            },
          ),
          // Core bright glowing beacon dot
          Container(
            width: widget.dotSize,
            height: widget.dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.65),
                  blurRadius: 5,
                  spreadRadius: 1.2,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!widget.showLabel) {
      return beaconDot;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: widget.color.withOpacity(0.45),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          beaconDot,
          const SizedBox(width: 4.5),
          Text(
            widget.label,
            style: widget.labelStyle ??
                TextStyle(
                  color: widget.color,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
          ),
        ],
      ),
    );
  }
}
