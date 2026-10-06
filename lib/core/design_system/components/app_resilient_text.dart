import 'package:flutter/material.dart';

/// AQIL Resilient: Dynamic typography & font scaling guard.
///
/// Ensures text renders safely across aggressive accessibility font scaling
/// (1.3x, 1.5x, 2.0x) without causing RenderFlex overflows or accidental clipping.
class AppResilientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow overflow;
  final int? maxLines;
  final double minScaleFactor;
  final double maxScaleFactor;
  final String? semanticsLabel;

  const AppResilientText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow = TextOverflow.ellipsis,
    this.maxLines = 1,
    this.minScaleFactor = 0.85,
    this.maxScaleFactor = 1.45,
    this.semanticsLabel,
  });

  /// Factory for badge/pill text requiring tighter scaling bounds to prevent layout explosions.
  const AppResilientText.badge(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
    this.overflow = TextOverflow.ellipsis,
    this.maxLines = 1,
    this.minScaleFactor = 0.85,
    this.maxScaleFactor = 1.25,
    this.semanticsLabel,
  });

  /// Factory for multi-line readable paragraphs allowing higher accessibility scaling up to 2.0x.
  const AppResilientText.body(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow = TextOverflow.ellipsis,
    this.maxLines,
    this.minScaleFactor = 0.85,
    this.maxScaleFactor = 2.0,
    this.semanticsLabel,
  });

  /// Utility to join multi-part metadata defensibly using a single text delimiter (' • ').
  static String joinMetadata(List<String?> parts, {String delimiter = ' • '}) {
    return parts
        .where((p) => p != null && p.trim().isNotEmpty)
        .map((p) => p!.trim())
        .join(delimiter);
  }

  @override
  Widget build(BuildContext context) {
    final currentScaler = MediaQuery.textScalerOf(context);
    final clampedScaler = currentScaler.clamp(
      minScaleFactor: minScaleFactor,
      maxScaleFactor: maxScaleFactor,
    );

    return Text(
      text,
      style: style,
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
      textScaler: clampedScaler,
      semanticsLabel: semanticsLabel,
    );
  }
}
