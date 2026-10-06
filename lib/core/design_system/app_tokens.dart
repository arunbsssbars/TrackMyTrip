import 'package:flutter/material.dart';

/// Semantic spacing tokens based on an 8-pt / 4-pt grid system.
abstract final class AppSpacing {
  /// 2dp micro spacing (hairline gap)
  static const double xxs = 2.0;

  /// 4dp extra-small spacing
  static const double xs = 4.0;

  /// 8dp small spacing
  static const double sm = 8.0;

  /// 12dp medium-small spacing
  static const double md = 12.0;

  /// 16dp regular standard spacing
  static const double lg = 16.0;

  /// 24dp extra-large spacing
  static const double xl = 24.0;

  /// 32dp double extra-large spacing
  static const double xxl = 32.0;

  /// 48dp section spacing
  static const double xxxl = 48.0;
}

/// Semantic border radii conforming to Material 3 shape scale.
abstract final class AppRadius {
  /// 4dp radius - micro elements, small badges
  static const double xs = 4.0;

  /// 8dp radius - compact chips, small cards
  static const double sm = 8.0;

  /// 12dp radius - standard input fields, chips, small dialogs
  static const double md = 12.0;

  /// 16dp radius - standard cards, bottom sheets
  static const double lg = 16.0;

  /// 20dp radius - elevated cards, dialogs
  static const double xl = 20.0;

  /// 24dp radius - large surface sheets, hero containers
  static const double xxl = 24.0;

  /// 999dp pill / fully rounded
  static const double pill = 999.0;

  // Pre-built BorderRadius helpers
  static const BorderRadius roundedXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius roundedSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius roundedMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius roundedLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius roundedXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius roundedXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius roundedPill = BorderRadius.all(Radius.circular(pill));
}

/// Motion and duration tokens with reduced-motion awareness.
abstract final class AppMotion {
  /// Instant / 0 duration for reduced motion or instantaneous transitions
  static const Duration instant = Duration.zero;

  /// Short duration (150ms) - small fades, toggle micro-interactions
  static const Duration fast = Duration(milliseconds: 150);

  /// Medium duration (250ms) - standard cards, modal entrances
  static const Duration normal = Duration(milliseconds: 250);

  /// Long duration (400ms) - page transitions, large hero expansion
  static const Duration slow = Duration(milliseconds: 400);

  /// Standard curves conforming to Material 3 motion
  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve standard = Curves.easeInOut;
  static const Curve decelerate = Curves.easeOut;

  /// Returns the provided [baseDuration], or [Duration.zero] if the user has requested reduced motion.
  static Duration duration(BuildContext context, Duration baseDuration) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Duration.zero;
    }
    return baseDuration;
  }
}

/// Adaptive window size classes conforming to Material 3 breakpoint system.
enum WindowSizeClass {
  compact,
  medium,
  expanded,
  large,
}

abstract final class AppBreakpoints {
  /// < 600 dp (compact phones in portrait)
  static const double compactMax = 599.0;

  /// 600 - 839 dp (tablets portrait, foldables unfolded)
  static const double mediumMax = 839.0;

  /// 840 - 1199 dp (tablets landscape, small desktops)
  static const double expandedMax = 1199.0;

  /// Determines the WindowSizeClass from a given width
  static WindowSizeClass of(double width) {
    if (width <= compactMax) return WindowSizeClass.compact;
    if (width <= mediumMax) return WindowSizeClass.medium;
    if (width <= expandedMax) return WindowSizeClass.expanded;
    return WindowSizeClass.large;
  }

  /// Convenience helpers for width queries
  static bool isCompact(double width) => width <= compactMax;
  static bool isMedium(double width) => width > compactMax && width <= mediumMax;
  static bool isExpanded(double width) => width > mediumMax && width <= expandedMax;
  static bool isLarge(double width) => width > expandedMax;

  /// Context-aware helpers
  static WindowSizeClass windowOf(BuildContext context) => of(MediaQuery.sizeOf(context).width);
  static bool isCompactContext(BuildContext context) => isCompact(MediaQuery.sizeOf(context).width);
  static bool isMediumContext(BuildContext context) => isMedium(MediaQuery.sizeOf(context).width);
  static bool isExpandedContext(BuildContext context) => isExpanded(MediaQuery.sizeOf(context).width);
  static bool isLargeContext(BuildContext context) => isLarge(MediaQuery.sizeOf(context).width);
}
