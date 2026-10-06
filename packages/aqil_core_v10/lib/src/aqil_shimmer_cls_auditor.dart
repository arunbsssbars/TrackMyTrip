import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Report emitted by [AqilShimmerClsAuditor.auditShimmerParity].
class ShimmerClsReport {
  final Size skeletonSize;
  final Size loadedContentSize;
  final double cumulativeLayoutShift;
  final bool isClsZero;
  final List<String> clsDiscrepancies;

  const ShimmerClsReport({
    required this.skeletonSize,
    required this.loadedContentSize,
    required this.cumulativeLayoutShift,
    required this.isClsZero,
    required this.clsDiscrepancies,
  });

  bool get isBigTechCompliant => isClsZero && cumulativeLayoutShift <= 0.02;
}

/// AQIL v11 Frontier 5: Zero-CLS Skeleton Shimmer & Content Parity Auditor
///
/// Ensures zero Cumulative Layout Shift (CLS <= 0.02) during shimmer skeleton
/// to real data transitions, matching Google Search and YouTube web standards.
abstract final class AqilShimmerClsAuditor {
  /// Measures Cumulative Layout Shift between shimmer skeleton and loaded widget.
  static Future<ShimmerClsReport> auditShimmerParity(
    WidgetTester tester, {
    required Widget skeletonWidget,
    required Widget loadedWidget,
    Finder? targetFinder,
  }) async {
    final discrepancies = <String>[];

    // 1. Render Skeleton
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: skeletonWidget)));
    await tester.pump();
    final skeletonBox = tester.renderObject(targetFinder ?? find.byType(skeletonWidget.runtimeType).first) as RenderBox;
    final skeletonSize = skeletonBox.size;

    // 2. Render Loaded Content
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: loadedWidget)));
    await tester.pumpAndSettle();
    final loadedBox = tester.renderObject(targetFinder ?? find.byType(loadedWidget.runtimeType).first) as RenderBox;
    final loadedSize = loadedBox.size;

    // Calculate layout shift delta
    final deltaHeight = (loadedSize.height - skeletonSize.height).abs();
    final deltaWidth = (loadedSize.width - skeletonSize.width).abs();

    final maxDim = skeletonSize.height > 0 ? skeletonSize.height : 100.0;
    final clsScore = (deltaHeight + deltaWidth) / maxDim;

    if (deltaHeight > 4.0) {
      discrepancies.add(
        'Height jump of ${deltaHeight.toStringAsFixed(1)}px detected between skeleton and loaded content',
      );
    }
    if (deltaWidth > 4.0) {
      discrepancies.add(
        'Width jump of ${deltaWidth.toStringAsFixed(1)}px detected between skeleton and loaded content',
      );
    }

    final isZero = deltaHeight <= 4.0 && deltaWidth <= 4.0;

    return ShimmerClsReport(
      skeletonSize: skeletonSize,
      loadedContentSize: loadedSize,
      cumulativeLayoutShift: clsScore,
      isClsZero: isZero,
      clsDiscrepancies: discrepancies,
    );
  }
}
