import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/models/outdoor_theme_profile.dart';
import 'package:trackmytrip/core/services/outdoor_theme_service.dart';
import 'package:trackmytrip/screens/settings/outdoor_theme_card.dart';

void main() {
  group('OutdoorThemeService Logic Tests', () {
    final service = OutdoorThemeService();

    setUp(() {
      service.updateProfile(const OutdoorThemeProfile());
    });

    test('Computes WCAG contrast ratio accurately', () {
      final ratio = OutdoorThemeService.calculateContrastRatio(Colors.black, Colors.white);
      expect(ratio, greaterThan(15.0)); // Black on white is 21:1

      final equalRatio = OutdoorThemeService.calculateContrastRatio(Colors.white, Colors.white);
      expect(equalRatio, closeTo(1.0, 0.01));
    });

    test('Adapts ColorScheme for Sunlight Glare high contrast', () {
      service.setMode(OutdoorDisplayMode.sunlightGlareHighContrast);
      const baseScheme = ColorScheme.light();
      final adapted = service.getAdaptedColorScheme(baseScheme);

      expect(adapted.surface, Colors.white);
      expect(adapted.onSurface, Colors.black);
      expect(adapted.outline, Colors.black);
    });

    test('Adapts ColorScheme for OLED Night Vision Red and Amber', () {
      service.setMode(OutdoorDisplayMode.nightVisionOledRed);
      const baseScheme = ColorScheme.dark();
      final adaptedRed = service.getAdaptedColorScheme(baseScheme);

      expect(adaptedRed.surface, Colors.black);
      expect(adaptedRed.primary, const Color(0xFFFF3B30));

      service.setMode(OutdoorDisplayMode.nightVisionOledAmber);
      final adaptedAmber = service.getAdaptedColorScheme(baseScheme);

      expect(adaptedAmber.surface, Colors.black);
      expect(adaptedAmber.primary, const Color(0xFFFF9F0A));
    });

    test('OutdoorThemeProfile JSON serialization and deserialization', () {
      const profile = OutdoorThemeProfile(
        mode: OutdoorDisplayMode.nightVisionOledRed,
        amoledPureBlack: true,
        contrastBoost: 1.5,
        boldTextForced: true,
      );

      final json = profile.toJson();
      final parsed = OutdoorThemeProfile.fromJson(json);

      expect(parsed.mode, OutdoorDisplayMode.nightVisionOledRed);
      expect(parsed.amoledPureBlack, true);
      expect(parsed.contrastBoost, 1.5);
      expect(parsed.boldTextForced, true);
      expect(parsed.isNightVision, true);
    });
  });

  group('AQIL Multi-Viewport Responsive Tests for OutdoorThemeCard', () {
    final viewports = <String, Size>{
      '320px compact mobile': const Size(320, 568),
      '393px standard mobile': const Size(393, 852),
      '412px large mobile': const Size(412, 915),
      '800px tablet portrait': const Size(800, 1200),
      '1280px desktop landscape': const Size(1280, 800),
    };

    for (final entry in viewports.entries) {
      testWidgets('Renders zero overflow on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: OutdoorThemeCard(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Outdoor Glare & Night Theme'), findsOneWidget);
        expect(find.text('FIELD READABILITY PREVIEW'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Renders with 1.5x font scale without overflow and toggles mode', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      OutdoorThemeProfile? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              textScaler: const TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: OutdoorThemeCard(
                  onProfileChanged: (p) => changed = p,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Outdoor Glare & Night Theme'), findsOneWidget);

      final sunlightOption = find.text('Sunlight Glare Shield');
      expect(sunlightOption, findsOneWidget);
      await tester.tap(sunlightOption);
      await tester.pumpAndSettle();

      expect(changed, isNotNull);
      expect(changed!.mode, OutdoorDisplayMode.sunlightGlareHighContrast);
      expect(tester.takeException(), isNull);
    });
  });
}
