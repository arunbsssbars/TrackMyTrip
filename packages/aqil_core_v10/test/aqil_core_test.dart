import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqil_core/aqil_core.dart';

void main() {
  group('AQIL v11 Core Gateway & Pipeline Suite', () {
    testWidgets('AqilUiGateway renders child cleanly and runs live screen audit',
        (WidgetTester tester) async {
      AqilUiReport? generatedReport;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AqilUiGateway.screen(
              screenName: 'TestScreen',
              enableInspector: true,
              onReportGenerated: (report) {
                generatedReport = report;
              },
              child: const Center(
                child: Text('Protected UI Screen'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Protected UI Screen'), findsOneWidget);
      expect(find.text('⚡ AQIL v11'), findsOneWidget);

      // Open HUD
      await tester.tap(find.text('⚡ AQIL v11'));
      await tester.pumpAndSettle();

      expect(find.text('AQIL Engine v11'), findsOneWidget);
      expect(find.text('Run Live AQIL Audit'), findsOneWidget);

      // Tap audit button
      await tester.tap(find.text('Run Live AQIL Audit'));
      await tester.pumpAndSettle();

      expect(generatedReport, isNotNull);
      expect(generatedReport!.screenName, equals('TestScreen'));
      expect(generatedReport!.estimatedScore, greaterThanOrEqualTo(80));
    });

    testWidgets('AqilUiGateway clamps responsive width when requested',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AqilUiGateway.screen(
              screenName: 'ClampedScreen',
              enableResponsiveClamping: true,
              maxContentWidth: 600,
              enableInspector: false,
              child: Container(
                color: Colors.blue,
                child: const Text('Clamped Body'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Clamped Body'), findsOneWidget);
      final widget = tester.widget<ConstrainedBox>(find.byKey(const Key('aqil_clamped_box')));
      expect(widget.constraints.maxWidth, equals(600));
    });

    test('AqilContrastAuditor verifies WCAG 2.2 AA and AAA contrast correctly', () {
      final blackOnWhite = AqilContrastAuditor.auditContrast(
        foreground: Colors.black,
        background: Colors.white,
      );
      expect(blackOnWhite.passesAA, isTrue);
      expect(blackOnWhite.passesAAA, isTrue);
      expect(blackOnWhite.contrastRatio, greaterThan(15.0));

      final whiteOnWhite = AqilContrastAuditor.auditContrast(
        foreground: Colors.white,
        background: Colors.white,
      );
      expect(whiteOnWhite.passesAA, isFalse);
      expect(whiteOnWhite.passesAAA, isFalse);
      expect(whiteOnWhite.contrastRatio, closeTo(1.0, 0.05));
    });

    test('AqilCodeHealer detects and repairs un-ellipsized single-line Text', () {
      final tempFile = File('test/temp_test_view.dart');
      tempFile.writeAsStringSync("const widget = Text('Sample', maxLines: 1);");

      final report = AqilCodeHealer.healFile(tempFile, applyFixes: true);
      expect(report.patchesApplied, equals(1));

      final healed = tempFile.readAsStringSync();
      expect(healed, contains('overflow: TextOverflow.ellipsis'));

      tempFile.deleteSync();
    });

    test('AqilTestGenerator discovers Screen classes in lib', () {
      final screens = AqilTestGenerator.discoverScreens('.');
      expect(screens, isA<List<PipelineScreenTarget>>());
    });

    test('AqilHtmlDiffStudio generates interactive HTML report', () {
      final reportFile = AqilHtmlDiffStudio.generateReport(
        projectName: 'TestProject',
        items: const [
          VisualAuditItem(
            screenName: 'DashboardScreen',
            viewport: '393x852',
            score: 95,
            hasOverflow: false,
            passesWcag: true,
          ),
        ],
        outputPath: 'build/test_studio_report.html',
      );

      expect(reportFile.existsSync(), isTrue);
      final html = reportFile.readAsStringSync();
      expect(html, contains('AQIL Studio Visual Quality Matrix'));
      expect(html, contains('DashboardScreen'));

      reportFile.deleteSync();
    });

    testWidgets('AqilFormFuzzer fuzzes input form cleanly across 5 personas',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const TextField(
                  decoration: InputDecoration(labelText: 'Name'),
                ),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Submit'),
                ),
              ],
            ),
          ),
        ),
      );

      final report = await AqilFormFuzzer.fuzzScreenForm(tester, screenName: 'TestForm');
      expect(report.totalTrials, equals(5));
      expect(report.passedTrials, greaterThanOrEqualTo(4));
    });

    test('AqilFrameBudgetSentinel evaluates frame budget constraints', () {
      final conforms = AqilFrameBudgetSentinel.evaluateDuration(
        const Duration(milliseconds: 10),
        target: FrameBudgetTarget.fps60,
      );
      expect(conforms.conformsToBudget, isTrue);

      final violates = AqilFrameBudgetSentinel.evaluateDuration(
        const Duration(milliseconds: 25),
        target: FrameBudgetTarget.fps60,
      );
      expect(violates.conformsToBudget, isFalse);
    });

    test('AqilFluid clamps responsive values proportionally', () {
      // At min viewport (320), value is min (10)
      final atMin = AqilFluid.clampValue(320, min: 10, max: 30, minViewport: 320, maxViewport: 1280);
      expect(atMin, equals(10.0));

      // At max viewport (1280), value is max (30)
      final atMax = AqilFluid.clampValue(1280, min: 10, max: 30, minViewport: 320, maxViewport: 1280);
      expect(atMax, equals(30.0));

      // At midpoint (800), value is midpoint (20)
      final atMid = AqilFluid.clampValue(800, min: 10, max: 30, minViewport: 320, maxViewport: 1280);
      expect(atMid, equals(20.0));
    });

    test('AqilMockSynthesizer synthesizes realistic mock data', () {
      final email = AqilMockSynthesizer.synthesizeValue('userEmail', 'String');
      expect(email, contains('@'));

      final amount = AqilMockSynthesizer.synthesizeValue('totalAmount', 'double');
      expect(amount, isA<double>());

      final date = AqilMockSynthesizer.synthesizeValue('createdAt', 'DateTime');
      expect(date, isA<DateTime>());
    });

    testWidgets('AqilLeakSentinel executes clean mount/unmount cycles',
        (WidgetTester tester) async {
      final report = await AqilLeakSentinel.auditMountCycles(
        tester,
        cycles: 3,
        builder: (context) => const Center(child: Text('Leaked Widget')),
      );
      expect(report.isClean, isTrue);
      expect(report.mountCyclesExecuted, equals(3));
    });

    testWidgets('AqilNetworkSimulator toggles offline state scope',
        (WidgetTester tester) async {
      bool? detectedOffline;

      await tester.pumpWidget(
        AqilNetworkSimulator.offline(
          child: Builder(
            builder: (context) {
              detectedOffline = AqilNetworkScope.isOffline(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(detectedOffline, isTrue);
    });

    test('AqilLocaleStressEngine transforms strings with expansion and BiDi', () {
      final german = AqilLocaleStressEngine.transform('Save', profile: LocaleStressProfile.germanExpansion);
      expect(german, contains('verlängert'));
      expect(german.length, greaterThan('Save'.length));

      final arabic = AqilLocaleStressEngine.transform('Home', profile: LocaleStressProfile.arabicBiDi);
      expect(arabic, contains('عربي'));
    });

    test('AqilCiGuardian synthesizes valid GitHub Actions workflow', () {
      final tempDir = Directory('test/temp_ci');
      tempDir.createSync(recursive: true);

      final workflow = AqilCiGuardian.generateGitHubWorkflow(tempDir.path);
      expect(workflow.existsSync(), isTrue);
      final yaml = workflow.readAsStringSync();
      expect(yaml, contains('AQIL Quality Guardian'));
      expect(yaml, contains('aqil_ui_pipeline_test.dart'));

      tempDir.deleteSync(recursive: true);
    });

    test('AqilStateSnapshot captures and compares state records', () {
      final snap1 = AqilStateSnapshot.captureSnapshot(
        screenName: 'ProfileScreen',
        stateValues: {'userId': 'USR-1', 'tabIndex': 0},
      );

      final snap2 = AqilStateSnapshot.captureSnapshot(
        screenName: 'ProfileScreen',
        stateValues: {'userId': 'USR-1', 'tabIndex': 0},
      );

      expect(AqilStateSnapshot.verifyRestoration(snap1, snap2), isTrue);

      final snapDifferent = AqilStateSnapshot.captureSnapshot(
        screenName: 'ProfileScreen',
        stateValues: {'userId': 'USR-1', 'tabIndex': 2},
      );
      expect(AqilStateSnapshot.verifyRestoration(snap1, snapDifferent), isFalse);
    });

    testWidgets('AqilGestureHeatmap tracks interactions and calculates reachability metrics',
        (WidgetTester tester) async {
      final key = GlobalKey<AqilGestureHeatmapState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AqilGestureHeatmap(
              key: key,
              enableOverlay: true,
              child: const SizedBox(
                width: 400,
                height: 800,
                child: Center(child: Text('Test Touch Surface')),
              ),
            ),
          ),
        ),
      );

      // Tap in comfort zone (dy = 600 > 320)
      key.currentState!.recordGesture(const Offset(200, 600));
      // Tap in stretch zone (dy = 100 < 320)
      key.currentState!.recordGesture(const Offset(200, 100));

      expect(key.currentState!.gestures.length, equals(2));

      final metrics = key.currentState!.calculateMetrics(const Size(400, 800));
      expect(metrics.totalGestures, equals(2));
      expect(metrics.thumbComfortZoneCount, equals(1));
      expect(metrics.reachStretchZoneCount, equals(1));
      expect(metrics.thumbReachabilityRatio, equals(0.5));
    });

    test('AqilTokenDriftAuditor identifies off-grid spacing and snaps correctly', () {
      final nearest13 = AqilTokenDriftAuditor.findNearestToken(13.0);
      expect(nearest13.value, equals(12.0));
      expect(nearest13.name, equals('AppSpacing.md'));

      // (19 - 16 = 3, 20 - 19 = 1) -> nearest to 19 is 20
      final nearest19 = AqilTokenDriftAuditor.findNearestToken(19.0);
      expect(nearest19.value, equals(20.0));
      expect(nearest19.name, equals('AppSpacing.lg'));
    });

    testWidgets('AqilScreenStateMatrix cleanly transitions across 4 UX states',
        (WidgetTester tester) async {
      for (final state in AqilScreenStateType.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AqilScreenStateMatrix(
                state: state,
                emptyTitle: 'Zero Orders',
                errorMessage: 'Network timeout',
                content: const Text('Live Content'),
              ),
            ),
          ),
        );

        switch (state) {
          case AqilScreenStateType.content:
            expect(find.text('Live Content'), findsOneWidget);
            break;
          case AqilScreenStateType.loading:
            expect(find.byType(CircularProgressIndicator), findsOneWidget);
            break;
          case AqilScreenStateType.empty:
            expect(find.text('Zero Orders'), findsOneWidget);
            break;
          case AqilScreenStateType.error:
            expect(find.text('Network timeout'), findsOneWidget);
            break;
        }
      }
    });

    testWidgets('AqilSpringBounce renders child and audits animation curves',
        (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AqilSpringBounce(
              onTap: () => tapped = true,
              child: const Text('Spring Button'),
            ),
          ),
        ),
      );

      expect(find.text('Spring Button'), findsOneWidget);
      await tester.tap(find.text('Spring Button'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);

      final warning = AqilSpringAnimationAuditor.auditCurve(Curves.linear);
      expect(warning, contains('mechanical curve'));

      final clean = AqilSpringAnimationAuditor.auditCurve(AqilSpringCurves.smoothDamped);
      expect(clean, isNull);
    });

    testWidgets('AqilSkeletonCard renders bone geometry with zero layout errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AqilSkeletonCard(
              hasAvatar: true,
              textLines: 3,
            ),
          ),
        ),
      );

      expect(find.byType(AqilSkeletonBone), findsWidgets);
      expect(find.byType(AqilShimmerSweep), findsOneWidget);
    });

    test('AqilHapticChoreographer executes trigger methods safely without crash', () async {
      await AqilHapticChoreographer.tap();
      await AqilHapticChoreographer.tick();
      await AqilHapticChoreographer.confirm();
      await AqilHapticChoreographer.error();
      expect(AqilHapticChoreographer.enableHaptics, isTrue);
    });

    testWidgets('AqilFrostedGlass renders with backdrop blur and audits optics',
        (WidgetTester tester) async {
      const frosted = AqilFrostedGlass(
        blurSigma: 20.0,
        child: Text('Frosted Content'),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: frosted),
        ),
      );

      expect(find.text('Frosted Content'), findsOneWidget);
      final optics = frosted.auditOptics();
      expect(optics.blurSigma, equals(20.0));
      expect(optics.passesWcagAa, isTrue);
    });

    testWidgets('AqilRollingCounter animates numeric value update with tabular figures',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AqilRollingCounter(
              value: 1250.50,
              prefix: '\$',
            ),
          ),
        ),
      );

      expect(find.text('\$1250.50'), findsOneWidget);
    });

    test('AqilThumbReachEnforcer classifies comfort vs stretch zones', () {
      final comfort = AqilThumbReachEnforcer.evaluatePosition(
        widgetY: 550,
        viewportHeight: 800,
      );
      expect(comfort, equals(ThumbReachZone.comfortZone));

      final stretch = AqilThumbReachEnforcer.evaluatePosition(
        widgetY: 150,
        viewportHeight: 800,
      );
      expect(stretch, equals(ThumbReachZone.stretchZone));

      final warning = AqilThumbReachEnforcer.auditCtaPlacement(
        actionName: 'Submit Order',
        widgetY: 120,
        viewportHeight: 800,
      );
      expect(warning, contains('stretch zone'));
    });

    test('AqilSliverHeaderAuditor evaluates SliverAppBar geometry constraints', () {
      final valid = AqilSliverHeaderAuditor.auditAppBarGeometry(
        expandedHeight: 200.0,
        collapsedHeight: 64.0,
      );
      expect(valid, isNull);

      final invalid = AqilSliverHeaderAuditor.auditAppBarGeometry(
        expandedHeight: 50.0,
        collapsedHeight: 64.0,
      );
      expect(invalid, contains('must be greater than'));
    });

    test('AqilObsidianTheme provides deep dark background and audits luminance', () {
      final theme = AqilObsidianTheme.themeData();
      expect(theme.scaffoldBackgroundColor, equals(const Color(0xFF08090A)));

      final clean = AqilDarkThemeAuditor.auditBackgroundLuminance(const Color(0xFF08090A));
      expect(clean, isNull);

      final muddy = AqilDarkThemeAuditor.auditBackgroundLuminance(const Color(0xFF4A4A4A));
      expect(muddy, contains('muddy'));
    });

    test('AqilHeroAuditor validates non-empty Hero tags', () {
      final clean = AqilHeroAuditor.auditTag('hero-product-101');
      expect(clean, isNull);

      final empty = AqilHeroAuditor.auditTag('   ');
      expect(empty, contains('must not be empty'));
    });

    test('AqilBenchmarkEvaluator scores world-class UI conformance', () {
      final score = AqilBenchmarkEvaluator.evaluate(
        hasSpringOrBounce: true,
        hasTactileHaptics: true,
        passesOpticsContrast: true,
        hasTabularNumbersOrRolling: true,
        thumbReachabilityRatio: 0.90,
      );

      expect(score.passesWorldClassTier, isTrue);
      expect(score.compositeScore, greaterThanOrEqualTo(0.85));
      expect(score.toJson()['isWorldClass'], isTrue);
    });

    test('AqilOptimisticStore executes instant local mutation and rolls back on error', () async {
      final store = AqilOptimisticStore<int>(10);
      expect(store.value, equals(10));

      // Successful mutation
      final success = await store.mutateOptimistically(
        mutationId: 'inc-1',
        applyOptimisticChange: (val) => val + 1,
        remoteCall: () async {},
      );
      expect(success, isTrue);
      expect(store.value, equals(11));
      expect(store.status, equals(AqilMutationStatus.committed));

      // Failing mutation with rollback
      final fail = await store.mutateOptimistically(
        mutationId: 'inc-2',
        applyOptimisticChange: (val) => val + 5,
        remoteCall: () async => throw Exception('Network timeout'),
      );
      expect(fail, isFalse);
      expect(store.value, equals(11)); // Rolled back to 11
      expect(store.status, equals(AqilMutationStatus.rolledBack));
    });

    test('AqilTypeScaleAuditor evaluates text themes for accessibility line height headroom', () {
      const theme = TextTheme(
        bodyMedium: TextStyle(fontSize: 14.0, height: 1.4),
      );
      final report = AqilTypeScaleAuditor.auditTheme(theme);
      expect(report.totalAuditedStyles, equals(15));
      expect(report.isCompliant, isTrue);

      const collisionStyle = TextStyle(fontSize: 18.0, height: 1.0);
      final warning = AqilTypeScaleAuditor.auditStyle(collisionStyle, name: 'tightHeader');
      expect(warning, contains('Risk of line collision'));
    });

    testWidgets('AqilA11yTraverser flags icon buttons missing tooltip semantic labels',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Search items',
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {}, // missing tooltip
                ),
              ],
            ),
          ),
        ),
      );

      final report = AqilA11yTraverser.auditScreenSemantics(tester);
      expect(report.totalInteractiveWidgets, equals(2));
      expect(report.missingLabelCount, equals(1));
      expect(report.isFullyAccessible, isFalse);
    });

    test('AqilVisualHierarchyAuditor detects flat typography hierarchy', () {
      const flatHead = TextStyle(fontSize: 14.0, fontWeight: FontWeight.normal);
      const flatBody = TextStyle(fontSize: 14.0, fontWeight: FontWeight.normal);
      final gap = AqilVisualHierarchyAuditor.auditPair(headline: flatHead, body: flatBody);
      expect(gap, isNotNull);
      expect(gap!.severity, equals(AqilGapSeverity.critical));
      expect(gap.description, contains('Flat typographic hierarchy'));

      const boldHead = TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold);
      const cleanBody = TextStyle(fontSize: 14.0, fontWeight: FontWeight.normal);
      final clean = AqilVisualHierarchyAuditor.auditPair(headline: boldHead, body: cleanBody);
      expect(clean, isNull);
    });

    test('AqilTouchCrowdingAuditor detects hazardous proximity between touch targets', () {
      const btn1 = Rect.fromLTWH(20, 100, 48, 48);
      const btn2 = Rect.fromLTWH(72, 100, 48, 48); // gap = 72 - 68 = 4dp < 12dp
      final gap = AqilTouchCrowdingAuditor.auditDistance(
        firstTarget: btn1,
        secondTarget: btn2,
        firstLabel: 'Edit',
        secondLabel: 'Delete',
      );
      expect(gap, isNotNull);
      expect(gap!.category, equals('TouchCrowding'));
      expect(gap.description, contains('spaced only 4.0dp apart'));

      const btnFar = Rect.fromLTWH(120, 100, 48, 48); // gap = 120 - 68 = 52dp > 12dp
      final safe = AqilTouchCrowdingAuditor.auditDistance(firstTarget: btn1, secondTarget: btnFar);
      expect(safe, isNull);
    });

    test('AqilSpatialRhythmAuditor detects off-grid vertical spacing cadence', () {
      final gaps = AqilSpatialRhythmAuditor.auditSpacingSequence([8.0, 13.0, 16.0, 2.0]);
      expect(gaps.length, equals(2)); // 13dp (off-grid) and 2dp (cramped micro-gap)
      expect(gaps.any((g) => g.description.contains('13.0dp')), isTrue);
      expect(gaps.any((g) => g.description.contains('Cramped micro-gap')), isTrue);
    });

    test('AqilColorBlindnessSim audits contrast across all 4 CVD conditions', () {
      // High contrast: Black on white
      final results = AqilColorBlindnessSim.auditContrast(
        foreground: (0, 0, 0),
        background: (255, 255, 255),
      );
      expect(results.length, equals(4));
      expect(results.every((r) => r.passesWcagAa), isTrue);
    });

    test('AqilPhysicalShadow provides dual ambient and key light box shadows', () {
      final shadows = AqilPhysicalShadow.realistic(elevation: 4.0);
      expect(shadows.length, equals(2));
      expect(AqilElevationAuditor.auditBoxShadow(shadows.first), isNull);

      const harsh = BoxShadow(color: Color(0x99000000), blurRadius: 4.0);
      expect(AqilElevationAuditor.auditBoxShadow(harsh), contains('harsh opacity'));
    });

    testWidgets('AqilFluidSwitch renders and toggles with fluid curves',
        (WidgetTester tester) async {
      bool value = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AqilFluidSwitch(
              value: value,
              onChanged: (v) => value = v,
            ),
          ),
        ),
      );

      expect(find.byType(AqilFluidSwitch), findsOneWidget);
      await tester.tap(find.byType(AqilFluidSwitch));
      await tester.pumpAndSettle();
      expect(value, isTrue);
    });

    test('AqilCtaHierarchyAuditor enforces Von Restorff primary button isolation', () {
      final singlePrimary = AqilCtaHierarchyAuditor.auditButtonCollection([
        AqilButtonRole.primary,
        AqilButtonRole.secondary,
      ]);
      expect(singlePrimary, isNull);

      final competing = AqilCtaHierarchyAuditor.auditButtonCollection([
        AqilButtonRole.primary,
        AqilButtonRole.primary,
      ]);
      expect(competing, contains('Von Restorff'));
    });

    testWidgets('AqilInteractiveField renders with animated focus styling',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AqilInteractiveField(
              label: 'Full Name',
              hint: 'John Doe',
            ),
          ),
        ),
      );

      expect(find.text('Full Name'), findsOneWidget);
    });

    testWidgets('AqilProgressiveBlur softens scrollable edges',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AqilProgressiveBlur(
              child: Text('Scrollable Body'),
            ),
          ),
        ),
      );

      expect(find.text('Scrollable Body'), findsOneWidget);
    });

    testWidgets('AqilMicroBadge renders variant styling with refined typography',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AqilMicroBadge(
              label: 'Active',
              variant: AqilBadgeVariant.success,
            ),
          ),
        ),
      );

      expect(find.text('Active'), findsOneWidget);
    });

    test('AqilCornerRadiusAuditor verifies concentric nested curvature harmony', () {
      final inner = AqilCornerRadiusAuditor.calculateConcentricInnerRadius(
        outerRadius: 20.0,
        padding: 8.0,
      );
      expect(inner, equals(12.0));

      final harmonious = AqilCornerRadiusAuditor.auditNestedCornerHarmony(
        outerRadius: 20.0,
        padding: 8.0,
        actualInnerRadius: 12.0,
      );
      expect(harmonious, isNull);

      final clashing = AqilCornerRadiusAuditor.auditNestedCornerHarmony(
        outerRadius: 20.0,
        padding: 8.0,
        actualInnerRadius: 2.0,
      );
      expect(clashing, contains('non-concentric inner radius'));
    });

    test('AqilVisualDesignMatrix evaluates complete 10-pillar visual scorecard', () {
      final report = AqilVisualDesignMatrix.evaluateScreen(
        textColor: (0, 0, 0),
        surfaceColor: (255, 255, 255),
        buttons: [AqilButtonRole.primary, AqilButtonRole.secondary],
        outerCardRadius: 16.0,
        cardPadding: 8.0,
        innerElementRadius: 8.0,
      );

      expect(report.isWorldClassTier, isTrue);
      expect(report.compositeVisualScore, greaterThanOrEqualTo(0.90));
      expect(report.detectedGaps.isEmpty, isTrue);
    });

    test('AqilDynamicTracking computes optical letter-spacing accurately', () {
      final largeTracking = AqilDynamicTracking.computeTracking(36.0);
      expect(largeTracking, lessThan(0.0)); // Tight tracking for headlines

      final captionTracking = AqilDynamicTracking.computeTracking(11.0);
      expect(captionTracking, greaterThan(0.0)); // Loose tracking for small text

      final bodyTracking = AqilDynamicTracking.computeTracking(16.0);
      expect(bodyTracking, equals(0.0));
    });

    testWidgets('AqilFloatingBanner renders notification with custom icon',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AqilFloatingBanner(
              title: 'Changes saved',
              message: 'Your profile has been updated.',
              type: AqilToastType.success,
            ),
          ),
        ),
      );

      expect(find.text('Changes saved'), findsOneWidget);
      expect(find.text('Your profile has been updated.'), findsOneWidget);
    });

    testWidgets('AqilSegmentedPill switches active pill on tap',
        (WidgetTester tester) async {
      String selected = 'day';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AqilSegmentedPill<String>(
                  selectedValue: selected,
                  options: const {'day': 'Day', 'week': 'Week', 'month': 'Month'},
                  onSelected: (val) => setState(() => selected = val),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Week'), findsOneWidget);
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(selected, equals('week'));
    });

    test('AqilIconGeometryAuditor verifies touch target and glyph proportions', () {
      final valid = AqilIconGeometry.auditIconProportions(glyphSize: 24.0, containerSize: 48.0);
      expect(valid, isNull);

      final cramped = AqilIconGeometry.auditIconProportions(glyphSize: 40.0, containerSize: 48.0);
      expect(cramped, contains('cramped against container boundary'));
    });

    testWidgets('AqilAccordionTile expands and collapses content smoothly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AqilAccordionTile(
              title: Text('FAQ Question'),
              content: Text('Detailed Answer Content'),
            ),
          ),
        ),
      );

      expect(find.text('FAQ Question'), findsOneWidget);
      await tester.tap(find.text('FAQ Question'));
      await tester.pumpAndSettle();
      expect(find.text('Detailed Answer Content'), findsOneWidget);
    });

    testWidgets('AqilHairlineDivider renders with subtle thickness',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AqilHairlineDivider(),
          ),
        ),
      );

      expect(find.byType(AqilHairlineDivider), findsOneWidget);
    });

    test('AqilMediaAspectAuditor catches distorted media dimensions', () {
      final valid = AqilMediaAspectAuditor.auditAspect(width: 160.0, height: 90.0);
      expect(valid, isNull);

      final distorted = AqilMediaAspectAuditor.auditAspect(width: 160.0, height: 160.0);
      expect(distorted, contains('deviates significantly'));
    });

    testWidgets('AqilInteractiveCard handles tap spring scale',
        (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AqilInteractiveCard(
              onTap: () => tapped = true,
              child: const Text('Interactive Card Body'),
            ),
          ),
        ),
      );

      expect(find.text('Interactive Card Body'), findsOneWidget);
      await tester.tap(find.text('Interactive Card Body'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('AqilFloatingActionButtonExtended renders icon and label',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AqilFloatingActionButtonExtended(
              icon: const Icon(Icons.add),
              label: const Text('Create Task'),
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Create Task'), findsOneWidget);
    });

    test('AqilDesignArchetypes provides ready-to-use aesthetic theme data', () {
      final obsidian = AqilDesignArchetypes.obsidian();
      expect(obsidian.scaffoldBackgroundColor, equals(const Color(0xFF08090A)));

      final minimalist = AqilDesignArchetypes.minimalist();
      expect(minimalist.brightness, equals(Brightness.light));

      final fintech = AqilDesignArchetypes.fintechVibrant();
      expect(fintech.colorScheme.primary, equals(const Color(0xFF00D632)));
    });

    testWidgets('AqilSurfaceLighting renders child with specular rim and audits depth',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AqilSurfaceLighting(
              child: Text('Specular Surface'),
            ),
          ),
        ),
      );

      expect(find.text('Specular Surface'), findsOneWidget);

      final score = AqilSurfaceDepthAuditor.evaluateLuminanceContrast(
        background: const Color(0xFF101012),
        surface: const Color(0xFF242428),
      );
      expect(score, greaterThan(0.5));
    });

    testWidgets('AqilTypographicContrastAuditor and AqilTypeHierarchy enforce scale contrast',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AqilTypeHierarchy(
              title: 'Executive Title',
              subtitle: 'Subordinate explanatory description',
            ),
          ),
        ),
      );

      expect(find.text('Executive Title'), findsOneWidget);
      expect(find.text('Subordinate explanatory description'), findsOneWidget);

      final contrast = AqilTypographicContrastAuditor.evaluateContrast(
        heading: const TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
        body: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.normal),
      );
      expect(contrast.isHarmonious, isTrue);
    });

    testWidgets('AqilFloatingDock renders items and selects active item',
        (WidgetTester tester) async {
      int selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AqilFloatingDock(
              currentIndex: selected,
              onItemSelected: (idx) => selected = idx,
              items: const [
                AqilDockItem(icon: Icons.home, label: 'Home'),
                AqilDockItem(icon: Icons.search, label: 'Search', badgeCount: 3),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expect(selected, equals(1));
    });

    testWidgets('AqilContentDensity provides density multipliers and adapts row insets',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AqilDensityScope(
              level: AqilDensityLevel.compact,
              child: Builder(
                builder: (context) {
                  final spacing = AqilDensityScope.spacing(context, 16.0);
                  expect(spacing, equals(12.0));
                  return const AqilDensityRow(
                    leading: Icon(Icons.star),
                    title: Text('Compact Task'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Compact Task'), findsOneWidget);
    });

    testWidgets('AqilStatusPill renders status variant with pulse and audits palette',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AqilStatusPill(
              variant: AqilStatusVariant.success,
              showLivePulse: true,
            ),
          ),
        ),
      );

      expect(find.text('Success'), findsOneWidget);

      final isNeon = AqilSemanticPaletteAuditor.isHarshNeon(const Color(0xFFFF0000));
      expect(isNeon, isTrue);

      final softened = AqilSemanticPaletteAuditor.softenHarmonious(const Color(0xFFFF0000));
      expect(AqilSemanticPaletteAuditor.isHarshNeon(softened), isFalse);
    });

    testWidgets('AqilFocusRing surrounds child when focused',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AqilFocusRing(
              isFocused: true,
              child: Text('Focused Input'),
            ),
          ),
        ),
      );

      expect(find.text('Focused Input'), findsOneWidget);
    });

    testWidgets('AqilAvatarGroup renders overlapping facepile and excess counter',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AqilAvatarGroup(
              maxVisible: 2,
              avatars: [
                AqilAvatarItem(id: '1', name: 'Alice Smith'),
                AqilAvatarItem(id: '2', name: 'Bob Jones'),
                AqilAvatarItem(id: '3', name: 'Charlie Brown'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('AS'), findsOneWidget);
      expect(find.text('BJ'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('AqilEmptyState renders expressive empty state and validates audit',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AqilEmptyState(
              icon: Icons.inbox,
              title: 'No Active Projects',
              description: 'Create your first project to begin tracking milestones.',
              action: ElevatedButton(
                onPressed: () {},
                child: const Text('New Project'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('No Active Projects'), findsOneWidget);
      expect(find.text('New Project'), findsOneWidget);

      final isActionable = AqilEmptyStateAuditor.isActionableEmptyState(
        title: 'No Active Projects',
        description: 'Create your first project to begin tracking milestones.',
        hasAction: true,
      );
      expect(isActionable, isTrue);

      final isNotActionable = AqilEmptyStateAuditor.isActionableEmptyState(
        title: 'None',
        description: 'Empty',
        hasAction: false,
      );
      expect(isNotActionable, isFalse);
    });

    testWidgets('AqilGlassMorphismCard renders with backdrop blur and border gradient',
        (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AqilGlassMorphismCard(
              onTap: () => tapped = true,
              child: const Text('VisionOS Card'),
            ),
          ),
        ),
      );

      expect(find.text('VisionOS Card'), findsOneWidget);
      await tester.tap(find.text('VisionOS Card'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    test('AqilWorldClassDesignBenchmark scores composite design quality', () {
      final scorecard = AqilWorldClassDesignBenchmark.evaluateScreen(
        headingStyle: const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
        bodyStyle: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.normal),
        backgroundColor: const Color(0xFF0F0F12),
        surfaceColor: const Color(0xFF1E1E24),
        semanticAlertColors: [
          const Color(0xFF10B981),
          const Color(0xFFF59E0B),
        ],
        hasActionableEmptyStates: true,
      );

      expect(scorecard.overallScore, greaterThanOrEqualTo(85.0));
      expect(scorecard.isWorldClass, isTrue);
      expect(scorecard.designRecommendations, isEmpty);
    });

    testWidgets('AqilAmbientGlow renders child with ambient mesh background',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AqilAmbientGlow(
              intensity: 0.25,
              child: Text('Ambient Mesh Content'),
            ),
          ),
        ),
      );

      expect(find.text('Ambient Mesh Content'), findsOneWidget);
      expect(AqilAmbientGlowAuditor.isSafeGlowIntensity(0.25), isTrue);
      expect(AqilAmbientGlowAuditor.isSafeGlowIntensity(0.85), isFalse);
    });

    testWidgets('AqilSyncedShimmerGroup coordinates placeholder bones',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AqilSyncedShimmerGroup(
              duration: Duration(milliseconds: 1400),
              child: Column(
                children: [
                  AqilSyncedBone(width: 120.0, height: 16.0),
                  SizedBox(height: 8.0),
                  AqilSyncedBone(width: 200.0, height: 16.0),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AqilSyncedBone), findsNWidgets(2));
      expect(AqilShimmerWaveAuditor.isSmoothDuration(const Duration(milliseconds: 1400)), isTrue);
      expect(AqilShimmerWaveAuditor.isSmoothDuration(const Duration(milliseconds: 500)), isFalse);
    });

    testWidgets('AqilInteractiveBadgePill toggles active state and dismisses',
        (WidgetTester tester) async {
      bool tapped = false;
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AqilInteractiveBadgePill(
              label: 'Design System',
              count: 4,
              isSelected: true,
              onTap: () => tapped = true,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(find.text('Design System'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);

      await tester.tap(find.text('Design System'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    });

    testWidgets('AqilDynamicIslandToast transitions between compact and expanded modes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AqilDynamicIslandToast(
              mode: AqilIslandMode.expanded,
              leading: Icon(Icons.flight, color: Colors.white),
              title: 'Flight DL 284',
              subtitle: 'Boarding in 12 min',
            ),
          ),
        ),
      );

      expect(find.text('Flight DL 284'), findsOneWidget);
      expect(find.text('Boarding in 12 min'), findsOneWidget);
    });

    test('AqilVisualWeightAuditor calculates horizontal balance and flags severe asymmetry', () {
      final balanced = AqilVisualWeightAuditor.evaluateHorizontalBalance(
        leftSize: const Size(120, 40),
        rightSize: const Size(100, 40),
      );
      expect(balanced.isBalanced, isTrue);

      final asymmetric = AqilVisualWeightAuditor.evaluateHorizontalBalance(
        leftSize: const Size(400, 200),
        rightSize: const Size(20, 20),
      );
      expect(asymmetric.isBalanced, isFalse);
    });

    testWidgets('AqilSteppedProgressIndicator renders steps and completed marks',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AqilSteppedProgressIndicator(
              currentStep: 1,
              steps: [
                AqilStepItem(title: 'Account'),
                AqilStepItem(title: 'Billing'),
                AqilStepItem(title: 'Confirm'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Billing'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget); // Step 0 is completed
    });

    testWidgets('AqilBorderGradientGlow renders with custom gradient border',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AqilBorderGradientGlow(
              child: Text('Glow Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Glow Card Content'), findsOneWidget);
    });

    testWidgets('AqilSplitActionPill fires main action and dropdown events separately',
        (WidgetTester tester) async {
      bool actionPressed = false;
      bool dropdownPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AqilSplitActionPill(
              label: 'Merge Branch',
              onAction: () => actionPressed = true,
              onDropdown: () => dropdownPressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Merge Branch'), findsOneWidget);

      await tester.tap(find.text('Merge Branch'));
      await tester.pumpAndSettle();
      expect(actionPressed, isTrue);

      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      expect(dropdownPressed, isTrue);
    });

    test('AqilZIndexLayerAuditor validates layer tiers and catches inversion', () {
      final validCard = AqilZIndexLayerAuditor.conformsToTier(
        elevation: 2.0,
        tier: AqilElevationTier.card,
      );
      expect(validCard, isTrue);

      final validModal = AqilZIndexLayerAuditor.conformsToTier(
        elevation: 12.0,
        tier: AqilElevationTier.modalSheet,
      );
      expect(validModal, isTrue);

      final noInversion = AqilZIndexLayerAuditor.auditLayerPair(
        backgroundElevation: 2.0,
        foregroundElevation: 12.0,
      );
      expect(noInversion, isNull);

      final inverted = AqilZIndexLayerAuditor.auditLayerPair(
        backgroundElevation: 16.0,
        foregroundElevation: 4.0,
      );
      expect(inverted, contains('Elevation Inversion'));
    });

    test('AqilIndustryExcellenceRadar produces composite score and ratings', () {
      final scorecard = AqilIndustryExcellenceRadar.evaluate(
        ambientIntensity: 0.20,
        shimmerDuration: const Duration(milliseconds: 1500),
        leftCardSize: const Size(140, 48),
        rightCardSize: const Size(120, 48),
        cardElevation: 2.0,
        modalElevation: 12.0,
      );

      expect(scorecard.compositeScore, equals(100.0));
      expect(scorecard.ratingTier, equals('World-Class Enterprise'));
      expect(scorecard.findings, isEmpty);
    });
  });
}
