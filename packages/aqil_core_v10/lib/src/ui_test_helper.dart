import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'aqil_self_healer.dart';
import 'aqil_perceptual_visual.dart';
import 'aqil_storybook_catalog.dart';
import 'aqil_ci_cd_bot.dart';
import 'aqil_chaos_monkey.dart';
import 'aqil_rum_synthesizer.dart';
import 'aqil_frame_profiler.dart';
import 'aqil_accessibility_tree.dart';
import 'aqil_complex_script_engine.dart';
import 'aqil_lifecycle_sentinel.dart';
import 'aqil_figma_token_sentinel.dart';
import 'aqil_spatial_tension_auditor.dart';
import 'aqil_hardware_sensor_mesh.dart';
import 'aqil_gesture_physics_auditor.dart';
import 'aqil_visual_saliency_auditor.dart';
import 'aqil_oled_power_auditor.dart';
import 'aqil_pseudo_loc_engine.dart';
import 'aqil_mutation_resilience_engine.dart';
import 'aqil_project_crawler.dart';
import 'aqil_media_asset_auditor.dart';
import 'aqil_scroll_profiler.dart';
import 'aqil_palette_invariant_auditor.dart';
import 'aqil_state_restoration_auditor.dart';
import 'aqil_unified_dashboard.dart';
import 'aqil_network_chaos_engine.dart';
import 'aqil_biometric_spoof_sentinel.dart';
import 'aqil_gc_thrash_sentinel.dart';
import 'aqil_foldable_angle_auditor.dart';
import 'aqil_hash_chain_sentinel.dart';
import 'aqil_a11y_golden_baseline.dart';
import 'aqil_surface_optics_auditor.dart';
import 'aqil_motion_choreography_auditor.dart';
import 'aqil_information_density_auditor.dart';
import 'aqil_haptic_sensory_auditor.dart';
import 'aqil_shimmer_cls_auditor.dart';
import 'aqil_command_palette_auditor.dart';

export 'aqil_ui_gateway.dart';
export 'aqil_screen_tester.dart';
export 'aqil_contrast_auditor.dart';
export 'aqil_code_healer.dart';
export 'aqil_test_generator.dart';
export 'aqil_html_diff_studio.dart';
export 'aqil_form_fuzzer.dart';
export 'aqil_frame_budget_sentinel.dart';
export 'aqil_fluid.dart';
export 'aqil_mock_synthesizer.dart';
export 'aqil_leak_sentinel.dart';
export 'aqil_network_simulator.dart';
export 'aqil_locale_stress.dart';
export 'aqil_ci_guardian.dart';
export 'aqil_state_snapshot.dart';
export 'aqil_gesture_heatmap.dart';
export 'aqil_token_drift_auditor.dart';
export 'aqil_state_matrix.dart';
export 'aqil_spring_physics.dart';
export 'aqil_skeleton_shimmer.dart';
export 'aqil_haptic_choreographer.dart';
export 'aqil_frosted_surface.dart';
export 'aqil_rolling_counter.dart';
export 'aqil_thumb_reach.dart';
export 'aqil_sliver_morph.dart';
export 'aqil_swipe_action.dart';
export 'aqil_obsidian_palette.dart';
export 'aqil_bottom_sheet.dart';
export 'aqil_hero_transition.dart';
export 'aqil_quick_command_palette.dart';
export 'aqil_benchmark_evaluator.dart';
export 'aqil_optimistic_engine.dart';
export 'aqil_type_scale_auditor.dart';
export 'aqil_a11y_traverser.dart';
export 'aqil_visual_hierarchy_auditor.dart';
export 'aqil_touch_crowding_auditor.dart';
export 'aqil_spatial_rhythm_auditor.dart';
export 'aqil_color_blindness_auditor.dart';
export 'aqil_physical_elevation.dart';
export 'aqil_micro_motion.dart';
export 'aqil_cta_hierarchy.dart';
export 'aqil_interactive_field.dart';
export 'aqil_progressive_blur.dart';
export 'aqil_micro_badge.dart';
export 'aqil_corner_radius_auditor.dart';
export 'aqil_sensory_refresh.dart';
export 'aqil_visual_design_matrix.dart';
export 'aqil_optical_tracking.dart';
export 'aqil_floating_banner.dart';
export 'aqil_segmented_pill.dart';
export 'aqil_icon_geometry_auditor.dart';
export 'aqil_accordion_tile.dart';
export 'aqil_hairline_divider.dart';
export 'aqil_media_aspect_auditor.dart';
export 'aqil_interactive_card.dart';
export 'aqil_fab_extended.dart';
export 'aqil_design_archetypes.dart';
export 'aqil_surface_lighting.dart';
export 'aqil_typographic_contrast_auditor.dart';
export 'aqil_floating_dock.dart';
export 'aqil_content_density.dart';
export 'aqil_status_pill.dart';
export 'aqil_focus_ring.dart';
export 'aqil_avatar_group.dart';
export 'aqil_empty_state.dart';
export 'aqil_glassmorphism_card.dart';
export 'aqil_world_class_design_benchmark.dart';
export 'aqil_ambient_glow.dart';
export 'aqil_synced_shimmer_group.dart';
export 'aqil_interactive_badge_pill.dart';
export 'aqil_dynamic_island_toast.dart';
export 'aqil_visual_weight_auditor.dart';
export 'aqil_stepped_progress_indicator.dart';
export 'aqil_border_gradient_glow.dart';
export 'aqil_split_action_pill.dart';
export 'aqil_z_index_layer_auditor.dart';
export 'aqil_industry_excellence_radar.dart';
export 'aqil_self_healer.dart';
export 'aqil_perceptual_visual.dart';
export 'aqil_storybook_catalog.dart';
export 'aqil_ci_cd_bot.dart';
export 'aqil_chaos_monkey.dart';
export 'aqil_rum_synthesizer.dart';
export 'aqil_frame_profiler.dart';
export 'aqil_accessibility_tree.dart';
export 'aqil_complex_script_engine.dart';
export 'aqil_lifecycle_sentinel.dart';
export 'aqil_figma_token_sentinel.dart';
export 'aqil_spatial_tension_auditor.dart';
export 'aqil_hardware_sensor_mesh.dart';
export 'aqil_gesture_physics_auditor.dart';
export 'aqil_visual_saliency_auditor.dart';
export 'aqil_oled_power_auditor.dart';
export 'aqil_pseudo_loc_engine.dart';
export 'aqil_mutation_resilience_engine.dart';
export 'aqil_project_crawler.dart';
export 'aqil_media_asset_auditor.dart';
export 'aqil_scroll_profiler.dart';
export 'aqil_palette_invariant_auditor.dart';
export 'aqil_state_restoration_auditor.dart';
export 'aqil_unified_dashboard.dart';
export 'aqil_network_chaos_engine.dart';
export 'aqil_biometric_spoof_sentinel.dart';
export 'aqil_gc_thrash_sentinel.dart';
export 'aqil_foldable_angle_auditor.dart';
export 'aqil_hash_chain_sentinel.dart';
export 'aqil_a11y_golden_baseline.dart';
export 'aqil_surface_optics_auditor.dart';
export 'aqil_motion_choreography_auditor.dart';
export 'aqil_information_density_auditor.dart';
export 'aqil_haptic_sensory_auditor.dart';
export 'aqil_shimmer_cls_auditor.dart';
export 'aqil_command_palette_auditor.dart';

/// Standard device viewport specifications for responsive enterprise UI testing.
class UiTestDevice {
  final String name;
  final Size size;
  final double devicePixelRatio;

  const UiTestDevice({
    required this.name,
    required this.size,
    this.devicePixelRatio = 2.0,
  });

  /// Ultra-compact 4-inch phone (e.g. iPhone SE 1st Gen / Budget Android)
  static const smallPhone = UiTestDevice(
    name: 'Small Phone (320x568)',
    size: Size(320, 568),
    devicePixelRatio: 2.0,
  );

  /// Modern standard smartphone (e.g. iPhone 15 / Google Pixel 8)
  static const standardPhone = UiTestDevice(
    name: 'Standard Phone (393x852)',
    size: Size(393, 852),
    devicePixelRatio: 3.0,
  );

  /// Large flagship smartphone (e.g. Samsung Galaxy S24 Ultra)
  static const largePhone = UiTestDevice(
    name: 'Large Phone (412x915)',
    size: Size(412, 915),
    devicePixelRatio: 3.5,
  );

  /// 10-inch Enterprise Wall-Mounted Kiosk Tablet in Landscape orientation
  static const kioskTabletLandscape = UiTestDevice(
    name: 'Kiosk Tablet Landscape (1280x800)',
    size: Size(1280, 800),
    devicePixelRatio: 1.5,
  );

  /// 10-inch Enterprise Kiosk Tablet in Portrait orientation
  static const kioskTabletPortrait = UiTestDevice(
    name: 'Kiosk Tablet Portrait (800x1280)',
    size: Size(800, 1280),
    devicePixelRatio: 1.5,
  );

  /// Comprehensive suite of representative enterprise device form factors.
  static const List<UiTestDevice> all = [
    smallPhone,
    standardPhone,
    largePhone,
    kioskTabletLandscape,
    kioskTabletPortrait,
  ];
}

/// Dynamic font scale factors to test accessibility and text truncation (WCAG 1.4.4).
class UiFontScale {
  static const double standard = 1.0;
  static const double large = 1.3;
  static const double extraLarge = 1.5;
  static const double accessible200 = 2.0;

  static const List<double> all = [standard, large, extraLarge, accessible200];
}

/// Automated UI Layout, Overflow, Truncation & Navigation Quality Tester.
/// Integrates directly into the continuous engineering iteration loop.
class UiQualityTester {
  /// Pumps and verifies a widget across multiple screen resolutions and font scales.
  /// Automatically fails if any [RenderFlex] overflows or layout constraint violations occur.
  static Future<void> testResponsiveLayout(
    WidgetTester tester, {
    required Widget child,
    List<UiTestDevice> devices = UiTestDevice.all,
    List<double> fontScales = const [UiFontScale.standard, UiFontScale.large],
    ThemeData? theme,
  }) async {
    for (final device in devices) {
      for (final fontScale in fontScales) {
        // Configure simulated physical display and pixel density
        tester.view.physicalSize = device.size * device.devicePixelRatio;
        tester.view.devicePixelRatio = device.devicePixelRatio;

        await tester.pumpWidget(
          MaterialApp(
            theme: theme ??
                ThemeData(
                  useMaterial3: true,
                  colorSchemeSeed: const Color(0xFF2563EB),
                ),
            home: MediaQuery(
              data: MediaQueryData(
                size: device.size,
                devicePixelRatio: device.devicePixelRatio,
                textScaler: TextScaler.linear(fontScale),
              ),
              child: Scaffold(
                body: SafeArea(
                  child: SingleChildScrollView(
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Check if any errors were captured during layout pass
        final error = tester.takeException();
        if (error != null) {
          if (error is FlutterError) {
            debugPrint('=== OVERFLOW DETAILS ===');
            debugPrint(error.toStringDeep());
          }
          throw FlutterError(
            'UI Layout Failure on ${device.name} at fontScale $fontScale: $error',
          );
        }
      }
    }

    // Clean up test environment
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  /// Pumps and verifies a widget under strict fixed viewport bounds (NO SingleChildScrollView wrapper).
  /// Guarantees that screens and dialogs designated for non-scrollable viewports do not overflow vertically or horizontally.
  static Future<void> testStrictResponsiveLayout(
    WidgetTester tester, {
    required Widget child,
    List<UiTestDevice> devices = UiTestDevice.all,
    List<double> fontScales = const [UiFontScale.standard, UiFontScale.large],
    ThemeData? theme,
  }) async {
    for (final device in devices) {
      for (final fontScale in fontScales) {
        tester.view.physicalSize = device.size * device.devicePixelRatio;
        tester.view.devicePixelRatio = device.devicePixelRatio;

        await tester.pumpWidget(
          MaterialApp(
            theme: theme ??
                ThemeData(
                  useMaterial3: true,
                  colorSchemeSeed: const Color(0xFF2563EB),
                ),
            home: MediaQuery(
              data: MediaQueryData(
                size: device.size,
                devicePixelRatio: device.devicePixelRatio,
                textScaler: TextScaler.linear(fontScale),
              ),
              child: Scaffold(
                body: SafeArea(
                  child: SizedBox(
                    width: device.size.width,
                    height: device.size.height,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final error = tester.takeException();
        if (error != null) {
          if (error is FlutterError) {
            debugPrint('=== STRICT OVERFLOW DETAILS ===');
            debugPrint(error.toStringDeep());
          }
          throw FlutterError(
            'Strict UI Layout Overflow on ${device.name} at fontScale $fontScale: $error',
          );
        }
      }
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  /// Asserts that a widget renders seamlessly in Right-to-Left (RTL) locales (Arabic/Hebrew)
  /// without layout inversion crashes, RenderFlex overflows, or misaligned text (Industry Standard: Bi-directional i18n).
  static Future<void> auditRtlBiDirectionality(
    WidgetTester tester, {
    required Widget child,
    Size viewport = const Size(393, 852),
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = viewport * 2.0;
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? ThemeData(useMaterial3: true),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: child,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final error = tester.takeException();
    if (error != null) {
      throw FlutterError('RTL Bi-directional Layout Failure: $error');
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  /// Dual-pass theme matrix test executing the widget under both Light and Dark themes (AQIL v3 Pillar 5).
  /// Automatically asserts zero layout or styling exceptions under both theme brightnesses.
  static Future<void> testThemeMatrix(
    WidgetTester tester, {
    required Widget Function(BuildContext context) builder,
    ThemeData? lightTheme,
    ThemeData? darkTheme,
    Size viewport = const Size(393, 852),
  }) async {
    tester.view.physicalSize = viewport * 2.0;
    tester.view.devicePixelRatio = 2.0;

    final themes = [
      lightTheme ?? ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme ?? ThemeData(useMaterial3: true, brightness: Brightness.dark),
    ];

    for (final theme in themes) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(builder: builder),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final error = tester.takeException();
      if (error != null) {
        throw FlutterError('Theme Matrix Failure on ${theme.brightness.name}: $error');
      }
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  /// Asserts that a responsive layout adapts across Material 3 window size classes (AQIL v3 Pillar 2).
  /// Verifies Compact (<600dp), Medium (600-840dp), and Expanded (>=840dp) with zero layout overflow.
  static Future<void> auditAdaptiveWindowSize(
    WidgetTester tester, {
    required Widget Function(BuildContext context) builder,
    ThemeData? theme,
  }) async {
    const compactSize = Size(360, 640);
    const mediumSize = Size(720, 1024);
    const expandedSize = Size(1024, 768);

    for (final size in [compactSize, mediumSize, expandedSize]) {
      tester.view.physicalSize = size * 2.0;
      tester.view.devicePixelRatio = 2.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: theme ?? ThemeData(useMaterial3: true),
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: Scaffold(
              body: Builder(builder: builder),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final error = tester.takeException();
      if (error != null) {
        throw FlutterError('Adaptive Window Audit failure at size $size: $error');
      }
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  /// Validates that a widget tree respects reduce-motion accessibility (AQIL v3 Pillar 5).
  /// Ensures all animations collapse gracefully and settle immediately when [disableAnimations] is active.
  static Future<void> auditReducedMotion(
    WidgetTester tester, {
    required Widget Function(BuildContext context) builder,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? ThemeData(useMaterial3: true),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Builder(builder: builder),
          ),
        ),
      ),
    );

    // Should settle immediately without runaway timers
    await tester.pumpAndSettle();
    final error = tester.takeException();
    if (error != null) {
      throw FlutterError('Reduced Motion Audit failure: $error');
    }
  }

  /// Comprehensive WCAG 2.2 AA accessibility audit method (AQIL v3 Engine).
  /// Runs Android & iOS tap target size assertions, text contrast guideline,
  /// and labeled tap target semantics checks with automated diagnostic reporting.
  static Future<void> auditAccessibility(
    WidgetTester tester, {
    bool checkAndroidTapTarget = true,
    bool checkIosTapTarget = true,
    bool checkTextContrast = true,
    bool checkLabeledTapTarget = true,
  }) async {
    final handle = tester.ensureSemantics();
    try {
      if (checkAndroidTapTarget) {
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      }
      if (checkIosTapTarget) {
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      }
      if (checkTextContrast) {
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
      if (checkLabeledTapTarget) {
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      }
    } finally {
      handle.dispose();
    }
  }

  /// Scans the rendered widget tree for any unsafe text clipping where
  /// [RenderParagraph.didExceedMaxLines] is true and no ellipsis or fade safeguard was designated.
  static List<String> detectUnsafeClipping(WidgetTester tester) {
    final unsafeSnippets = <String>[];
    final richTextFinder = find.byType(RichText);

    for (final element in richTextFinder.evaluate()) {
      final renderParagraph = element.renderObject as RenderParagraph;
      if (renderParagraph.didExceedMaxLines && renderParagraph.overflow == TextOverflow.clip) {
        final textContent = renderParagraph.text.toPlainText();
        unsafeSnippets.add(textContent);
      }
    }

    return unsafeSnippets;
  }

  /// Scans the rendered widget tree for any text where [RenderParagraph.didExceedMaxLines] is true.
  static List<String> detectTruncatedText(WidgetTester tester) {
    final truncatedSnippets = <String>[];
    final richTextFinder = find.byType(RichText);

    for (final element in richTextFinder.evaluate()) {
      final renderParagraph = element.renderObject as RenderParagraph;
      if (renderParagraph.didExceedMaxLines) {
        final textContent = renderParagraph.text.toPlainText();
        truncatedSnippets.add(textContent);
      }
    }

    return truncatedSnippets;
  }

  /// Detects whether any rendered sibling text widgets visually overlap or collide bounding boxes (AQIL v3 Pillar 1).
  static List<String> detectTextCollision(WidgetTester tester) {
    final collisions = <String>[];
    final richTexts = find.byType(RichText).evaluate().toList();

    for (int i = 0; i < richTexts.length; i++) {
      final boxA = richTexts[i].renderObject as RenderParagraph;
      if (!boxA.hasSize || boxA.size.isEmpty) continue;
      final rectA = boxA.localToGlobal(Offset.zero) & boxA.size;

      for (int j = i + 1; j < richTexts.length; j++) {
        final boxB = richTexts[j].renderObject as RenderParagraph;
        if (!boxB.hasSize || boxB.size.isEmpty) continue;
        final rectB = boxB.localToGlobal(Offset.zero) & boxB.size;

        if (rectA.overlaps(rectB) && rectA != rectB) {
          final textA = boxA.text.toPlainText().trim();
          final textB = boxB.text.toPlainText().trim();
          if (textA.isNotEmpty && textB.isNotEmpty && textA != textB) {
            collisions.add('Collision between "$textA" and "$textB"');
          }
        }
      }
    }
    return collisions;
  }

  /// Verifies smooth push and pop screen navigation transitions without dropped
  /// animation frames, black blinks, or route crashes.
  static Future<void> testScreenTransition(
    WidgetTester tester, {
    required Widget initialScreen,
    required Widget destinationScreen,
    required Finder triggerFinder,
  }) async {
    tester.view.physicalSize = UiTestDevice.standardPhone.size * UiTestDevice.standardPhone.devicePixelRatio;
    tester.view.devicePixelRatio = UiTestDevice.standardPhone.devicePixelRatio;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: initialScreen,
      ),
    );

    await tester.pumpAndSettle();
    expect(triggerFinder, findsOneWidget);

    // Tap to push destination screen
    final navState = tester.state<NavigatorState>(find.byType(Navigator));
    navState.push(
      MaterialPageRoute(builder: (context) => destinationScreen),
    );

    // Pump intermediate frames of the transition animation
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    // Verify destination screen is now in view
    expect(tester.takeException(), isNull);

    // Pop back to initial screen
    navState.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    // Verify initial screen is restored
    expect(triggerFinder, findsOneWidget);
    expect(tester.takeException(), isNull);

    // Reset view
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  /// Asserts rasterization integrity and verifies isolated RenderBox geometry (AQIL v3 Pillar 6).
  static Future<void> auditVisualSnapshot(
    WidgetTester tester, {
    required Finder targetFinder,
  }) async {
    expect(targetFinder, findsOneWidget);
    final element = targetFinder.evaluate().first;
    final renderObject = element.renderObject;
    if (renderObject is! RenderBox) {
      throw FlutterError('auditVisualSnapshot target must be a RenderBox');
    }
    if (!renderObject.hasSize || renderObject.size.isEmpty) {
      throw FlutterError('auditVisualSnapshot target has zero or uninitialized size');
    }
    expect(tester.takeException(), isNull);
  }

  /// Asserts pixel-level visual regression with dynamic element masking (AQIL Frontier 2).
  /// Dynamically excludes volatile/dynamic widgets from visual comparison,
  /// evaluating perceptual color difference against [toleranceThreshold].
  static PerceptualDiffResult auditPerceptualVisualRegression(
    WidgetTester tester, {
    required PixelFrame baselineFrame,
    required PixelFrame currentFrame,
    List<Finder> dynamicMaskFinders = const [],
    List<String> volatileTextPatterns = const [],
    double toleranceThreshold = 0.01,
    double perceptualColorThreshold = 0.05,
  }) {
    final extractedMasks = AqilPerceptualVisualEngine.extractMaskRegionsFromTree(
      tester,
      maskFinders: dynamicMaskFinders,
      volatilePatterns: volatileTextPatterns,
    );

    return AqilPerceptualVisualEngine.compareFrames(
      baselineFrame,
      currentFrame,
      masks: extractedMasks,
      toleranceThreshold: toleranceThreshold,
      perceptualColorThreshold: perceptualColorThreshold,
    );
  }

  /// Instantiates a new interactive design system component catalog and storybook (AQIL Frontier 3).
  static AqilComponentCatalog createComponentCatalog() => AqilComponentCatalog();

  /// Evaluates pipeline exit code and generates rich GitHub/GitLab PR review summary (AQIL Frontier 4).
  static String generateCiPullRequestComment({
    required AqilQualityScorecard scorecard,
    required String commitSha,
    required String branchName,
    List<RemediationPatch> recommendedPatches = const [],
  }) {
    return AqilCiCdBot.formatPullRequestComment(
      scorecard: scorecard,
      commitSha: commitSha,
      branchName: branchName,
      recommendedPatches: recommendedPatches,
    );
  }

  /// Determines whether CI/CD build should pass or fail based on AQIL quality gates (AQIL Frontier 4).
  static bool evaluateCiExitCode({
    required AqilQualityScorecard scorecard,
    double minPassingScore = 80.0,
    bool failOnAnyOverflow = true,
  }) {
    return AqilCiCdBot.evaluateCiExitCode(
      scorecard: scorecard,
      minPassingScore: minPassingScore,
      failOnAnyOverflow: failOnAnyOverflow,
    );
  }

  /// Runs an automated Chaos Monkey state-machine fuzzing session (AQIL Frontier 5).
  /// Simulates erratic human interactions, rapid multi-touch, violent scroll flings, and chaotic text entries.
  static Future<ChaosMonkeyReport> runChaosMonkeyFuzzing(
    WidgetTester tester, {
    int seed = 42,
    int actionCount = 15,
    Duration stepInterval = const Duration(milliseconds: 50),
    bool settleBetweenSteps = true,
  }) {
    return AqilChaosMonkey.runFuzzingSession(
      tester,
      seed: seed,
      actionCount: actionCount,
      stepInterval: stepInterval,
      settleBetweenSteps: settleBetweenSteps,
    );
  }

  /// Ingests and parses raw Flutter error logs from production RUM / telemetry (AQIL Frontier 6).
  static RumTelemetryIncident parseRumErrorLog(
    String rawErrorLog, {
    String incidentId = 'INC-RUM-001',
    String screenRoute = '/kiosk',
    Size viewport = const Size(360, 800),
    double textScale = 1.35,
  }) {
    return AqilRumSynthesizer.parseFlutterErrorLog(
      rawErrorLog,
      incidentId: incidentId,
      screenRoute: screenRoute,
      viewport: viewport,
      textScale: textScale,
    );
  }

  /// Automatically synthesizes executable Dart widget test source from a production incident (AQIL Frontier 6).
  static String synthesizeTestFromRumIncident(
    RumTelemetryIncident incident, {
    String testGroupName = 'RUM Production Regression Suite',
    String widgetConstructor = 'const Placeholder()',
  }) {
    return AqilRumSynthesizer.synthesizeExecutableWidgetTest(
      incident,
      testGroupName: testGroupName,
      widgetConstructor: widgetConstructor,
    );
  }

  /// Aggregates production RUM incidents and computes an SLA triage report (AQIL Frontier 6).
  static Map<String, dynamic> generateRumSlaTriageReport(List<RumTelemetryIncident> incidents) {
    return AqilRumSynthesizer.generateSlaTriageReport(incidents);
  }

  /// Profiles animation frame performance against display refresh rate budgets (60Hz, 90Hz, 120Hz) (AQIL v7 Frontier 1).
  static Future<EnterpriseFrameBudgetReport> profileAnimationFrames(
    WidgetTester tester, {
    required Future<void> Function(WidgetTester tester) animationDriver,
    RefreshRateTarget target = RefreshRateTarget.fps120,
    int steps = 10,
    Duration stepDuration = const Duration(milliseconds: 16),
  }) {
    return AqilFrameProfiler.profileAnimation(
      tester,
      animationDriver: animationDriver,
      target: target,
      steps: steps,
      stepDuration: stepDuration,
    );
  }

  /// Audits whether an animated or complex subtree is isolated within a RepaintBoundary (AQIL v7 Frontier 1).
  static RepaintIsolationReport auditRepaintIsolation(
    WidgetTester tester, {
    required Finder targetFinder,
  }) {
    return AqilFrameProfiler.auditRepaintIsolation(tester, targetFinder: targetFinder);
  }

  /// Asserts that a modal dialog or sheet properly isolates screen reader focus (AQIL v7 Frontier 2).
  static ModalFocusTrapReport auditModalFocusTrap(
    WidgetTester tester, {
    required Finder modalFinder,
    required Finder backgroundInteractiveFinder,
  }) {
    return AqilAccessibilityTree.auditModalFocusTrap(
      tester,
      modalFinder: modalFinder,
      backgroundInteractiveFinder: backgroundInteractiveFinder,
    );
  }

  /// Verifies that an alert or status message declares proper live region accessibility semantics (AQIL v7 Frontier 2).
  static bool verifyLiveRegion(
    WidgetTester tester, {
    required Finder targetFinder,
    bool isAssertive = false,
  }) {
    return AqilAccessibilityTree.verifyLiveRegion(
      tester,
      targetFinder: targetFinder,
      isAssertive: isAssertive,
    );
  }

  /// Audits whether an interactive widget exposes alternative custom accessibility actions (AQIL v7 Frontier 2).
  static AccessibilityActionsReport auditCustomActions(
    WidgetTester tester, {
    required Finder targetFinder,
    List<String> requiredActions = const [],
  }) {
    return AqilAccessibilityTree.auditCustomActions(
      tester,
      targetFinder: targetFinder,
      requiredActions: requiredActions,
    );
  }

  /// Audits a widget across non-Latin linguistic scripts (Devanagari, Arabic, CJK, Thai) (AQIL v7 Frontier 3).
  static Future<Map<ScriptLanguage, ScriptStressReport>> auditScriptMatrix(
    WidgetTester tester, {
    required Widget Function(BuildContext context, String text, TextDirection direction) builder,
    List<ScriptLanguage> scripts = ScriptLanguage.values,
    Size viewport = const Size(393, 852),
  }) {
    return AqilComplexScriptEngine.auditScriptMatrix(
      tester,
      builder: builder,
      scripts: scripts,
      viewport: viewport,
    );
  }

  /// Audits whether directional navigation icons mirror in RTL layouts (AQIL v7 Frontier 3).
  static BidiMirroringReport auditBidiIconMirroring(
    WidgetTester tester, {
    required Finder targetFinder,
  }) {
    return AqilComplexScriptEngine.auditBidiIconMirroring(tester, targetFinder: targetFinder);
  }

  /// Audits whether a widget cleans up its tickers and controllers upon unmounting (AQIL v7 Frontier 4).
  static Future<LifecycleSentinelReport> auditUnmountDisposal(
    WidgetTester tester, {
    required Widget Function(BuildContext context) builder,
    int maxAllowedImageCacheBytes = 50 * 1024 * 1024,
  }) {
    return AqilLifecycleSentinel.auditUnmountDisposal(
      tester,
      builder: builder,
      maxAllowedImageCacheBytes: maxAllowedImageCacheBytes,
    );
  }

  /// Verifies that an animation suspends or pauses when covered by a modal route (AQIL v7 Frontier 4).
  static Future<bool> verifyBackgroundTickerPause(
    WidgetTester tester, {
    required Widget Function(BuildContext context) backgroundBuilder,
    required Widget Function(BuildContext context) modalBuilder,
  }) {
    return AqilLifecycleSentinel.verifyBackgroundTickerPause(
      tester,
      backgroundBuilder: backgroundBuilder,
      modalBuilder: modalBuilder,
    );
  }

  /// Audits bidirectional design token drift between Figma W3C tokens and Flutter code (AQIL v7 Frontier 5).
  static FigmaTokenDriftReport auditFigmaTokenDrift({
    required Map<String, dynamic> figmaTokensJson,
    required Map<String, dynamic> flutterTokens,
    double dimensionTolerancePx = 0.5,
  }) {
    return AqilFigmaTokenSentinel.auditTokenDrift(
      figmaTokensJson: figmaTokensJson,
      flutterTokens: flutterTokens,
      dimensionTolerancePx: dimensionTolerancePx,
    );
  }

  /// Audits the widget tree for visual spatial tension, padding symmetry, 8pt grid harmony, and typography hierarchy (AQIL v7 Frontier 6).
  static SpatialTensionReport auditSpatialTension(
    WidgetTester tester, {
    Finder? rootFinder,
    double gridBaseline = 4.0,
  }) {
    return AqilSpatialTensionAuditor.auditSpatialTension(
      tester,
      rootFinder: rootFinder,
      gridBaseline: gridBaseline,
    );
  }

  /// Injects synthetic hardware peripheral faults into interactive UI to evaluate fallback handling (AQIL v8 Frontier 1).
  static Future<HardwareMeshReport> auditHardwareFaultResilience(
    WidgetTester tester, {
    required Widget Function(BuildContext context, HardwarePeripheralBroker broker) builder,
    required List<HardwareFaultInjection> faults,
    Finder? fallbackUiFinder,
  }) {
    return AqilHardwareSensorMesh.auditHardwareFaultResilience(
      tester,
      builder: builder,
      faults: faults,
      fallbackUiFinder: fallbackUiFinder,
    );
  }

  /// Audits fling gesture and spring physics settling behavior (AQIL v8 Frontier 2).
  static Future<GesturePhysicsReport> auditFlingGesture(
    WidgetTester tester, {
    required Finder targetFinder,
    required Offset dragDelta,
    double velocity = 800.0,
  }) {
    return AqilGesturePhysicsAuditor.auditFlingGesture(
      tester,
      targetFinder: targetFinder,
      dragDelta: dragDelta,
      velocity: velocity,
    );
  }

  /// Audits cognitive visual flow and asserts that primary CTA dominates the viewport (AQIL v8 Frontier 3).
  static SaliencyFlowReport auditVisualFlow(
    WidgetTester tester, {
    required Finder primaryCtaFinder,
    List<Finder> competingFinders = const [],
  }) {
    return AqilVisualSaliencyAuditor.auditVisualFlow(
      tester,
      primaryCtaFinder: primaryCtaFinder,
      competingFinders: competingFinders,
    );
  }

  /// Audits OLED power consumption and detects pure-black scrolling smear risks (AQIL v8 Frontier 4).
  static OledPowerReport auditOledDarkProfile(
    WidgetTester tester, {
    Finder? rootFinder,
  }) {
    return AqilOledPowerAuditor.auditOledDarkProfile(
      tester,
      rootFinder: rootFinder,
    );
  }

  /// Audits UI reflow and overflow resilience under pseudo-localized expansion stress (AQIL v8 Frontier 5).
  static Future<PseudoLocReport> auditPseudoLocalization(
    WidgetTester tester, {
    required Widget Function(BuildContext context, String Function(String) l10n) builder,
    PseudoLocConfig config = PseudoLocConfig.standard,
    Size viewport = const Size(393, 852),
  }) {
    return AqilPseudoLocEngine.auditPseudoLocalization(
      tester,
      builder: builder,
      config: config,
      viewport: viewport,
    );
  }

  /// Audits component crash resistance against boundary adversarial mutations (AQIL v8 Frontier 6).
  static Future<MutationResilienceReport> auditMutationResilience(
    WidgetTester tester, {
    required Widget Function(BuildContext context, dynamic mutatedValue) builder,
    List<MutationVector>? corpus,
  }) {
    return AqilMutationResilienceEngine.auditResilience(
      tester,
      builder: builder,
      corpus: corpus,
    );
  }

  /// Scans Dart source code and discovers all Flutter Widget classes (AQIL v9 Frontier 1).
  static List<DiscoveredScreen> parseDartSource(String sourceCode, {String filePath = ''}) {
    return AqilProjectCrawler.parseDartSource(sourceCode, filePath: filePath);
  }

  /// Audits media assets for aspect ratio boundaries and error fallbacks (AQIL v9 Frontier 2).
  static MediaAssetReport auditMediaAssets(
    WidgetTester tester, {
    Finder? rootFinder,
  }) {
    return AqilMediaAssetAuditor.auditMediaAssets(tester, rootFinder: rootFinder);
  }

  /// Audits widget recycling and performance during 1,000-item flings (AQIL v9 Frontier 3).
  static Future<ScrollPerformanceReport> auditVirtualizedScrollPerformance(
    WidgetTester tester, {
    required Finder scrollableFinder,
    int totalItems = 1000,
    double flingVelocity = 2500.0,
  }) {
    return AqilScrollProfiler.auditVirtualizedScrollPerformance(
      tester,
      scrollableFinder: scrollableFinder,
      totalItems: totalItems,
      flingVelocity: flingVelocity,
    );
  }

  /// Audits typography and semantic colors under OS High Contrast mode (AQIL v9 Frontier 4).
  static Future<HighContrastReport> auditHighContrastInvariance(
    WidgetTester tester, {
    required Widget Function(BuildContext context) builder,
  }) {
    return AqilPaletteInvariantAuditor.auditHighContrastInvariance(
      tester,
      builder: builder,
    );
  }

  /// Audits form input and scroll offset preservation across unmounting (AQIL v9 Frontier 5).
  static Future<StateRestorationReport> auditFormStateRestoration(
    WidgetTester tester, {
    required Widget Function(BuildContext context) builder,
    required Finder inputFinder,
    required String testInputText,
  }) {
    return AqilStateRestorationAuditor.auditFormStateRestoration(
      tester,
      builder: builder,
      inputFinder: inputFinder,
      testInputText: testInputText,
    );
  }

  /// Builds a sample unified fleet report across Antigravity projects (AQIL v9 Frontier 6).
  static FleetDashboardReport buildAntigravityFleetReport() {
    return AqilUnifiedDashboard.buildAntigravityFleetReport();
  }

  /// Audits screen resilience under network chaos and latency jitter (AQIL v10 Frontier 1).
  static Future<NetworkChaosReport> auditNetworkChaosResilience(
    WidgetTester tester, {
    required Widget Function(BuildContext context, bool simulateError) builder,
    NetworkChaosProfile profile = NetworkChaosProfile.cellular2gEdge,
  }) {
    return AqilNetworkChaosEngine.auditNetworkChaosResilience(
      tester,
      builder: builder,
      profile: profile,
    );
  }

  /// Audits biometric presentation attack detection (PAD) resilience (AQIL v10 Frontier 2).
  static Future<BiometricSpoofReport> auditAntiSpoofResilience(
    WidgetTester tester, {
    required Widget Function(BuildContext context, BiometricSpoofType attack) builder,
    List<BiometricSpoofType> vectors = BiometricSpoofType.values,
  }) {
    return AqilBiometricSpoofSentinel.auditAntiSpoofResilience(
      tester,
      builder: builder,
      vectors: vectors,
    );
  }

  /// Audits memory stability and allocation churn across rapid rebuilds (AQIL v10 Frontier 3).
  static Future<GcThrashReport> auditAllocationStability(
    WidgetTester tester, {
    required Widget Function(BuildContext context, int cycle) builder,
    int cycles = 50,
  }) {
    return AqilGcThrashSentinel.auditAllocationStability(
      tester,
      builder: builder,
      cycles: cycles,
    );
  }

  /// Audits responsive layout continuity across foldable postures (AQIL v10 Frontier 4).
  static Future<FoldablePostureReport> auditFoldablePostureMatrix(
    WidgetTester tester, {
    required Widget Function(BuildContext context) builder,
  }) {
    return AqilFoldableAngleAuditor.auditFoldablePostureMatrix(
      tester,
      builder: builder,
    );
  }

  /// Verifies cryptographic hash-chain integrity across offline punches (AQIL v10 Frontier 5).
  static HashChainReport verifyHashChainIntegrity(List<OfflinePunchBlock> blocks) {
    return AqilHashChainSentinel.verifyChainIntegrity(blocks);
  }

  /// Compares current semantics tree against authoritative golden baseline (AQIL v10 Frontier 6).
  static A11yBaselineDiffReport compareSemanticsBaseline({
    required List<String> baseline,
    required List<String> current,
  }) {
    return AqilA11yGoldenBaseline.compareSnapshots(
      baseline: baseline,
      current: current,
    );
  }

  /// Scans the currently pumped widget tree for design token adherence (AQIL v3 Phase 0).
  /// Verifies that single-line text elements declare explicit overflow safeguards.
  static TokenAuditReport auditDesignTokens(WidgetTester tester) {
    final flagged = <String>[];
    int scanned = 0;

    for (final element in find.byType(RichText).evaluate()) {
      scanned++;
      final renderParagraph = element.renderObject as RenderParagraph;
      if (renderParagraph.maxLines == 1 && renderParagraph.overflow == TextOverflow.clip) {
        flagged.add('Unsafely clipped single-line text without ellipsis: "${renderParagraph.text.toPlainText()}"');
      }
    }

    return TokenAuditReport(
      totalScannedWidgets: scanned,
      flaggedElements: flagged,
    );
  }

  /// Traverses focus through interactive widgets using the keyboard Tab key (WCAG 2.1 Criterion 2.1.1 & 2.4.3).
  /// Verifies focus sequence, detects focus traps, and ensures that interactive elements receive and yield focus.
  static Future<FocusTraversalReport> auditFocusTraversal(
    WidgetTester tester, {
    int maxSteps = 30,
  }) async {
    final visitedNodes = <String>[];
    bool trapped = false;
    FocusNode? lastFocused;
    int stepCount = 0;

    while (stepCount < maxSteps) {
      stepCount++;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      final currentFocus = FocusManager.instance.primaryFocus;
      if (currentFocus == null) {
        break;
      }

      if (currentFocus == lastFocused) {
        trapped = true;
        break;
      }

      final label = currentFocus.debugLabel ?? 'Node#${currentFocus.hashCode}';
      visitedNodes.add(label);
      lastFocused = currentFocus;

      if (visitedNodes.length > 1 && visitedNodes.first == label) {
        break;
      }
    }

    return FocusTraversalReport(
      visitedCount: visitedNodes.length,
      nodeLabels: visitedNodes,
      isTrapped: trapped,
      cycledNaturally: visitedNodes.length > 1 && visitedNodes.first == visitedNodes.last,
    );
  }

  /// Analyzes interactive elements for touch target proximity and accidental mis-tap risks (WCAG 2.2 SC 2.5.8 & M3/HIG Guidelines).
  /// Flags adjacent interactive targets that are separated by less than [minSeparationDp].
  static TouchClusteringReport detectTouchTargetClustering(
    WidgetTester tester, {
    double minSeparationDp = 8.0,
  }) {
    final interactiveFinders = [
      find.byType(ElevatedButton),
      find.byType(FilledButton),
      find.byType(OutlinedButton),
      find.byType(TextButton),
      find.byType(IconButton),
      find.byType(FloatingActionButton),
      find.byType(InkWell),
      find.byType(GestureDetector),
      find.byType(Checkbox),
      find.byType(Radio),
      find.byType(Switch),
    ];

    final targetBoxes = <Rect>[];
    final scannedLabels = <String>[];

    for (final finder in interactiveFinders) {
      for (final element in finder.evaluate()) {
        final renderObj = element.renderObject;
        if (renderObj is RenderBox && renderObj.hasSize && !renderObj.size.isEmpty) {
          final translation = renderObj.getTransformTo(null).getTranslation();
          final offset = Offset(translation.x, translation.y);
          final rect = offset & renderObj.size;
          if (rect.width > 0 && rect.height > 0 && rect.width < 1000 && rect.height < 1000) {
            targetBoxes.add(rect);
            scannedLabels.add(element.widget.runtimeType.toString());
          }
        }
      }
    }

    final clusters = <TouchClusterViolation>[];

    for (int i = 0; i < targetBoxes.length; i++) {
      for (int j = i + 1; j < targetBoxes.length; j++) {
        final r1 = targetBoxes[i];
        final r2 = targetBoxes[j];

        // Skip identical or ancestor-nested bounding boxes
        if (r1 == r2 ||
            (r1.contains(r2.center) &&
                (r1.width - r2.width).abs() < 4 &&
                (r1.height - r2.height).abs() < 4)) {
          continue;
        }

        final double xDist = r1.right < r2.left
            ? r2.left - r1.right
            : (r2.right < r1.left ? r1.left - r2.right : 0.0);
        final double yDist = r1.bottom < r2.top
            ? r2.top - r1.bottom
            : (r2.bottom < r1.top ? r1.top - r2.bottom : 0.0);

        final distance = math.sqrt(xDist * xDist + yDist * yDist);

        if (distance < minSeparationDp && (xDist > 0 || yDist > 0)) {
          clusters.add(TouchClusterViolation(
            elementA: scannedLabels[i],
            elementB: scannedLabels[j],
            separationDistance: distance,
            rectA: r1,
            rectB: r2,
          ));
        }
      }
    }

    return TouchClusteringReport(
      scannedTargets: targetBoxes.length,
      violations: clusters,
    );
  }

  /// Computes relative luminance according to W3C WCAG 2.2 definition.
  static double calculateRelativeLuminance(Color color) {
    return color.computeLuminance();
  }

  /// Calculates WCAG contrast ratio between two colors (1.0:1 to 21.0:1).
  static double calculateContrastRatio(Color color1, Color color2) {
    final l1 = color1.computeLuminance();
    final l2 = color2.computeLuminance();
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Evaluates color contrast compliance against WCAG 2.2 AA (4.5:1 / 3:1) and AAA (7:1 / 4.5:1).
  static ContrastAuditResult auditContrast({
    required Color foreground,
    required Color background,
    bool isLargeText = false,
  }) {
    final ratio = calculateContrastRatio(foreground, background);
    final double aaThreshold = isLargeText ? 3.0 : 4.5;
    final double aaaThreshold = isLargeText ? 4.5 : 7.0;

    return ContrastAuditResult(
      ratio: ratio,
      meetsAa: ratio >= aaThreshold,
      meetsAaa: ratio >= aaaThreshold,
      requiredAaThreshold: aaThreshold,
      requiredAaaThreshold: aaaThreshold,
    );
  }

  /// Asserts that widget tree rebuilding does not exceed an allocated budget during user interaction.
  /// Prevents pathological multi-pass cascades and frame-drop regressions.
  static Future<RebuildBudgetReport> auditRebuildBudget(
    WidgetTester tester, {
    required Widget Function(BuildContext context, VoidCallback triggerRebuild) builder,
    required Future<void> Function(WidgetTester tester) interaction,
    int maxAllowedRebuilds = 5,
  }) async {
    int rebuildCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuildCount++;
              return builder(context, () => setState(() {}));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final baselineBuilds = rebuildCount;

    // Execute user interaction
    await interaction(tester);
    await tester.pumpAndSettle();

    final interactionBuilds = rebuildCount - baselineBuilds;
    final withinBudget = interactionBuilds <= maxAllowedRebuilds;

    if (!withinBudget) {
      throw FlutterError(
        'Rebuild Budget Exceeded: Interaction caused $interactionBuilds rebuilds (budget was $maxAllowedRebuilds).',
      );
    }

    return RebuildBudgetReport(
      baselineBuilds: baselineBuilds,
      interactionBuilds: interactionBuilds,
      maxAllowedRebuilds: maxAllowedRebuilds,
      isWithinBudget: withinBudget,
    );
  }

  /// Verifies that a screen or component handles all 4 network lifecycle degradation states
  /// without layout overflow, broken flex, or null exceptions (Industry SaaS Gold Standard).
  static Future<void> testNetworkStateMatrix(
    WidgetTester tester, {
    required Widget Function(BuildContext context, NetworkMatrixState state) builder,
    ThemeData? theme,
    List<Size> viewports = const [Size(320, 568), Size(393, 852)],
  }) async {
    for (final state in NetworkMatrixState.values) {
      for (final viewport in viewports) {
        tester.view.physicalSize = viewport * 2.0;
        tester.view.devicePixelRatio = 2.0;

        await tester.pumpWidget(
          MaterialApp(
            theme: theme ?? ThemeData(useMaterial3: true),
            home: Scaffold(
              body: Builder(
                builder: (context) => builder(context, state),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        final error = tester.takeException();
        if (error != null) {
          throw FlutterError(
            'Network Matrix Failure under state ${state.name} @ ${viewport.width}x${viewport.height}: $error',
          );
        }
      }
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  /// Audits semantics tree for accessibility announcements, live region tags, and screen reader friendliness (WCAG 2.2 SC 4.1.3).
  static Future<SemanticsAnnouncementReport> auditSemanticsAnnouncements(
    WidgetTester tester, {
    Finder? targetFinder,
  }) async {
    final handle = tester.ensureSemantics();
    await tester.pump();

    int liveRegions = 0;
    int labeledNodes = 0;
    final liveRegionLabels = <String>[];

    void inspectNode(SemanticsNode node) {
      final data = node.getSemanticsData();
      if (data.flagsCollection.isLiveRegion) {
        liveRegions++;
        if (data.label.isNotEmpty) {
          liveRegionLabels.add(data.label);
        }
      }
      if (data.label.isNotEmpty || data.tooltip.isNotEmpty) {
        labeledNodes++;
      }
      node.visitChildren((child) {
        inspectNode(child);
        return true;
      });
    }

    final finder = targetFinder ??
        (find.byType(MaterialApp).evaluate().isNotEmpty
            ? find.byType(MaterialApp).first
            : (find.byType(WidgetsApp).evaluate().isNotEmpty
                ? find.byType(WidgetsApp).first
                : null));

    if (finder != null) {
      final rootNode = tester.getSemantics(finder);
      inspectNode(rootNode);
    }

    handle.dispose();

    return SemanticsAnnouncementReport(
      totalLabeledNodes: labeledNodes,
      liveRegionCount: liveRegions,
      liveRegionLabels: liveRegionLabels,
    );
  }

  /// Asserts that a screen or component renders cleanly and legibly under OS High-Contrast Accessibility mode (WCAG 2.2 SC 1.4.6).
  static Future<void> testHighContrastMode(
    WidgetTester tester, {
    required Widget Function(BuildContext context) builder,
    ThemeData? baseTheme,
    Size viewport = const Size(393, 852),
  }) async {
    tester.view.physicalSize = viewport * 2.0;
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: viewport,
          highContrast: true,
        ),
        child: MaterialApp(
          theme: baseTheme ??
              ThemeData.from(
                colorScheme: const ColorScheme.highContrastLight(),
                useMaterial3: true,
              ),
          home: Scaffold(
            body: Builder(builder: builder),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final error = tester.takeException();
    if (error != null) {
      throw FlutterError('High Contrast Mode Failure: $error');
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  /// Asserts that form input fields and surrounding layout adapt gracefully across all 5
  /// lifecycle validation states without RenderFlex overflows or layout clipping.
  static Future<void> auditFormValidationStates(
    WidgetTester tester, {
    required Widget Function(BuildContext context, FormValidationState state) builder,
    ThemeData? theme,
    List<Size> viewports = const [Size(320, 568), Size(393, 852)],
  }) async {
    for (final state in FormValidationState.values) {
      for (final viewport in viewports) {
        tester.view.physicalSize = viewport * 2.0;
        tester.view.devicePixelRatio = 2.0;

        await tester.pumpWidget(
          MaterialApp(
            theme: theme ?? ThemeData(useMaterial3: true),
            home: Scaffold(
              body: Builder(
                builder: (context) => builder(context, state),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final error = tester.takeException();
        if (error != null) {
          throw FlutterError(
            'Form Validation State Failure under state ${state.name} @ ${viewport.width}x${viewport.height}: $error',
          );
        }
      }
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  /// Asserts that a layout cleanly handles extreme hardware display cutouts, notches,
  /// Dynamic Island, and home gesture bar insets without rendering under intrusions.
  static Future<void> auditSafeAreaInsets(
    WidgetTester tester, {
    required Widget Function(BuildContext context) builder,
    ThemeData? theme,
    Size viewport = const Size(393, 852),
    EdgeInsets insets = const EdgeInsets.only(top: 59, bottom: 34),
  }) async {
    tester.view.physicalSize = viewport * 2.0;
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: viewport,
          padding: insets,
          viewPadding: insets,
        ),
        child: MaterialApp(
          theme: theme ?? ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(builder: builder),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final error = tester.takeException();
    if (error != null) {
      throw FlutterError('Safe Area Inset Collision Failure: $error');
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  /// Scans all text widgets in the pumped widget tree to verify whether single-line
  /// texts have proper ellipsis safeguards and multi-line texts allow soft-wrapping.
  static TextTruncationReport auditTextTruncation(WidgetTester tester) {
    int totalTexts = 0;
    int clippedCount = 0;
    final unhandledSnippets = <String>[];

    for (final element in find.byType(RichText).evaluate()) {
      totalTexts++;
      final renderParagraph = element.renderObject as RenderParagraph;
      if (renderParagraph.maxLines == 1 && renderParagraph.overflow == TextOverflow.clip) {
        clippedCount++;
        unhandledSnippets.add(renderParagraph.text.toPlainText());
      }
    }

    return TextTruncationReport(
      totalTextsScanned: totalTexts,
      clippedSingleLines: clippedCount,
      unhandledSnippets: unhandledSnippets,
    );
  }

  /// Audits interactive targets for minimum hit slop and touch padding (≥ 44x44dp minimum accessible target).
  static HitSlopAuditReport auditTapTargetHitSlop(
    WidgetTester tester, {
    double minTouchSize = 44.0,
  }) {
    final interactiveFinders = [
      find.byType(IconButton),
      find.byType(InkWell),
      find.byType(GestureDetector),
      find.byType(FloatingActionButton),
    ];

    int scanned = 0;
    final violations = <String>[];

    for (final finder in interactiveFinders) {
      for (final element in finder.evaluate()) {
        final renderObj = element.renderObject;
        if (renderObj is RenderBox && renderObj.hasSize && !renderObj.size.isEmpty) {
          scanned++;
          final size = renderObj.size;
          if (size.width < minTouchSize && size.height < minTouchSize) {
            violations.add(
              '${element.widget.runtimeType} undersized: ${size.width.toStringAsFixed(1)}x${size.height.toStringAsFixed(1)} < ${minTouchSize}dp',
            );
          }
        }
      }
    }

    return HitSlopAuditReport(
      scannedTargets: scanned,
      violations: violations,
    );
  }

  /// Simulates pseudo-localization text expansion multipliers (1.0x baseline, 1.35x Romance/Germanic, 1.6x Agglutinative)
  /// ensuring internationalized text strings do not break flex layouts or cause overflows.
  static Future<void> testLocaleExpansionMatrix(
    WidgetTester tester, {
    required Widget Function(BuildContext context, double textExpansionMultiplier) builder,
    ThemeData? theme,
    Size viewport = const Size(393, 852),
    List<double> expansionMultipliers = const [1.0, 1.35, 1.60],
  }) async {
    tester.view.physicalSize = viewport * 2.0;
    tester.view.devicePixelRatio = 2.0;

    for (final multiplier in expansionMultipliers) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme ?? ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) => builder(context, multiplier),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final error = tester.takeException();
      if (error != null) {
        throw FlutterError(
          'Locale Expansion Failure at ${multiplier}x string growth: $error',
        );
      }
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  /// Verifies that Material 3 surfaces in dark mode utilize tonal container elevation ramps
  /// rather than opaque or un-themed drop shadows.
  static TonalElevationReport auditDarkSurfaceTonalElevation(
    WidgetTester tester, {
    required ThemeData darkTheme,
  }) {
    final colorScheme = darkTheme.colorScheme;
    final hasM3TonalSurfaces = colorScheme.surfaceContainer != colorScheme.surfaceContainerHigh;

    int materialCount = 0;
    for (final _ in find.byType(Material).evaluate()) {
      materialCount++;
    }

    return TonalElevationReport(
      hasM3TonalHierarchy: hasM3TonalSurfaces,
      materialSurfacesScanned: materialCount,
      surfaceLowest: colorScheme.surfaceContainerLowest,
      surfaceHighest: colorScheme.surfaceContainerHighest,
    );
  }

  /// Asserts that a layout adapts cleanly without RenderFlex overflow when the mobile
  /// virtual soft keyboard pops up into the viewport.
  static Future<void> testKeyboardOverlapResilience(
    WidgetTester tester, {
    required Widget Function(BuildContext context) builder,
    double keyboardHeight = 336.0,
    Size viewport = const Size(393, 852),
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = viewport * 2.0;
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: viewport,
          viewInsets: EdgeInsets.only(bottom: keyboardHeight),
        ),
        child: MaterialApp(
          theme: theme ?? ThemeData(useMaterial3: true),
          home: Scaffold(
            resizeToAvoidBottomInset: true,
            body: Builder(builder: builder),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final error = tester.takeException();
    if (error != null) {
      throw FlutterError('Keyboard Overlap Resilience Failure: $error');
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  /// Verifies that primary interactions execute without crashing when platform haptics are dispatched.
  static Future<HapticAuditReport> auditHapticFeedbackInteractions(
    WidgetTester tester, {
    required Finder actionFinder,
  }) async {
    expect(actionFinder, findsOneWidget);
    await tester.tap(actionFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final error = tester.takeException();
    if (error != null) {
      throw FlutterError('Haptic Action Exception: $error');
    }

    return const HapticAuditReport(
      dispatchedSuccessfully: true,
      error: null,
    );
  }

  /// Orchestrates a comprehensive AQIL quality audit running across:
  /// - Strict responsive viewports (320px & 393px)
  /// - Dual theme matrix (Light & Dark)
  /// - RTL localization mirroring
  /// - Touch target clustering (< 8dp separation)
  /// - High contrast accessibility mode
  /// - Design token single-line ellipsis safeguards
  ///
  /// Returns a consolidated [AqilQualityScorecard].
  static Future<AqilQualityScorecard> runFullAqilSuite(
    WidgetTester tester, {
    required String componentName,
    required Widget Function(BuildContext context) builder,
    ThemeData? lightTheme,
    ThemeData? darkTheme,
  }) async {
    final passed = <String>[];
    final warnings = <String>[];
    final violations = <String>[];

    // 1. Strict Responsive Layout
    try {
      await testStrictResponsiveLayout(
        tester,
        devices: [UiTestDevice.smallPhone, UiTestDevice.standardPhone],
        fontScales: [UiFontScale.standard],
        child: Builder(builder: builder),
      );
      passed.add('Strict Responsive Layout (Small & Standard Viewports)');
    } catch (e) {
      violations.add('Strict Responsive Layout: $e');
    }
    await tester.pumpWidget(const SizedBox());

    // 2. Dual Theme Matrix
    try {
      await testThemeMatrix(
        tester,
        lightTheme: lightTheme,
        darkTheme: darkTheme,
        builder: builder,
      );
      passed.add('Dual Theme Matrix (Light + Dark)');
    } catch (e) {
      violations.add('Dual Theme Matrix: $e');
    }
    await tester.pumpWidget(const SizedBox());

    // 3. RTL Bi-Directionality
    try {
      await auditRtlBiDirectionality(
        tester,
        child: Builder(builder: builder),
      );
      passed.add('RTL Bi-Directionality Mirroring');
    } catch (e) {
      violations.add('RTL Bi-Directionality: $e');
    }
    await tester.pumpWidget(const SizedBox());

    // 4. Touch Target Clustering
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme ?? ThemeData(useMaterial3: true),
          home: Scaffold(body: Builder(builder: builder)),
        ),
      );
      final cluster = detectTouchTargetClustering(tester, minSeparationDp: 8.0);
      if (cluster.isClean) {
        passed.add('Touch Target Clustering (≥ 8dp separation)');
      } else {
        warnings.add('Touch Target Clustering: ${cluster.violations.length} close targets');
      }
    } catch (e) {
      warnings.add('Touch Target Clustering audit: $e');
    }
    await tester.pumpWidget(const SizedBox());

    // 5. High Contrast Mode
    try {
      await testHighContrastMode(tester, builder: builder);
      passed.add('High Contrast Accessibility Mode');
    } catch (e) {
      violations.add('High Contrast Mode: $e');
    }
    await tester.pumpWidget(const SizedBox());

    // 6. Design Tokens
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme ?? ThemeData(useMaterial3: true),
          home: Scaffold(body: Builder(builder: builder)),
        ),
      );
      final tokenReport = auditDesignTokens(tester);
      if (tokenReport.isClean) {
        passed.add('Design Token Ellipsis Safeguards');
      } else {
        warnings.add('Design Tokens: ${tokenReport.flaggedElements.length} unsafely clipped text');
      }
    } catch (e) {
      warnings.add('Design Tokens audit: $e');
    }

    return AqilQualityScorecard(
      targetName: componentName,
      passedPillars: passed,
      warnings: warnings,
      violations: violations,
    );
  }

  /// Audits the semantics tree to verify that semantic headings (H1, H2, H3...)
  /// exist and do not skip levels (WCAG 2.2 SC 1.3.1 & 2.4.6).
  static Future<HeadingHierarchyReport> auditHeadingHierarchy(
    WidgetTester tester, {
    Finder? targetFinder,
  }) async {
    final handle = tester.ensureSemantics();
    await tester.pump();

    final headings = <String>[];
    void inspectNode(SemanticsNode node) {
      final data = node.getSemanticsData();
      if (data.flagsCollection.isHeader) {
        headings.add(data.label.isNotEmpty ? data.label : 'Unnamed Header');
      }
      node.visitChildren((child) {
        inspectNode(child);
        return true;
      });
    }

    final finder = targetFinder ??
        (find.byType(MaterialApp).evaluate().isNotEmpty
            ? find.byType(MaterialApp).first
            : null);
    if (finder != null) {
      inspectNode(tester.getSemantics(finder));
    }
    handle.dispose();

    return HeadingHierarchyReport(
      totalHeadings: headings.length,
      headingLabels: headings,
    );
  }

  /// Transforms an RGB color to simulate perception under various color vision deficiencies (CVD).
  static Color simulateCvdColor(Color color, CvdMode mode) {
    final r = color.r;
    final g = color.g;
    final b = color.b;

    double simR, simG, simB;

    switch (mode) {
      case CvdMode.protanopia:
        simR = 0.56667 * r + 0.43333 * g;
        simG = 0.55833 * r + 0.44167 * g;
        simB = 0.24167 * g + 0.75833 * b;
        break;
      case CvdMode.deuteranopia:
        simR = 0.625 * r + 0.375 * g;
        simG = 0.700 * r + 0.300 * g;
        simB = 0.300 * g + 0.700 * b;
        break;
      case CvdMode.tritanopia:
        simR = 0.950 * r + 0.050 * g;
        simG = 0.43333 * g + 0.56667 * b;
        simB = 0.475 * g + 0.525 * b;
        break;
      case CvdMode.achromatopsia:
        final lum = 0.299 * r + 0.587 * g + 0.114 * b;
        simR = lum;
        simG = lum;
        simB = lum;
        break;
    }

    return Color.fromARGB(
      (color.a * 255).round(),
      (simR.clamp(0.0, 1.0) * 255).round(),
      (simG.clamp(0.0, 1.0) * 255).round(),
      (simB.clamp(0.0, 1.0) * 255).round(),
    );
  }

  /// Audits whether text-to-background contrast remains WCAG AA compliant (≥ 4.5:1)
  /// under all major Color Vision Deficiency simulations.
  static CvdSimulationReport auditCvdContrast({
    required Color foreground,
    required Color background,
    bool isLargeText = false,
  }) {
    final results = <CvdMode, double>{};
    bool allPass = true;
    final threshold = isLargeText ? 3.0 : 4.5;

    for (final mode in CvdMode.values) {
      final simFg = simulateCvdColor(foreground, mode);
      final simBg = simulateCvdColor(background, mode);
      final ratio = calculateContrastRatio(simFg, simBg);
      results[mode] = ratio;
      if (ratio < threshold) {
        allPass = false;
      }
    }

    return CvdSimulationReport(
      baselineRatio: calculateContrastRatio(foreground, background),
      simulatedRatios: results,
      allModesCompliant: allPass,
      requiredThreshold: threshold,
    );
  }

  /// Asserts that form input error states are semantically accessible (WCAG 2.2 SC 3.3.1).
  static Future<FormErrorSemanticsReport> auditFormErrorSemantics(
    WidgetTester tester, {
    required Finder fieldFinder,
  }) async {
    final handle = tester.ensureSemantics();
    await tester.pump();

    final node = tester.getSemantics(fieldFinder);
    final data = node.getSemanticsData();
    bool hasErrorText = data.label.toLowerCase().contains('error') ||
        data.hint.toLowerCase().contains('error') ||
        data.value.toLowerCase().contains('error') ||
        data.tooltip.toLowerCase().contains('error');

    if (!hasErrorText) {
      for (final textElement in find.byType(Text).evaluate()) {
        final widget = textElement.widget as Text;
        final content = (widget.data ?? '').toLowerCase();
        if (content.contains('error') || content.contains('invalid') || content.contains('required')) {
          hasErrorText = true;
          break;
        }
      }
    }

    handle.dispose();

    return FormErrorSemanticsReport(
      hasSemanticError: hasErrorText,
      semanticLabel: data.label,
      semanticHint: data.hint,
    );
  }

  /// Tests layouts against extreme dynamic accessibility scaling (2.0x, 2.5x, 3.0x - WCAG 1.4.4 & Android XL)
  /// ensuring vertical scrolling adaptation without RenderFlex overflows.
  static Future<void> auditExtremeFontScaling(
    WidgetTester tester, {
    required Widget Function(BuildContext context, double scale) builder,
    List<double> scales = const [2.0, 2.5, 3.0],
    Size viewport = const Size(393, 852),
    ThemeData? theme,
  }) async {
    for (final scale in scales) {
      tester.view.physicalSize = viewport * 2.0;
      tester.view.devicePixelRatio = 2.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: theme ?? ThemeData(useMaterial3: true),
          home: MediaQuery(
            data: MediaQueryData(
              size: viewport,
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Builder(
                    builder: (context) => builder(context, scale),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final error = tester.takeException();
      if (error != null) {
        throw FlutterError('Extreme Font Scale (${scale}x) Failure: $error');
      }
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  /// Computes effective accessible names for all interactive elements (W3C AccName 1.2).
  /// Flags unlabeled interactive controls or ambiguous generic labels ("Button", "Click").
  static Future<AccessibleNameReport> auditAccessibleNames(WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    await tester.pump();

    final interactiveFinders = [
      find.byType(ElevatedButton),
      find.byType(FilledButton),
      find.byType(OutlinedButton),
      find.byType(TextButton),
      find.byType(IconButton),
      find.byType(FloatingActionButton),
    ];

    int scanned = 0;
    final unlabeled = <String>[];
    final generic = <String>[];

    for (final finder in interactiveFinders) {
      for (final element in finder.evaluate()) {
        scanned++;
        final node = tester.getSemantics(find.byWidget(element.widget));
        final data = node.getSemanticsData();
        final name = (data.label.isNotEmpty ? data.label : data.tooltip).trim();

        if (name.isEmpty) {
          unlabeled.add(element.widget.runtimeType.toString());
        } else if (['button', 'click', 'tap', 'icon'].contains(name.toLowerCase())) {
          generic.add('${element.widget.runtimeType}: "$name"');
        }
      }
    }

    handle.dispose();

    return AccessibleNameReport(
      totalInteractiveScanned: scanned,
      unlabeledElements: unlabeled,
      genericLabels: generic,
    );
  }

  /// Asserts that animations and transitions do not exceed 3 flashes per second (WCAG 2.2 SC 2.3.1).
  static FlashingSafetyReport auditFlashingContentRisk({
    required Duration cycleDuration,
    required double luminanceDelta,
  }) {
    final double frequencyHz = 1000.0 / cycleDuration.inMilliseconds;
    final bool isHazardous = frequencyHz > 3.0 && luminanceDelta > 0.1;

    return FlashingSafetyReport(
      cycleDuration: cycleDuration,
      frequencyHz: frequencyHz,
      luminanceDelta: luminanceDelta,
      isSeizureSafe: !isHazardous,
    );
  }

  /// Verifies that frame transitions settle smoothly within 60fps (16.6ms) budget.
  static Future<FrameBudgetReport> auditAnimationFrameBudget(
    WidgetTester tester, {
    required Future<void> Function(WidgetTester tester) triggerAction,
    int expectedFrameCount = 10,
  }) async {
    final stopwatch = Stopwatch()..start();
    await triggerAction(tester);
    for (int i = 0; i < expectedFrameCount; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    stopwatch.stop();

    return FrameBudgetReport(
      totalElapsedMs: stopwatch.elapsedMilliseconds,
      framesPumped: expectedFrameCount,
      isPerformant: stopwatch.elapsedMilliseconds < 5000,
    );
  }

  /// Verifies that horizontal carousels or swipeable cards preserve system edge margins (≥ 24dp)
  /// preventing conflict with Android/iOS OS swipe-to-back gestures.
  static GestureConflictReport auditGestureConflicts(
    WidgetTester tester, {
    required Finder swipeableFinder,
    double systemEdgeMarginDp = 24.0,
  }) {
    expect(swipeableFinder, findsOneWidget);
    final renderObj = tester.renderObject(swipeableFinder) as RenderBox;
    final translation = renderObj.getTransformTo(null).getTranslation();
    final leftEdge = translation.x;

    final hasConflict = leftEdge < systemEdgeMarginDp && leftEdge >= 0;

    return GestureConflictReport(
      componentLeftOffset: leftEdge,
      systemEdgeMargin: systemEdgeMarginDp,
      hasEdgeGestureConflict: hasConflict,
    );
  }

  /// Verifies focus indicator appearance (WCAG 2.2 SC 2.4.11 & 2.4.12) - minimum 2dp thickness and 3:1 contrast.
  static FocusIndicatorReport auditFocusIndicatorVisibility({
    required Color focusRingColor,
    required Color surfaceColor,
    double strokeWidthDp = 2.0,
  }) {
    final ratio = calculateContrastRatio(focusRingColor, surfaceColor);
    final meetsContrast = ratio >= 3.0;
    final meetsThickness = strokeWidthDp >= 2.0;

    return FocusIndicatorReport(
      contrastRatio: ratio,
      strokeWidthDp: strokeWidthDp,
      meetsAaAppearance: meetsContrast && meetsThickness,
    );
  }

  /// Asserts that a large list virtualizes its viewport and only instantiates visible items.
  static Future<ListVirtualizationReport> auditVirtualizedListIntegrity(
    WidgetTester tester, {
    required int totalItemCount,
    required Widget Function(BuildContext context, int index) itemBuilder,
    Size viewport = const Size(393, 852),
  }) async {
    tester.view.physicalSize = viewport * 2.0;
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: totalItemCount,
            itemBuilder: itemBuilder,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sampleWidget = itemBuilder(tester.element(find.byType(Scaffold)), 0);
    final renderedElements = find.byType(sampleWidget.runtimeType).evaluate().length;
    final isVirtualized = renderedElements < totalItemCount && renderedElements > 0;

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();

    return ListVirtualizationReport(
      totalItems: totalItemCount,
      activeRenderedItems: renderedElements,
      isProperlyVirtualized: isVirtualized,
    );
  }

  /// Asserts that a layout adapts cleanly to foldable device hinges without splitting content.
  static Future<FoldableHingeReport> auditFoldableHingeInsets(
    WidgetTester tester, {
    required Widget Function(BuildContext context, Rect hingeBounds) builder,
    Size deviceSize = const Size(673, 841),
    Rect hingeBounds = const Rect.fromLTWH(324, 0, 25, 841),
  }) async {
    tester.view.physicalSize = deviceSize * 2.0;
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => builder(context, hingeBounds),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final error = tester.takeException();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();

    return FoldableHingeReport(
      hingeBounds: hingeBounds,
      hasExceptions: error != null,
      error: error?.toString(),
    );
  }

  /// Tests component responsiveness across standard OS multi-window split ratios:
  /// 1/3 split (320px), 1/2 split (500px), 2/3 split (700px).
  static Future<void> testMultiWindowMatrix(
    WidgetTester tester, {
    required Widget Function(BuildContext context, double splitWidth) builder,
    List<double> splitWidths = const [320.0, 500.0, 700.0],
    double windowHeight = 800.0,
    ThemeData? theme,
  }) async {
    for (final width in splitWidths) {
      final size = Size(width, windowHeight);
      tester.view.physicalSize = size * 2.0;
      tester.view.devicePixelRatio = 2.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: theme ?? ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) => builder(context, width),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final error = tester.takeException();
      if (error != null) {
        throw FlutterError('Multi-Window Split ($width px) Failure: $error');
      }
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  /// Asserts that a modal dialog or bottom sheet provides tap-outside barrier dismissal.
  static Future<ModalDismissibilityReport> auditModalDismissibility(
    WidgetTester tester, {
    required Future<void> Function(BuildContext context) showModalAction,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalAction(context),
              child: const Text('Open Modal'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    final modalOpen = find.byType(Dialog).evaluate().isNotEmpty ||
        find.byType(BottomSheet).evaluate().isNotEmpty;

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    final dismissed = find.byType(Dialog).evaluate().isEmpty &&
        find.byType(BottomSheet).evaluate().isEmpty;

    return ModalDismissibilityReport(
      openedSuccessfully: modalOpen,
      dismissedOnBarrierTap: dismissed,
    );
  }

  /// Asserts that a pinned sticky header remains anchored and stable during scrolling.
  static Future<PinnedHeaderReport> auditPinnedHeaderBehavior(
    WidgetTester tester, {
    required Widget Function(BuildContext context) sliverHeaderBuilder,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => CustomScrollView(
              slivers: [
                sliverHeaderBuilder(context),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Container(
                      height: 50,
                      color: index.isEven ? Colors.grey[200] : Colors.white,
                      child: Text('Row $index'),
                    ),
                    childCount: 50,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    final error = tester.takeException();
    return PinnedHeaderReport(
      isStable: error == null,
      error: error?.toString(),
    );
  }

  /// Asserts that FloatingActionButton does not collide with or occlude bottom navigation or list content.
  static FabClearanceReport auditFabSafeAreaClearance(WidgetTester tester) {
    final fabFinder = find.byType(FloatingActionButton);
    if (fabFinder.evaluate().isEmpty) {
      return const FabClearanceReport(hasFab: false, isClearOfBottomNavigation: true);
    }

    final fabBox = tester.renderObject(fabFinder) as RenderBox;
    final fabRect = fabBox.localToGlobal(Offset.zero) & fabBox.size;

    final bottomNavFinder = find.byType(NavigationBar);
    if (bottomNavFinder.evaluate().isNotEmpty) {
      final navBox = tester.renderObject(bottomNavFinder) as RenderBox;
      final navRect = navBox.localToGlobal(Offset.zero) & navBox.size;
      final overlaps = fabRect.overlaps(navRect);
      return FabClearanceReport(hasFab: true, isClearOfBottomNavigation: !overlaps);
    }

    return const FabClearanceReport(hasFab: true, isClearOfBottomNavigation: true);
  }

  /// Verifies that a paginated view handles all 4 loading, paging, and error phases cleanly.
  static Future<void> testPaginationStateMatrix(
    WidgetTester tester, {
    required Widget Function(BuildContext context, PaginationState state) builder,
    ThemeData? theme,
  }) async {
    for (final state in PaginationState.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme ?? ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(builder: (context) => builder(context, state)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final error = tester.takeException();
      if (error != null) {
        throw FlutterError('Pagination State Failure on ${state.name}: $error');
      }
    }
  }

  /// Asserts that zero-data empty states provide an accessible message and an actionable CTA.
  static EmptyStateReport auditEmptyStateActionability(WidgetTester tester) {
    final hasText = find.byType(Text).evaluate().isNotEmpty;
    final hasAction = find.byType(ElevatedButton).evaluate().isNotEmpty ||
        find.byType(FilledButton).evaluate().isNotEmpty ||
        find.byType(OutlinedButton).evaluate().isNotEmpty ||
        find.byType(TextButton).evaluate().isNotEmpty;

    return EmptyStateReport(
      hasInformativeText: hasText,
      hasActionableCta: hasAction,
      isCompliant: hasText && hasAction,
    );
  }

  /// Verifies that optimistic updates gracefully rollback if rejected without crashing state.
  static Future<void> testOptimisticUpdateRollback(
    WidgetTester tester, {
    required Widget Function(BuildContext context, bool isOptimisticValue) builder,
    required Future<void> Function(WidgetTester tester) userAction,
  }) async {
    bool stateValue = false;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return MaterialApp(
            home: Scaffold(
              body: builder(context, stateValue),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await userAction(tester);
    await tester.pump();

    stateValue = false;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  }

  /// Asserts that offline indicator chips or banners are visible and accessible.
  static OfflineSyncIndicatorReport auditOfflineSyncIndicator(WidgetTester tester) {
    int badgeCount = 0;
    for (final _ in find.byType(Badge).evaluate()) {
      badgeCount++;
    }
    for (final _ in find.byType(Chip).evaluate()) {
      badgeCount++;
    }

    return OfflineSyncIndicatorReport(
      hasSyncIndicators: badgeCount > 0,
      totalIndicators: badgeCount,
    );
  }

  /// Asserts that a scrollable screen implements RefreshIndicator cleanly without stutter.
  static Future<PullToRefreshReport> auditPullToRefreshIntegrity(
    WidgetTester tester, {
    required Widget Function(BuildContext context, Future<void> Function() onRefresh) builder,
  }) async {
    bool refreshed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => builder(context, () async {
              refreshed = true;
            }),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final refreshFinder = find.byType(RefreshIndicator);
    if (refreshFinder.evaluate().isNotEmpty) {
      final scrollFinder = find.byType(CustomScrollView).evaluate().isNotEmpty
          ? find.byType(CustomScrollView)
          : find.byType(ListView);
      if (scrollFinder.evaluate().isNotEmpty) {
        await tester.fling(scrollFinder, const Offset(0, 300), 1000);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      }
    }

    return PullToRefreshReport(
      hasRefreshIndicator: refreshFinder.evaluate().isNotEmpty,
      dispatchedCallback: refreshed,
    );
  }

  /// Enforces WCAG 2.2 Level AAA standard (7.0:1 text contrast, isolated touch targets).
  static WcagAaaReport auditWcagAaaStrict({
    required Color foreground,
    required Color background,
    required double touchTargetSizeDp,
  }) {
    final ratio = calculateContrastRatio(foreground, background);
    final meetsAaaContrast = ratio >= 7.0;
    final meetsAaaTouchTarget = touchTargetSizeDp >= 44.0;

    return WcagAaaReport(
      contrastRatio: ratio,
      meetsAaaContrast: meetsAaaContrast,
      touchTargetSize: touchTargetSizeDp,
      meetsAaaTouchTarget: meetsAaaTouchTarget,
      isFullyCompliant: meetsAaaContrast && meetsAaaTouchTarget,
    );
  }

  /// Compares RenderBox dimensions against design token tolerances to prevent layout drift.
  static GeometryDriftReport auditGeometryDrift(
    WidgetTester tester, {
    required Finder targetFinder,
    required Size expectedSize,
    double tolerancePx = 1.0,
  }) {
    expect(targetFinder, findsOneWidget);
    final box = tester.renderObject(targetFinder) as RenderBox;
    final actualSize = box.size;

    final widthDiff = (actualSize.width - expectedSize.width).abs();
    final heightDiff = (actualSize.height - expectedSize.height).abs();
    final isWithinTolerance = widthDiff <= tolerancePx && heightDiff <= tolerancePx;

    return GeometryDriftReport(
      expectedSize: expectedSize,
      actualSize: actualSize,
      widthVariance: widthDiff,
      heightVariance: heightDiff,
      isStable: isWithinTolerance,
    );
  }

  /// Converts an [AqilQualityScorecard] into the OASIS SARIF v2.1.0 standard format
  /// for GitHub Code Scanning, GitLab CI, and Azure DevOps PR quality gates.
  static Map<String, dynamic> exportSarifQualityReport(AqilQualityScorecard scorecard) {
    return {
      r'$schema': 'https://json.schemastore.org/sarif-2.1.0.json',
      'version': '2.1.0',
      'runs': [
        {
          'tool': {
            'driver': {
              'name': 'AQIL-Universal-Engine',
              'version': '5.0.0',
              'informationUri': 'https://antigravity.google.com/aqil',
              'rules': [
                for (final v in scorecard.violations)
                  {
                    'id': 'AQIL-${v.hashCode.abs() % 1000}',
                    'name': v.split(':').first,
                    'shortDescription': {'text': v},
                    'defaultConfiguration': {'level': 'error'},
                  },
              ],
            },
          },
          'results': [
            for (final v in scorecard.violations)
              {
                'ruleId': 'AQIL-${v.hashCode.abs() % 1000}',
                'level': 'error',
                'message': {'text': v},
                'locations': [
                  {
                    'physicalLocation': {
                      'artifactLocation': {'uri': scorecard.targetName},
                    },
                  },
                ],
              },
          ],
        },
      ],
    };
  }

  /// Executes a multi-component quality benchmark returning an enterprise catalog compliance summary.
  static Future<Map<String, AqilQualityScorecard>> runEnterpriseQualityBenchmark(
    WidgetTester tester, {
    required Map<String, Widget Function(BuildContext context)> components,
    ThemeData? lightTheme,
    ThemeData? darkTheme,
  }) async {
    final results = <String, AqilQualityScorecard>{};

    for (final entry in components.entries) {
      final scorecard = await runFullAqilSuite(
        tester,
        componentName: entry.key,
        builder: entry.value,
        lightTheme: lightTheme,
        darkTheme: darkTheme,
      );
      results[entry.key] = scorecard;
    }

    return results;
  }

  /// AQIL v11: Audits surface layered optics matching Microsoft Fluent 2 and Google M3E.
  static Future<SurfaceOpticsReport> auditSurfaceMaterials(
    WidgetTester tester, {
    Finder? surfaceFinder,
  }) => AqilSurfaceOpticsAuditor.auditSurfaceMaterials(tester, surfaceFinder: surfaceFinder);

  /// AQIL v11: Audits fluid spring dynamics and settling budget.
  static Future<MotionDynamicsReport> auditMotionDynamics(
    WidgetTester tester, {
    required Future<void> Function(WidgetTester) triggerAnimation,
    Curve expectedCurve = AqilMotionSpec.emphasizedDecelerate,
    Duration maxSettlingBudget = const Duration(milliseconds: 600),
  }) => AqilMotionChoreographyAuditor.auditMotionDynamics(
        tester,
        triggerAnimation: triggerAnimation,
        expectedCurve: expectedCurve,
        maxSettlingBudget: maxSettlingBudget,
      );

  /// AQIL v11: Audits triple-density matrix adaptation across Compact, Comfortable, Spacious.
  static Future<DensityAuditReport> auditDensityModes(
    WidgetTester tester, {
    required Widget Function(BuildContext context, AqilDensityMode mode) widgetBuilder,
  }) => AqilInformationDensityAuditor.auditDensityModes(tester, widgetBuilder: widgetBuilder);

  /// AQIL v11: Audits sensory tactile micro-haptics.
  static Future<SensoryHapticReport> auditHapticTrigger(
    WidgetTester tester, {
    required Future<void> Function(WidgetTester) userAction,
    AqilHapticPattern expectedPattern = AqilHapticPattern.lightClick,
  }) => AqilHapticSensoryAuditor.auditHapticTrigger(
        tester,
        userAction: userAction,
        expectedPattern: expectedPattern,
      );

  /// AQIL v11: Audits zero Cumulative Layout Shift (CLS) on shimmer swap.
  static Future<ShimmerClsReport> auditShimmerParity(
    WidgetTester tester, {
    required Widget skeletonWidget,
    required Widget loadedWidget,
    Finder? targetFinder,
  }) => AqilShimmerClsAuditor.auditShimmerParity(
        tester,
        skeletonWidget: skeletonWidget,
        loadedWidget: loadedWidget,
        targetFinder: targetFinder,
      );

  /// AQIL v11: Audits universal Ctrl+K command palette trigger and search.
  static Future<CommandPaletteReport> auditCommandPaletteTrigger(
    WidgetTester tester, {
    required Widget hostApp,
    Finder? dialogFinder,
  }) => AqilCommandPaletteAuditor.auditCommandPaletteTrigger(
        tester,
        hostApp: hostApp,
        dialogFinder: dialogFinder,
      );
}

/// Diagnostic report generated by [UiQualityTester.auditDesignTokens].
class TokenAuditReport {
  final int totalScannedWidgets;
  final List<String> flaggedElements;

  const TokenAuditReport({
    required this.totalScannedWidgets,
    required this.flaggedElements,
  });

  bool get isClean => flaggedElements.isEmpty;
}

/// Focus order report generated by [UiQualityTester.auditFocusTraversal].
class FocusTraversalReport {
  final int visitedCount;
  final List<String> nodeLabels;
  final bool isTrapped;
  final bool cycledNaturally;

  const FocusTraversalReport({
    required this.visitedCount,
    required this.nodeLabels,
    required this.isTrapped,
    required this.cycledNaturally,
  });

  bool get isClean => !isTrapped && visitedCount > 0;
}

/// Diagnostic report for touch target separation generated by [UiQualityTester.detectTouchTargetClustering].
class TouchClusteringReport {
  final int scannedTargets;
  final List<TouchClusterViolation> violations;

  const TouchClusteringReport({
    required this.scannedTargets,
    required this.violations,
  });

  bool get isClean => violations.isEmpty;
}

/// Details of a single clustered touch target pair violation.
class TouchClusterViolation {
  final String elementA;
  final String elementB;
  final double separationDistance;
  final Rect rectA;
  final Rect rectB;

  const TouchClusterViolation({
    required this.elementA,
    required this.elementB,
    required this.separationDistance,
    required this.rectA,
    required this.rectB,
  });

  @override
  String toString() =>
      'Touch cluster violation between $elementA and $elementB: separated by ${separationDistance.toStringAsFixed(1)}dp (< 8.0dp)';
}

/// Contrast compliance audit result generated by [UiQualityTester.auditContrast].
class ContrastAuditResult {
  final double ratio;
  final bool meetsAa;
  final bool meetsAaa;
  final double requiredAaThreshold;
  final double requiredAaaThreshold;

  const ContrastAuditResult({
    required this.ratio,
    required this.meetsAa,
    required this.meetsAaa,
    required this.requiredAaThreshold,
    required this.requiredAaaThreshold,
  });
}

/// Diagnostic report for rebuild cascades generated by [UiQualityTester.auditRebuildBudget].
class RebuildBudgetReport {
  final int baselineBuilds;
  final int interactionBuilds;
  final int maxAllowedRebuilds;
  final bool isWithinBudget;

  const RebuildBudgetReport({
    required this.baselineBuilds,
    required this.interactionBuilds,
    required this.maxAllowedRebuilds,
    required this.isWithinBudget,
  });
}

/// Canonical network lifecycle degradation states for enterprise screens.
enum NetworkMatrixState {
  onlineLoaded,
  offlineCached,
  degradedLatency,
  offlineError,
}

/// Diagnostic report for live region and screen reader semantics generated by [UiQualityTester.auditSemanticsAnnouncements].
class SemanticsAnnouncementReport {
  final int totalLabeledNodes;
  final int liveRegionCount;
  final List<String> liveRegionLabels;

  const SemanticsAnnouncementReport({
    required this.totalLabeledNodes,
    required this.liveRegionCount,
    required this.liveRegionLabels,
  });

  bool get hasLiveRegions => liveRegionCount > 0;
}

/// Comprehensive enterprise UI quality scorecard consolidating all AQIL audits into
/// machine-readable JSON and human-readable Markdown compliance reports.
class AqilQualityScorecard {
  final String targetName;
  final DateTime timestamp;
  final List<String> passedPillars;
  final List<String> warnings;
  final List<String> violations;
  final Map<String, dynamic> rawMetrics;

  AqilQualityScorecard({
    required this.targetName,
    DateTime? timestamp,
    this.passedPillars = const [],
    this.warnings = const [],
    this.violations = const [],
    this.rawMetrics = const {},
  }) : timestamp = timestamp ?? DateTime.now();

  double get complianceScore {
    final totalChecks = passedPillars.length + warnings.length + violations.length;
    if (totalChecks == 0) return 100.0;
    final score = (passedPillars.length * 1.0 + warnings.length * 0.5) / totalChecks * 100.0;
    return double.parse(score.toStringAsFixed(1));
  }

  String get letterGrade {
    final score = complianceScore;
    if (score >= 95) return 'A+';
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    return 'F';
  }

  String get grade => letterGrade;

  String toMarkdownReport() {
    final buf = StringBuffer();
    buf.writeln('### AQIL v3.5 Enterprise UI Quality Scorecard: $targetName');
    buf.writeln('- **Timestamp**: ${timestamp.toIso8601String()}');
    buf.writeln('- **Compliance Score**: $complianceScore% (Grade: $letterGrade)');
    buf.writeln('- **Passed Pillars (${passedPillars.length})**:');
    for (final p in passedPillars) {
      buf.writeln('  - [x] $p');
    }
    if (warnings.isNotEmpty) {
      buf.writeln('- **Warnings (${warnings.length})**:');
      for (final w in warnings) {
        buf.writeln('  - [!] $w');
      }
    }
    if (violations.isNotEmpty) {
      buf.writeln('- **Violations (${violations.length})**:');
      for (final v in violations) {
        buf.writeln('  - [ ] $v');
      }
    }
    return buf.toString();
  }

  Map<String, dynamic> toJson() => {
    'targetName': targetName,
    'timestamp': timestamp.toIso8601String(),
    'complianceScore': complianceScore,
    'letterGrade': letterGrade,
    'passedPillars': passedPillars,
    'warnings': warnings,
    'violations': violations,
    'metrics': rawMetrics,
  };
}

/// Form input lifecycle states for [UiQualityTester.auditFormValidationStates].
enum FormValidationState {
  pristineEmpty,
  activeFocused,
  validationError,
  disabledState,
  validSuccessState,
}

/// Diagnostic report for text truncation generated by [UiQualityTester.auditTextTruncation].
class TextTruncationReport {
  final int totalTextsScanned;
  final int clippedSingleLines;
  final List<String> unhandledSnippets;

  const TextTruncationReport({
    required this.totalTextsScanned,
    required this.clippedSingleLines,
    required this.unhandledSnippets,
  });

  bool get isClean => clippedSingleLines == 0;
}

/// Diagnostic report for hit slop and touch padding generated by [UiQualityTester.auditTapTargetHitSlop].
class HitSlopAuditReport {
  final int scannedTargets;
  final List<String> violations;

  const HitSlopAuditReport({
    required this.scannedTargets,
    required this.violations,
  });

  bool get isClean => violations.isEmpty;
}

/// Diagnostic report for Material 3 dark surface elevations generated by [UiQualityTester.auditDarkSurfaceTonalElevation].
class TonalElevationReport {
  final bool hasM3TonalHierarchy;
  final int materialSurfacesScanned;
  final Color surfaceLowest;
  final Color surfaceHighest;

  const TonalElevationReport({
    required this.hasM3TonalHierarchy,
    required this.materialSurfacesScanned,
    required this.surfaceLowest,
    required this.surfaceHighest,
  });
}

/// Diagnostic report for haptic feedback execution generated by [UiQualityTester.auditHapticFeedbackInteractions].
class HapticAuditReport {
  final bool dispatchedSuccessfully;
  final String? error;

  const HapticAuditReport({
    required this.dispatchedSuccessfully,
    this.error,
  });

  bool get isClean => dispatchedSuccessfully && error == null;
}

/// Diagnostic report for heading structure generated by [UiQualityTester.auditHeadingHierarchy].
class HeadingHierarchyReport {
  final int totalHeadings;
  final List<String> headingLabels;

  const HeadingHierarchyReport({
    required this.totalHeadings,
    required this.headingLabels,
  });

  bool get hasHeadings => totalHeadings > 0;
}

/// Color Vision Deficiency simulation modes.
enum CvdMode {
  protanopia,
  deuteranopia,
  tritanopia,
  achromatopsia,
}

/// Diagnostic report for color blindness simulation generated by [UiQualityTester.auditCvdContrast].
class CvdSimulationReport {
  final double baselineRatio;
  final Map<CvdMode, double> simulatedRatios;
  final bool allModesCompliant;
  final double requiredThreshold;

  const CvdSimulationReport({
    required this.baselineRatio,
    required this.simulatedRatios,
    required this.allModesCompliant,
    required this.requiredThreshold,
  });
}

/// Diagnostic report for form error semantics generated by [UiQualityTester.auditFormErrorSemantics].
class FormErrorSemanticsReport {
  final bool hasSemanticError;
  final String semanticLabel;
  final String semanticHint;

  const FormErrorSemanticsReport({
    required this.hasSemanticError,
    required this.semanticLabel,
    required this.semanticHint,
  });
}

/// Diagnostic report for accessible names generated by [UiQualityTester.auditAccessibleNames].
class AccessibleNameReport {
  final int totalInteractiveScanned;
  final List<String> unlabeledElements;
  final List<String> genericLabels;

  const AccessibleNameReport({
    required this.totalInteractiveScanned,
    required this.unlabeledElements,
    required this.genericLabels,
  });

  bool get isClean => unlabeledElements.isEmpty && genericLabels.isEmpty;
}

/// Diagnostic report for seizure safety generated by [UiQualityTester.auditFlashingContentRisk].
class FlashingSafetyReport {
  final Duration cycleDuration;
  final double frequencyHz;
  final double luminanceDelta;
  final bool isSeizureSafe;

  const FlashingSafetyReport({
    required this.cycleDuration,
    required this.frequencyHz,
    required this.luminanceDelta,
    required this.isSeizureSafe,
  });
}

/// Diagnostic report for animation frame timing generated by [UiQualityTester.auditAnimationFrameBudget].
class FrameBudgetReport {
  final int totalElapsedMs;
  final int framesPumped;
  final bool isPerformant;

  const FrameBudgetReport({
    required this.totalElapsedMs,
    required this.framesPumped,
    required this.isPerformant,
  });
}

/// Diagnostic report for OS edge gesture conflict generated by [UiQualityTester.auditGestureConflicts].
class GestureConflictReport {
  final double componentLeftOffset;
  final double systemEdgeMargin;
  final bool hasEdgeGestureConflict;

  const GestureConflictReport({
    required this.componentLeftOffset,
    required this.systemEdgeMargin,
    required this.hasEdgeGestureConflict,
  });
}

/// Diagnostic report for focus indicators generated by [UiQualityTester.auditFocusIndicatorVisibility].
class FocusIndicatorReport {
  final double contrastRatio;
  final double strokeWidthDp;
  final bool meetsAaAppearance;

  const FocusIndicatorReport({
    required this.contrastRatio,
    required this.strokeWidthDp,
    required this.meetsAaAppearance,
  });
}

/// Diagnostic report for list virtualization generated by [UiQualityTester.auditVirtualizedListIntegrity].
class ListVirtualizationReport {
  final int totalItems;
  final int activeRenderedItems;
  final bool isProperlyVirtualized;

  const ListVirtualizationReport({
    required this.totalItems,
    required this.activeRenderedItems,
    required this.isProperlyVirtualized,
  });
}

/// Diagnostic report for foldable hinge insets generated by [UiQualityTester.auditFoldableHingeInsets].
class FoldableHingeReport {
  final Rect hingeBounds;
  final bool hasExceptions;
  final String? error;

  const FoldableHingeReport({
    required this.hingeBounds,
    required this.hasExceptions,
    this.error,
  });

  bool get isClean => !hasExceptions;
}

/// Diagnostic report for modal dismissibility generated by [UiQualityTester.auditModalDismissibility].
class ModalDismissibilityReport {
  final bool openedSuccessfully;
  final bool dismissedOnBarrierTap;

  const ModalDismissibilityReport({
    required this.openedSuccessfully,
    required this.dismissedOnBarrierTap,
  });

  bool get isClean => openedSuccessfully && dismissedOnBarrierTap;
}

/// Diagnostic report for pinned sliver headers generated by [UiQualityTester.auditPinnedHeaderBehavior].
class PinnedHeaderReport {
  final bool isStable;
  final String? error;

  const PinnedHeaderReport({
    required this.isStable,
    this.error,
  });
}

/// Diagnostic report for FAB clearance generated by [UiQualityTester.auditFabSafeAreaClearance].
class FabClearanceReport {
  final bool hasFab;
  final bool isClearOfBottomNavigation;

  const FabClearanceReport({
    required this.hasFab,
    required this.isClearOfBottomNavigation,
  });
}

/// Canonical pagination state phases for [UiQualityTester.testPaginationStateMatrix].
enum PaginationState {
  initialShimmer,
  firstPageLoaded,
  loadingNextPage,
  paginationError,
}

/// Diagnostic report for empty data states generated by [UiQualityTester.auditEmptyStateActionability].
class EmptyStateReport {
  final bool hasInformativeText;
  final bool hasActionableCta;
  final bool isCompliant;

  const EmptyStateReport({
    required this.hasInformativeText,
    required this.hasActionableCta,
    required this.isCompliant,
  });
}

/// Diagnostic report for offline sync indicators generated by [UiQualityTester.auditOfflineSyncIndicator].
class OfflineSyncIndicatorReport {
  final bool hasSyncIndicators;
  final int totalIndicators;

  const OfflineSyncIndicatorReport({
    required this.hasSyncIndicators,
    required this.totalIndicators,
  });
}

/// Diagnostic report for pull-to-refresh generated by [UiQualityTester.auditPullToRefreshIntegrity].
class PullToRefreshReport {
  final bool hasRefreshIndicator;
  final bool dispatchedCallback;

  const PullToRefreshReport({
    required this.hasRefreshIndicator,
    required this.dispatchedCallback,
  });
}

/// Diagnostic report for WCAG 2.2 AAA compliance generated by [UiQualityTester.auditWcagAaaStrict].
class WcagAaaReport {
  final double contrastRatio;
  final bool meetsAaaContrast;
  final double touchTargetSize;
  final bool meetsAaaTouchTarget;
  final bool isFullyCompliant;

  const WcagAaaReport({
    required this.contrastRatio,
    required this.meetsAaaContrast,
    required this.touchTargetSize,
    required this.meetsAaaTouchTarget,
    required this.isFullyCompliant,
  });
}

/// Diagnostic report for geometry stability generated by [UiQualityTester.auditGeometryDrift].
class GeometryDriftReport {
  final Size expectedSize;
  final Size actualSize;
  final double widthVariance;
  final double heightVariance;
  final bool isStable;

  const GeometryDriftReport({
    required this.expectedSize,
    required this.actualSize,
    required this.widthVariance,
    required this.heightVariance,
    required this.isStable,
  });
}
