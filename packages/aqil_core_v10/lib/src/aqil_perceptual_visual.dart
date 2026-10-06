import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Defines a dynamic or volatile exclusion zone in visual regression testing (AQIL Frontier 2).
class VisualMaskRegion {
  final Rect rect;
  final String label;
  final bool isDynamic;

  const VisualMaskRegion({
    required this.rect,
    this.label = 'Dynamic Region',
    this.isDynamic = true,
  });

  @override
  String toString() => 'VisualMaskRegion[$label: ${rect.left},${rect.top} - ${rect.width}x${rect.height}]';
}

/// A 2D raster frame representing rendered UI pixels (ARGB integers).
class PixelFrame {
  final int width;
  final int height;
  final List<int> pixels; // 0xAARRGGBB

  PixelFrame({
    required this.width,
    required this.height,
    List<int>? pixels,
  }) : pixels = pixels ?? List<int>.filled(width * height, 0xFFFFFFFF);

  factory PixelFrame.filled({
    required int width,
    required int height,
    int color = 0xFFFFFFFF,
  }) {
    return PixelFrame(
      width: width,
      height: height,
      pixels: List<int>.filled(width * height, color),
    );
  }

  int getPixel(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return 0x00000000;
    return pixels[y * width + x];
  }

  void setPixel(int x, int y, int argb) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
      pixels[y * width + x] = argb;
    }
  }

  /// Fills a rectangular region on this frame with a solid color.
  void fillRect(Rect rect, int argb) {
    final left = rect.left.clamp(0, width).toInt();
    final top = rect.top.clamp(0, height).toInt();
    final right = rect.right.clamp(0, width).toInt();
    final bottom = rect.bottom.clamp(0, height).toInt();

    for (int y = top; y < bottom; y++) {
      for (int x = left; x < right; x++) {
        setPixel(x, y, argb);
      }
    }
  }

  /// Applies visual masks by overwriting masked pixels with a neutral mask color.
  void applyMasks(List<VisualMaskRegion> masks, {int maskColor = 0xFF808080}) {
    for (final mask in masks) {
      fillRect(mask.rect, maskColor);
    }
  }
}

/// Outcome of a pixel-level perceptual visual comparison with dynamic masking.
class PerceptualDiffResult {
  final int width;
  final int height;
  final int totalPixels;
  final int maskedPixels;
  final int differingPixels;
  final double diffRatio; // differingPixels / (totalPixels - maskedPixels)
  final double toleranceThreshold;
  final bool isMatch;
  final double maxColorDelta;
  final List<Rect> discrepancyBoundingBoxes;
  final List<VisualMaskRegion> appliedMasks;

  const PerceptualDiffResult({
    required this.width,
    required this.height,
    required this.totalPixels,
    required this.maskedPixels,
    required this.differingPixels,
    required this.diffRatio,
    required this.toleranceThreshold,
    required this.isMatch,
    required this.maxColorDelta,
    required this.discrepancyBoundingBoxes,
    required this.appliedMasks,
  });

  /// Generates a terminal-friendly ASCII heatmap visualization of visual diffs.
  String renderAsciiDiffHeatmap({int cols = 20, int rows = 10}) {
    final buffer = StringBuffer();
    buffer.writeln('=== AQIL Perceptual Visual Diff Heatmap (${width}x$height) ===');
    buffer.writeln('Evaluated: $totalPixels px | Masked: $maskedPixels px | Diff: $differingPixels px (${(diffRatio * 100).toStringAsFixed(2)}%)');
    buffer.writeln('Tolerance: ${(toleranceThreshold * 100).toStringAsFixed(2)}% | Status: ${isMatch ? "MATCH (PASS)" : "MISMATCH (FAIL)"}');
    buffer.writeln('Legend: [.] Match  [*] Diff  [M] Masked\n');

    final cellW = width / cols;
    final cellH = height / rows;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cellRect = Rect.fromLTWH(c * cellW, r * cellH, cellW, cellH);
        
        // Check if inside any mask
        final isMasked = appliedMasks.any((m) => m.rect.overlaps(cellRect));
        if (isMasked) {
          buffer.write('M ');
          continue;
        }

        // Check if inside any discrepancy cluster
        final hasDiff = discrepancyBoundingBoxes.any((box) => box.overlaps(cellRect));
        buffer.write(hasDiff ? '* ' : '. ');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
}

/// Pixel-Level Perceptual Visual Regression with Dynamic Masking Engine (AQIL Frontier 2).
class AqilPerceptualVisualEngine {
  /// Computes perceptual distance between two 32-bit ARGB colors (normalized to 0.0 - 1.0).
  static double colorDistance(int c1, int c2) {
    if (c1 == c2) return 0.0;

    final r1 = (c1 >> 16) & 0xFF;
    final g1 = (c1 >> 8) & 0xFF;
    final b1 = c1 & 0xFF;

    final r2 = (c2 >> 16) & 0xFF;
    final g2 = (c2 >> 8) & 0xFF;
    final b2 = c2 & 0xFF;

    final dr = (r1 - r2).toDouble();
    final dg = (g1 - g2).toDouble();
    final db = (b1 - b2).toDouble();

    // Euclidean distance normalized against max possible distance (sqrt(255^2 * 3) ≈ 441.67)
    return math.sqrt(dr * dr + dg * dg + db * db) / 441.6729559300637;
  }

  /// Compares two [PixelFrame] instances with perceptual color distance and dynamic masking.
  static PerceptualDiffResult compareFrames(
    PixelFrame baseline,
    PixelFrame current, {
    List<VisualMaskRegion> masks = const [],
    double toleranceThreshold = 0.01, // 1% threshold
    double perceptualColorThreshold = 0.05, // 5% color distance allows anti-aliasing jitter
  }) {
    assert(baseline.width == current.width && baseline.height == current.height,
        'Frames must have identical dimensions for visual comparison');

    final width = baseline.width;
    final height = baseline.height;
    final totalPixels = width * height;

    int maskedCount = 0;
    int differingCount = 0;
    double maxDistance = 0.0;
    final diffCoordinates = <math.Point<int>>[];

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pt = Offset(x.toDouble(), y.toDouble());
        final isMasked = masks.any((m) => m.rect.contains(pt));

        if (isMasked) {
          maskedCount++;
          continue;
        }

        final p1 = baseline.getPixel(x, y);
        final p2 = current.getPixel(x, y);

        final dist = colorDistance(p1, p2);
        if (dist > maxDistance) {
          maxDistance = dist;
        }

        if (dist > perceptualColorThreshold) {
          differingCount++;
          diffCoordinates.add(math.Point(x, y));
        }
      }
    }

    final effectivePixels = math.max(1, totalPixels - maskedCount);
    final diffRatio = differingCount / effectivePixels;
    final isMatch = diffRatio <= toleranceThreshold;

    // Cluster diff coordinates into bounding boxes
    final boundingBoxes = _clusterDiscrepancies(diffCoordinates);

    return PerceptualDiffResult(
      width: width,
      height: height,
      totalPixels: totalPixels,
      maskedPixels: maskedCount,
      differingPixels: differingCount,
      diffRatio: diffRatio,
      toleranceThreshold: toleranceThreshold,
      isMatch: isMatch,
      maxColorDelta: maxDistance,
      discrepancyBoundingBoxes: boundingBoxes,
      appliedMasks: masks,
    );
  }

  /// Groups disparate pixel coordinates into a consolidated list of bounding boxes.
  static List<Rect> _clusterDiscrepancies(List<math.Point<int>> points) {
    if (points.isEmpty) return const [];

    int minX = points.first.x;
    int maxX = points.first.x;
    int minY = points.first.y;
    int maxY = points.first.y;

    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    return [
      Rect.fromLTRB(
        minX.toDouble(),
        minY.toDouble(),
        (maxX + 1).toDouble(),
        (maxY + 1).toDouble(),
      ),
    ];
  }

  /// Automatically locates dynamic widgets in the tree (via finders or volatile text patterns)
  /// and synthesizes their screen-space [VisualMaskRegion] bounding boxes.
  static List<VisualMaskRegion> extractMaskRegionsFromTree(
    WidgetTester tester, {
    List<Finder> maskFinders = const [],
    List<String> volatilePatterns = const [],
  }) {
    final maskRegions = <VisualMaskRegion>[];

    // 1. Process explicit finders
    for (final finder in maskFinders) {
      for (final element in finder.evaluate()) {
        final renderBox = element.renderObject;
        if (renderBox is RenderBox && renderBox.hasSize) {
          final origin = renderBox.localToGlobal(Offset.zero);
          final rect = origin & renderBox.size;
          maskRegions.add(VisualMaskRegion(
            rect: rect,
            label: 'Finder Mask: ${element.widget.runtimeType}',
          ));
        }
      }
    }

    // 2. Discover volatile text patterns (e.g. timestamps, IDs, live counters)
    if (volatilePatterns.isNotEmpty) {
      for (final pattern in volatilePatterns) {
        final textFinder = find.byWidgetPredicate((widget) {
          if (widget is Text && widget.data != null) {
            return widget.data!.contains(pattern);
          }
          return false;
        });

        for (final element in textFinder.evaluate()) {
          final renderBox = element.renderObject;
          if (renderBox is RenderBox && renderBox.hasSize) {
            final origin = renderBox.localToGlobal(Offset.zero);
            maskRegions.add(VisualMaskRegion(
              rect: origin & renderBox.size,
              label: 'Volatile Text Mask: $pattern',
            ));
          }
        }
      }
    }

    return maskRegions;
  }
}
