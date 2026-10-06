import 'package:flutter/material.dart';

/// Content density level options (Linear, Slack, Notion, GitHub standard).
enum AqilDensityLevel {
  compact(0.75, 40.0),
  standard(1.0, 52.0),
  spacious(1.25, 64.0);

  final double spacingMultiplier;
  final double defaultRowHeight;

  const AqilDensityLevel(this.spacingMultiplier, this.defaultRowHeight);
}

/// Inherited scope providing dynamic content density scaling across subtrees.
class AqilDensityScope extends InheritedWidget {
  final AqilDensityLevel level;

  const AqilDensityScope({
    super.key,
    required this.level,
    required super.child,
  });

  /// Retrieves the nearest [AqilDensityLevel] or defaults to [AqilDensityLevel.standard].
  static AqilDensityLevel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AqilDensityScope>();
    return scope?.level ?? AqilDensityLevel.standard;
  }

  /// Calculates clamped spacing adjusted for current density.
  static double spacing(BuildContext context, double baseSpacing) {
    final m = of(context).spacingMultiplier;
    return (baseSpacing * m).clamp(2.0, 48.0);
  }

  /// Calculates edge insets adjusted for current density.
  static EdgeInsets insets(
    BuildContext context, {
    double horizontal = 16.0,
    double vertical = 12.0,
  }) {
    final m = of(context).spacingMultiplier;
    return EdgeInsets.symmetric(
      horizontal: (horizontal * m).clamp(4.0, 32.0),
      vertical: (vertical * m).clamp(4.0, 28.0),
    );
  }

  @override
  bool updateShouldNotify(AqilDensityScope oldWidget) => level != oldWidget.level;
}

/// Responsive list tile or row adhering strictly to [AqilDensityScope].
class AqilDensityRow extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const AqilDensityRow({
    super.key,
    required this.leading,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final level = AqilDensityScope.of(context);
    final insets = AqilDensityScope.insets(context, horizontal: 16.0, vertical: 10.0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        constraints: BoxConstraints(minHeight: level.defaultRowHeight),
        padding: insets,
        child: Row(
          children: [
            leading,
            SizedBox(width: 12.0 * level.spacingMultiplier),
            Expanded(child: title),
            if (trailing != null) ...[
              SizedBox(width: 12.0 * level.spacingMultiplier),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
