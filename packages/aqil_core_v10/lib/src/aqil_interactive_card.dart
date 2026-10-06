import 'package:flutter/material.dart';

/// An interactive tactile card container with smooth hover elevation, tap spring bounce,
/// and subtle 1px border highlights inspired by Linear and Stripe dashboard cards.
class AqilInteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const AqilInteractiveCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16.0),
    this.borderRadius = 16.0,
  });

  @override
  State<AqilInteractiveCard> createState() => _AqilInteractiveCardState();
}

class _AqilInteractiveCardState extends State<AqilInteractiveCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark
        ? const Color(0xFF13151A)
        : Colors.white;

    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(color: border, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: _isPressed ? 6.0 : 12.0,
                offset: Offset(0, _isPressed ? 2.0 : 4.0),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
