import 'package:flutter/material.dart';
import 'app_status_colors.dart';
import 'app_tokens.dart';

export 'app_status_colors.dart';
export 'app_tokens.dart';
export 'components/app_shimmer_skeleton.dart';
export 'components/app_empty_state.dart';
export 'components/app_error_retry.dart';
export 'components/app_error_boundary.dart';
export 'components/app_resilient_text.dart';

/// Ergonomic BuildContext extensions for accessing design tokens and theme.
extension DesignSystemContextX on BuildContext {
  /// Theme convenience
  ThemeData get theme => Theme.of(this);

  /// ColorScheme convenience
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// TextTheme convenience
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Semantic status colors (falls back to light mode if not configured)
  AppStatusColors get statusColors =>
      Theme.of(this).extension<AppStatusColors>() ?? AppStatusColors.light;

  /// Window size class
  WindowSizeClass get windowSizeClass => AppBreakpoints.windowOf(this);

  /// Breakpoint checks
  bool get isCompact => AppBreakpoints.isCompactContext(this);
  bool get isMedium => AppBreakpoints.isMediumContext(this);
  bool get isExpanded => AppBreakpoints.isExpandedContext(this);
  bool get isLarge => AppBreakpoints.isLargeContext(this);
}
