import 'package:flutter/material.dart';

/// Reusable drag handle indicator for bottom sheets and modal dialogs.
class SheetDragHandle extends StatelessWidget {
  final double width;
  final double height;
  final EdgeInsetsGeometry margin;
  final Color? color;

  const SheetDragHandle({
    super.key,
    this.width = 40.0,
    this.height = 4.0,
    this.margin = const EdgeInsets.only(top: 12, bottom: 8),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = color ?? (isDark ? Colors.white24 : Colors.black12);

    return Center(
      child: Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: effectiveColor,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
  }
}
