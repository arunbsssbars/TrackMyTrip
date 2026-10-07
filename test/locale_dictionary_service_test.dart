import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/models/expedition_locale.dart';
import 'package:trackmytrip/core/services/locale_dictionary_service.dart';
import 'package:trackmytrip/screens/settings/expedition_locale_selector_dialog.dart';

void main() {
  group('LocaleDictionaryService Logic Tests', () {
    final service = LocaleDictionaryService();

    setUp(() {
      service.setLocale('en');
    });

    test('Translates standard keys in English', () {
      expect(service.translate('start_trip'), 'Start Expedition');
      expect(service.translate('emergency_sos'), 'Emergency SOS');
      expect(service.translate('fuel_tolls'), 'Fuel & Tolls');
    });

    test('Translates keys in Hindi, Spanish, French, and German', () {
      expect(service.translate('start_trip', locale: 'hi'), 'यात्रा शुरू करें');
      expect(service.translate('emergency_sos', locale: 'es'), 'Emergencia SOS');
      expect(service.translate('record_stoppage', locale: 'fr'), 'Enregistrer l\'Étape');
      expect(service.translate('fuel_tolls', locale: 'de'), 'Treibstoff & Maut');
    });

    test('Falls back safely to English or raw key for missing entries', () {
      expect(service.translate('non_existent_key'), 'non_existent_key');
      expect(service.translate('start_trip', locale: 'non_existent_locale'), 'Start Expedition');
    });

    test('setLocale successfully updates state for supported locales', () {
      service.setLocale('hi');
      expect(service.currentLocale, 'hi');
      expect(service.translate('settled'), 'पूरा हिसाब हो गया');

      // Invalid locale should be rejected without error
      service.setLocale('xx_invalid');
      expect(service.currentLocale, 'hi');
    });

    test('ExpeditionLocale JSON serialization and fallback deserialization', () {
      final loc = const ExpeditionLocale(
        languageCode: 'ja',
        nativeName: '日本語',
        englishName: 'Japanese',
        flagEmoji: '🇯🇵',
      );

      final json = loc.toJson();
      final parsed = ExpeditionLocale.fromJson(json);

      expect(parsed.languageCode, 'ja');
      expect(parsed.nativeName, '日本語');
      expect(parsed.englishName, 'Japanese');
      expect(parsed.flagEmoji, '🇯🇵');

      final fallback = ExpeditionLocale.fromJson({});
      expect(fallback.languageCode, 'en');
      expect(fallback.nativeName, 'English');
    });
  });

  group('AQIL Multi-Viewport Responsive Tests for ExpeditionLocaleSelectorDialog', () {
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
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => const ExpeditionLocaleSelectorDialog(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Expedition Language'), findsOneWidget);
        expect(find.text('Live Preview:'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Renders with 1.5x font scale without overflow and changes dialect', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? selectedLanguage;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              textScaler: const TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: Builder(
                builder: (context) => ExpeditionLocaleSelectorDialog(
                  onLocaleChanged: (code) => selectedLanguage = code,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Expedition Language'), findsOneWidget);

      final hindiTile = find.text('हिन्दी');
      expect(hindiTile, findsOneWidget);
      await tester.tap(hindiTile);
      await tester.pumpAndSettle();

      expect(selectedLanguage, 'hi');
      expect(find.textContaining('यात्रा शुरू करें'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
