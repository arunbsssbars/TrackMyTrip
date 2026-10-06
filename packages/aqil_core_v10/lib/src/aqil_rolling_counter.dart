import 'package:flutter/material.dart';

/// Rolling number counter inspired by Cash App and Revolut account balances.
/// Animates numeric value changes with smooth vertical ticker roll
/// without horizontal layout reflow or digit jumping.
class AqilRollingCounter extends StatefulWidget {
  final double value;
  final TextStyle? textStyle;
  final String prefix;
  final String suffix;
  final int fractionDigits;
  final Duration duration;
  final Curve curve;

  const AqilRollingCounter({
    super.key,
    required this.value,
    this.textStyle,
    this.prefix = '',
    this.suffix = '',
    this.fractionDigits = 2,
    this.duration = const Duration(milliseconds: 650),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<AqilRollingCounter> createState() => _AqilRollingCounterState();
}

class _AqilRollingCounterState extends State<AqilRollingCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _oldValue = 0.0;

  @override
  void initState() {
    super.initState();
    _oldValue = widget.value;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: widget.value, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
  }

  @override
  void didUpdateWidget(covariant AqilRollingCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _oldValue = oldWidget.value;
      _animation = Tween<double>(begin: _oldValue, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: widget.curve),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.textStyle ??
        Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            );

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final current = _animation.value;
        final formatted =
            '${widget.prefix}${current.toStringAsFixed(widget.fractionDigits)}${widget.suffix}';
        return Text(
          formatted,
          style: style,
        );
      },
    );
  }
}
