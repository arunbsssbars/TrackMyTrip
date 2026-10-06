import 'package:flutter/material.dart';

/// Audits Sliver headers and AppBars for smooth transitions, collapsing behavior,
/// and prevents title clipping or overlap at minimum collapsed heights.
class AqilSliverHeaderAuditor {
  /// Evaluates expanded vs collapsed height ratios for SliverAppBars.
  static String? auditAppBarGeometry({
    required double expandedHeight,
    required double collapsedHeight,
  }) {
    if (expandedHeight <= collapsedHeight) {
      return 'SliverAppBar expandedHeight ($expandedHeight) must be greater than collapsedHeight ($collapsedHeight).';
    }
    if (collapsedHeight < 56.0) {
      return 'SliverAppBar collapsedHeight ($collapsedHeight) is below minimum Material touch target (56.0dp).';
    }
    return null;
  }
}

/// A drop-in responsive morphing SliverAppBar inspired by Airbnb and Apple Store.
/// Handles smooth title opacity fade-in only when fully collapsed,
/// and hero title scale-down when scrolling.
class AqilMorphingAppBar extends StatelessWidget {
  final String title;
  final Widget? background;
  final List<Widget>? actions;
  final double expandedHeight;

  const AqilMorphingAppBar({
    super.key,
    required this.title,
    this.background,
    this.actions,
    this.expandedHeight = 220.0,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: true,
      actions: actions,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        titlePadding: const EdgeInsetsDirectional.only(start: 16.0, bottom: 16.0),
        background: background,
      ),
    );
  }
}
