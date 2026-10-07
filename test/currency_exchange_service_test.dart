import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/services/currency_exchange_service.dart';
import 'package:trackmytrip/screens/expenses/multi_currency_converter_card.dart';

void main() {
  group('CurrencyExchangeService Unit Tests', () {
    setUp(() {
      CurrencyExchangeService.resetToDefaultRates();
    });

    test('Converts between identical currencies with 1.0 multiplier', () {
      final res = CurrencyExchangeService.convert(150.0, from: 'INR', to: 'INR');
      expect(res, equals(150.0));
    });

    test('Accurately converts USD to INR based on baseline peg', () {
      final res = CurrencyExchangeService.convert(10.0, from: 'USD', to: 'INR');
      // 10 USD * 83.50 = 835.00
      expect(res, equals(835.0));
    });

    test('Accurately converts EUR to INR', () {
      final rate = CurrencyExchangeService.getRate('EUR', 'INR');
      expect(rate, greaterThan(80.0));
      expect(rate, lessThan(100.0));

      final converted = CurrencyExchangeService.convert(100.0, from: 'EUR', to: 'INR');
      expect(converted, greaterThan(8000.0));
    });

    test('Custom rate override applies and reflects reciprocally', () {
      CurrencyExchangeService.setCustomRate('EUR', 'INR', 90.0);

      expect(CurrencyExchangeService.convert(10.0, from: 'EUR', to: 'INR'), equals(900.0));
      // Inverted
      final inverted = CurrencyExchangeService.convert(900.0, from: 'INR', to: 'EUR');
      expect(inverted, equals(10.0));
    });
  });

  group('AQIL Multi-Viewport & Accessibility Tests: MultiCurrencyConverterCard', () {
    const viewports = [
      Size(320, 600),  // Compact Mobile
      Size(393, 852),  // Standard Mobile
      Size(412, 915),  // Large Mobile
      Size(800, 1200), // Tablet Portrait
      Size(1280, 800), // Landscape Desktop
    ];

    for (final viewport in viewports) {
      testWidgets('Renders zero overflow at ${viewport.width}x${viewport.height} with 1.5x font scale', (tester) async {
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: viewport,
                textScaler: const TextScaler.linear(1.5),
              ),
              child: const Scaffold(
                body: SingleChildScrollView(
                  child: MultiCurrencyConverterCard(
                    initialFromCurrency: 'EUR',
                    initialToCurrency: 'INR',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Currency Calculator'), findsOneWidget);
        expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));

        // Tap swap button to verify interaction without exception
        await tester.tap(find.byIcon(Icons.swap_horiz_rounded));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
