import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sample linguistic script definitions for non-Latin typography stress tests (AQIL Frontier 3).
enum ScriptLanguage {
  devanagari(
    name: 'Devanagari (Hindi)',
    sampleText: 'नमस्ते! उपस्थिति और बायोमेट्रिक कार्यप्रणाली',
    isRtl: false,
    hasStackedDiacritics: true,
  ),
  arabic(
    name: 'Arabic',
    sampleText: 'تسجيل الحضور والانصراف اليومي للموظفين',
    isRtl: true,
    hasStackedDiacritics: true,
  ),
  cjk(
    name: 'CJK (Simplified Chinese)',
    sampleText: '企业考勤打卡与生物识别综合系统',
    isRtl: false,
    hasStackedDiacritics: false,
  ),
  thai(
    name: 'Thai',
    sampleText: 'ระบบลงเวลาการทำงานและบันทึกข้อมูลชีวมิติ',
    isRtl: false,
    hasStackedDiacritics: true,
  );

  final String name;
  final String sampleText;
  final bool isRtl;
  final bool hasStackedDiacritics;

  const ScriptLanguage({
    required this.name,
    required this.sampleText,
    required this.isRtl,
    required this.hasStackedDiacritics,
  });
}

/// Verification result of testing a component against complex non-Latin scripts.
class ScriptStressReport {
  final ScriptLanguage script;
  final bool passedWithoutOverflow;
  final bool hasVerticalClipping;
  final double measuredTextHeight;
  final String? exceptionMessage;

  const ScriptStressReport({
    required this.script,
    required this.passedWithoutOverflow,
    required this.hasVerticalClipping,
    required this.measuredTextHeight,
    this.exceptionMessage,
  });

  bool get isSuccessful => passedWithoutOverflow && !hasVerticalClipping && exceptionMessage == null;
}

/// Verification result of BiDi icon mirroring audit.
class BidiMirroringReport {
  final int directionalIconsScanned;
  final int properlyMirroredCount;
  final List<String> unmirroredDirectionalIcons;
  final bool isCompliant;

  const BidiMirroringReport({
    required this.directionalIconsScanned,
    required this.properlyMirroredCount,
    required this.unmirroredDirectionalIcons,
    required this.isCompliant,
  });
}

/// Complex Script & Non-Latin Typography Stress Engine (AQIL Frontier 3 / v7.0).
///
/// Verifies vertical line-height bounds, stacked diacritic rendering (Devanagari, Thai, Arabic),
/// CJK dense ideographic wrapping, and BiDi directional icon mirroring.
class AqilComplexScriptEngine {
  /// Directional icons that MUST mirror in RTL layouts according to Material Design 3 guidelines.
  static final Set<IconData> directionalIcons = {
    Icons.arrow_back,
    Icons.arrow_forward,
    Icons.arrow_back_ios,
    Icons.arrow_forward_ios,
    Icons.chevron_left,
    Icons.chevron_right,
    Icons.navigate_before,
    Icons.navigate_next,
    Icons.reply,
    Icons.forward,
  };

  /// Stress-tests a widget builder across non-Latin linguistic scripts (Devanagari, Arabic, CJK, Thai).
  static Future<Map<ScriptLanguage, ScriptStressReport>> auditScriptMatrix(
    WidgetTester tester, {
    required Widget Function(BuildContext context, String text, TextDirection direction) builder,
    List<ScriptLanguage> scripts = ScriptLanguage.values,
    Size viewport = const Size(393, 852),
  }) async {
    tester.view.physicalSize = viewport * 2.0;
    tester.view.devicePixelRatio = 2.0;

    final results = <ScriptLanguage, ScriptStressReport>{};

    for (final script in scripts) {
      final direction = script.isRtl ? TextDirection.rtl : TextDirection.ltr;
      String? exception;
      double measuredHeight = 0.0;
      bool hasVerticalClip = false;

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: Builder(
                  builder: (context) => builder(context, script.sampleText, direction),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final err = tester.takeException();
        if (err != null) {
          exception = err.toString();
        }

        // Measure rendered text heights and inspect for vertical clipping
        for (final element in find.byType(RichText).evaluate()) {
          final renderParagraph = element.renderObject as RenderParagraph;
          measuredHeight = math.max(measuredHeight, renderParagraph.size.height);

          // Check if paragraph exceeded bounds without ellipsis or has vertical bounds truncation
          if (renderParagraph.didExceedMaxLines && renderParagraph.overflow == TextOverflow.clip) {
            hasVerticalClip = true;
          }
        }
      } catch (e) {
        exception = e.toString();
      }

      results[script] = ScriptStressReport(
        script: script,
        passedWithoutOverflow: exception == null,
        hasVerticalClipping: hasVerticalClip,
        measuredTextHeight: measuredHeight,
        exceptionMessage: exception,
      );
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();

    return results;
  }

  /// Audits whether directional navigation icons (e.g. chevrons, back arrows) mirror
  /// in RTL text direction using `matchTextDirection: true` or directional icon constructors.
  static BidiMirroringReport auditBidiIconMirroring(
    WidgetTester tester, {
    required Finder targetFinder,
  }) {
    expect(targetFinder, findsAtLeastNWidgets(1));

    int directionalCount = 0;
    int mirroredCount = 0;
    final unmirrored = <String>[];

    for (final element in targetFinder.evaluate()) {
      if (element.widget is Icon) {
        final iconWidget = element.widget as Icon;
        if (directionalIcons.contains(iconWidget.icon)) {
          directionalCount++;
          if (iconWidget.icon?.matchTextDirection == true) {
            mirroredCount++;
          } else {
            unmirrored.add(iconWidget.icon?.toString() ?? 'Icon');
          }
        }
      }
    }

    final isCompliant = unmirrored.isEmpty;
    return BidiMirroringReport(
      directionalIconsScanned: directionalCount,
      properlyMirroredCount: mirroredCount,
      unmirroredDirectionalIcons: unmirrored,
      isCompliant: isCompliant,
    );
  }
}
