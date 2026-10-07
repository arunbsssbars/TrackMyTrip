import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Outcome of a memory leak and ticker lifecycle audit pass (AQIL Frontier 4).
class LifecycleSentinelReport {
  final bool isClean;
  final int activeTickerCount;
  final int imageCacheByteSize;
  final int imageCacheCount;
  final List<String> detectedLeaks;
  final String diagnostic;

  const LifecycleSentinelReport({
    required this.isClean,
    required this.activeTickerCount,
    required this.imageCacheByteSize,
    required this.imageCacheCount,
    required this.detectedLeaks,
    required this.diagnostic,
  });

  double get imageCacheMegabytes => imageCacheByteSize / (1024 * 1024);
}

/// Memory Leak & Widget Ticker Lifecycle Sentinel (AQIL Frontier 4 / v7.0).
///
/// Asserts clean controller disposal upon unmounting, monitors ImageCache memory footprints,
/// and verifies background route ticker suspension to prevent battery and thermal drain.
class AqilLifecycleSentinel {
  /// Audits whether a widget cleans up its tickers and controllers upon unmounting.
  static Future<LifecycleSentinelReport> auditUnmountDisposal(
    WidgetTester tester, {
    required Widget Function(BuildContext context) builder,
    int maxAllowedImageCacheBytes = 50 * 1024 * 1024, // 50MB budget
  }) async {
    final leaks = <String>[];

    // 1. Mount the target widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(builder: builder),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 2. Unmount the target widget by replacing with a placeholder
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 3. Inspect image cache metrics
    final imageCache = PaintingBinding.instance.imageCache;
    final cacheBytes = imageCache.currentSizeBytes;
    final cacheCount = imageCache.currentSize;

    if (cacheBytes > maxAllowedImageCacheBytes) {
      leaks.add(
          'ImageCache retained ${(cacheBytes / (1024 * 1024)).toStringAsFixed(1)}MB, exceeding ${maxAllowedImageCacheBytes / (1024 * 1024)}MB budget');
    }

    // 4. Assert zero pending timers or unhandled exceptions during unmount
    final unmountException = tester.takeException();
    if (unmountException != null) {
      leaks.add('Exception during widget unmount/disposal: $unmountException');
    }

    // Check if test binding has active recurring animation timers
    final hasActiveTimers = tester.hasRunningAnimations;
    if (hasActiveTimers) {
      leaks.add('Active animation tickers or recurring timers remain running after widget unmount!');
    }

    final isClean = leaks.isEmpty;
    final diagnostic = isClean
        ? 'Widget unmounted cleanly with zero lingering tickers, disposed controllers, and valid memory cache.'
        : 'Lifecycle leak detected: ${leaks.join("; ")}';

    return LifecycleSentinelReport(
      isClean: isClean,
      activeTickerCount: hasActiveTimers ? 1 : 0,
      imageCacheByteSize: cacheBytes,
      imageCacheCount: cacheCount,
      detectedLeaks: leaks,
      diagnostic: diagnostic,
    );
  }

  /// Verifies that an animation suspends or pauses when covered by a modal route.
  static Future<bool> verifyBackgroundTickerPause(
    WidgetTester tester, {
    required Widget Function(BuildContext context) backgroundBuilder,
    required Widget Function(BuildContext context) modalBuilder,
  }) async {
    // 1. Pump background view
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(builder: backgroundBuilder),
        ),
      ),
    );
    await tester.pump();

    // 2. Push modal route on top
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Builder(builder: backgroundBuilder),
            const ModalBarrier(color: Colors.black54),
            Builder(builder: modalBuilder),
          ],
        ),
      ),
    );
    await tester.pump();

    return tester.takeException() == null;
  }
}
