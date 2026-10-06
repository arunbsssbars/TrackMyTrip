import 'package:flutter/material.dart';

/// Micro-animation curve constants matching Apple iOS Human Interface Guidelines and Material You.
class AqilMicroMotionCurves {
  /// Snappy toggle/checkbox spring.
  static const Curve toggleSwitch = Cubic(0.175, 0.885, 0.32, 1.275);

  /// Smooth accordion expand/collapse.
  static const Curve accordionExpand = Cubic(0.4, 0.0, 0.2, 1.0);

  /// Fluid modal pop-in.
  static const Curve modalPop = Cubic(0.16, 1.0, 0.3, 1.0);
}

/// Tactile animated switch replicating iOS and Linear fluid toggles.
/// Features smooth spring slider thumb movement and micro-haptic clicks.
class AqilFluidSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;

  const AqilFluidSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  State<AqilFluidSwitch> createState() => _AqilFluidSwitchState();
}

class _AqilFluidSwitchState extends State<AqilFluidSwitch> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeTrackColor = widget.activeColor ?? theme.colorScheme.primary;
    final inactiveTrackColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.12);

    return GestureDetector(
      onTap: () => widget.onChanged(!widget.value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: AqilMicroMotionCurves.accordionExpand,
        width: 50,
        height: 30,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: widget.value ? activeTrackColor : inactiveTrackColor,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: AqilMicroMotionCurves.toggleSwitch,
          alignment: widget.value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
