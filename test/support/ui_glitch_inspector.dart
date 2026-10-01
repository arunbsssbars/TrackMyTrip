// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Device configuration presets for exhaustive UI glitch testing.
class DevicePreset {
  final String name;
  final Size logicalSize;
  final double pixelRatio;

  const DevicePreset({
    required this.name,
    required this.logicalSize,
    this.pixelRatio = 2.0,
  });

  /// Ultra-compact 4-inch phone (e.g., iPhone SE 1st gen, small Android)
  static const compact = DevicePreset(
    name: 'Compact (320x568)',
    logicalSize: Size(320, 568),
    pixelRatio: 2.0,
  );

  /// Standard modern smartphone (e.g., iPhone 13/14/15, Pixel 6/7)
  static const standard = DevicePreset(
    name: 'Standard (390x844)',
    logicalSize: Size(390, 844),
    pixelRatio: 3.0,
  );

  /// Tall modern Android device (e.g., Samsung Galaxy S23/S24, Pixel 8 Pro)
  static const tallAndroid = DevicePreset(
    name: 'Tall Android (412x915)',
    logicalSize: Size(412, 915),
    pixelRatio: 2.625,
  );

  /// Tablet / Foldable open screen (e.g., iPad Mini, Galaxy Fold inner)
  static const tablet = DevicePreset(
    name: 'Tablet (768x1024)',
    logicalSize: Size(768, 1024),
    pixelRatio: 2.0,
  );

  static const all = [compact, standard, tallAndroid, tablet];
}

/// Deep inspection engine for detecting visual flaws in Flutter widget trees.
class UiGlitchInspector {
  /// Asserts that no RenderFlex overflows or layout errors were caught during execution.
  static void assertNoOverflows(WidgetTester tester) {
    final exception = tester.takeException();
    if (exception != null) {
      fail('UI Glitch Detected: Layout exception was thrown:\n$exception');
    }
  }

  /// Traverses the render tree to ensure no text has been clipped without an intentional ellipsis,
  /// and that no RenderParagraph is experiencing layout overflow.
  static void assertNoUnintendedTruncation(WidgetTester tester) {
    assertNoOverflows(tester);

    final paragraphs = <RenderParagraph>[];
    void collectParagraphs(RenderObject object) {
      if (object is RenderOffstage && object.offstage) {
        return;
      }
      if (object is RenderIndexedStack) {
        final activeIndex = object.index;
        if (activeIndex != null) {
          int i = 0;
          RenderBox? child = object.firstChild;
          while (child != null) {
            if (i == activeIndex) {
              collectParagraphs(child);
            }
            child = object.childAfter(child);
            i++;
          }
        }
        return;
      }
      if (object is RenderParagraph) {
        paragraphs.add(object);
      }
      object.visitChildren(collectParagraphs);
    }

    final rootRenderObject = tester.binding.rootElement?.renderObject;
    if (rootRenderObject != null) {
      collectParagraphs(rootRenderObject);
    }

    for (final paragraph in paragraphs) {
      // Check if text exceeds maxLines without a configured ellipsis/fade overflow
      if (paragraph.didExceedMaxLines) {
        final overflowMode = paragraph.overflow;
        if (overflowMode != TextOverflow.ellipsis && overflowMode != TextOverflow.fade) {
          final text = paragraph.text.toPlainText();
          fail('UI Glitch Detected: Text was silently truncated without ellipsis: "$text"');
        }
      }

      // Check if paragraph width or height is zero when containing non-empty text
      if (paragraph.hasSize && paragraph.text.toPlainText().trim().isNotEmpty) {
        if (paragraph.size.width <= 0 || paragraph.size.height <= 0) {
          final text = paragraph.text.toPlainText();
          fail('UI Glitch Detected: RenderParagraph collapsed to zero size for non-empty text: "$text"');
        }
      }
    }
  }

  /// Configures test environment viewport and pumps the test widget with complete theme and media query wrappers.
  static Future<void> pumpSurface(
    WidgetTester tester, {
    required Widget child,
    DevicePreset device = DevicePreset.standard,
    double fontScale = 1.0,
    bool isDark = false,
  }) async {
    tester.view.physicalSize = Size(
      device.logicalSize.width * device.pixelRatio,
      device.logicalSize.height * device.pixelRatio,
    );
    tester.view.devicePixelRatio = device.pixelRatio;

    final theme = isDark
        ? ThemeData.dark(useMaterial3: true).copyWith(
            scaffoldBackgroundColor: const Color(0xFF0F172A),
          )
        : ThemeData.light(useMaterial3: true).copyWith(
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          );

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: device.logicalSize,
          devicePixelRatio: device.pixelRatio,
          textScaler: TextScaler.linear(fontScale),
          padding: const EdgeInsets.only(top: 44, bottom: 34),
          viewInsets: EdgeInsets.zero,
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: child,
        ),
      ),
    );

    // Initial pump
    await tester.pump();
    // Allow any layout micro-animations/transitions up to 500ms
    await tester.pump(const Duration(milliseconds: 500));
  }
}
