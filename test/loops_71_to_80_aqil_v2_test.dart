import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/design_system/design_system.dart';
import 'package:trackmytrip/core/theme/app_theme.dart';

void main() {
  group('Loop 71: Design Token Core Architecture Tests', () {
    test('AppSpacing adheres to 4-pt/8-pt grid system', () {
      expect(AppSpacing.xxs, equals(2.0));
      expect(AppSpacing.xs, equals(4.0));
      expect(AppSpacing.sm, equals(8.0));
      expect(AppSpacing.md, equals(12.0));
      expect(AppSpacing.lg, equals(16.0));
      expect(AppSpacing.xl, equals(24.0));
      expect(AppSpacing.xxl, equals(32.0));
      expect(AppSpacing.xxxl, equals(48.0));
    });

    test('AppRadius tokens conform to Material 3 shape scale', () {
      expect(AppRadius.xs, equals(4.0));
      expect(AppRadius.sm, equals(8.0));
      expect(AppRadius.md, equals(12.0));
      expect(AppRadius.lg, equals(16.0));
      expect(AppRadius.xl, equals(20.0));
      expect(AppRadius.xxl, equals(24.0));
      expect(AppRadius.pill, equals(999.0));

      expect(AppRadius.roundedSm.topLeft.x, equals(8.0));
      expect(AppRadius.roundedMd.topLeft.x, equals(12.0));
      expect(AppRadius.roundedLg.topLeft.x, equals(16.0));
      expect(AppRadius.roundedXl.topLeft.x, equals(20.0));
      expect(AppRadius.roundedPill.topLeft.x, equals(999.0));
    });

    test('AppBreakpoints correctly maps window size classes', () {
      expect(AppBreakpoints.of(320.0), equals(WindowSizeClass.compact));
      expect(AppBreakpoints.of(599.0), equals(WindowSizeClass.compact));
      expect(AppBreakpoints.isCompact(412.0), isTrue);

      expect(AppBreakpoints.of(600.0), equals(WindowSizeClass.medium));
      expect(AppBreakpoints.of(839.0), equals(WindowSizeClass.medium));
      expect(AppBreakpoints.isMedium(800.0), isTrue);

      expect(AppBreakpoints.of(840.0), equals(WindowSizeClass.expanded));
      expect(AppBreakpoints.of(1199.0), equals(WindowSizeClass.expanded));
      expect(AppBreakpoints.isExpanded(1024.0), isTrue);

      expect(AppBreakpoints.of(1200.0), equals(WindowSizeClass.large));
      expect(AppBreakpoints.of(1920.0), equals(WindowSizeClass.large));
      expect(AppBreakpoints.isLarge(1440.0), isTrue);
    });

    test('AppStatusColors light and dark palettes provide semantic tokens', () {
      const light = AppStatusColors.light;
      const dark = AppStatusColors.dark;

      expect(light.success, isNotNull);
      expect(light.onSuccess, equals(Colors.white));
      expect(light.successContainer, isNotNull);
      expect(light.onSuccessContainer, isNotNull);

      expect(dark.success, isNotNull);
      expect(dark.successContainer, isNotNull);
      expect(dark.onSuccessContainer, isNotNull);

      // copyWith test
      final copied = light.copyWith(success: Colors.teal);
      expect(copied.success, equals(Colors.teal));
      expect(copied.danger, equals(light.danger));

      // lerp test
      final lerped = light.lerp(dark, 0.5);
      expect(lerped, isNotNull);
      expect(lerped.success, isNotNull);
    });

    test('AppTheme wires AppStatusColors into lightTheme and darkTheme', () {
      final lightTheme = AppTheme.lightTheme;
      final darkTheme = AppTheme.darkTheme;

      final lightExt = lightTheme.extension<AppStatusColors>();
      final darkExt = darkTheme.extension<AppStatusColors>();

      expect(lightExt, isNotNull);
      expect(darkExt, isNotNull);
      expect(lightExt?.success, equals(AppStatusColors.light.success));
      expect(darkExt?.success, equals(AppStatusColors.dark.success));
    });
  });

  group('Loop 72: Screen State & Primitive Components Tests', () {
    testWidgets('AppSkeletonBox renders correctly and collapses on reduced motion', (tester) async {
      // 1. Normal motion
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppSkeletonBox(width: 100.0, height: 20.0),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AppSkeletonBox), findsOneWidget);

      // 2. Reduced motion
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: AppSkeletonBox(width: 100.0, height: 20.0),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AppSkeletonBox), findsOneWidget);
    });

    testWidgets('AppSkeletonListTile and AppSkeletonCard render without exceptions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppSkeletonCard(height: 80.0),
                AppSkeletonListTile(hasAvatar: true, hasTrailing: true),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AppSkeletonCard), findsOneWidget);
      expect(find.byType(AppSkeletonListTile), findsOneWidget);
    });

    testWidgets('AppEmptyState displays title, message, and responds to action callback', (tester) async {
      bool actionTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppEmptyState(
              icon: Icons.inbox_rounded,
              title: 'Empty Inbox',
              message: 'No incoming messages at this time.',
              actionLabel: 'Refresh Inbox',
              onAction: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Empty Inbox'), findsOneWidget);
      expect(find.text('No incoming messages at this time.'), findsOneWidget);
      expect(find.text('Refresh Inbox'), findsOneWidget);

      await tester.tap(find.text('Refresh Inbox'));
      await tester.pump();
      expect(actionTapped, isTrue);
    });

    testWidgets('AppErrorRetry displays error message and triggers onRetry', (tester) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AppErrorRetry(
              title: 'Connection Lost',
              message: 'Unable to reach the trip sync server.',
              retryLabel: 'Retry Sync',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Connection Lost'), findsOneWidget);
      expect(find.text('Unable to reach the trip sync server.'), findsOneWidget);
      expect(find.text('Retry Sync'), findsOneWidget);

      await tester.tap(find.text('Retry Sync'));
      await tester.pump();
      expect(retried, isTrue);
    });
  });

  group('Loop 75 & 78: Motion & Context Extensions Tests', () {
    testWidgets('AppMotion.duration respects disableAnimationsOf context', (tester) async {
      Duration? resolvedDuration;
      Duration? reducedDuration;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolvedDuration = AppMotion.duration(context, const Duration(milliseconds: 300));
              return const SizedBox();
            },
          ),
        ),
      );
      expect(resolvedDuration, equals(const Duration(milliseconds: 300)));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                reducedDuration = AppMotion.duration(context, const Duration(milliseconds: 300));
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(reducedDuration, equals(Duration.zero));
    });

    testWidgets('DesignSystemContextX provides convenient theme and status color accessors', (tester) async {
      AppStatusColors? statusColors;
      bool? isCompact;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(393, 852)),
            child: Builder(
              builder: (context) {
                statusColors = context.statusColors;
                isCompact = context.isCompact;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(statusColors, isNotNull);
      expect(statusColors?.success, equals(AppStatusColors.light.success));
      expect(isCompact, isTrue);
    });
  });
}
