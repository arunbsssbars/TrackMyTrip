import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/services/receipt_parser_engine.dart';
import 'package:trackmytrip/models/receipt_parsed_data.dart';
import 'package:trackmytrip/screens/expenses/receipt_correction_sheet.dart';

void main() {
  group('ReceiptParserEngine Unit Tests', () {
    test('Correctly parses fuel station receipt', () {
      const fuelReceipt = '''
      INDIAN OIL CORPORATION LTD
      STATION #4029 HIGHWAY PUMP
      DATE: 14/10/2026 TIME: 11:45
      INVOICE NO: IOC492049
      FUEL: DIESEL
      QTY: 35.5 LTR
      RATE: 89.50
      TOTAL AMOUNT: ₹3,177.25
      TAX/GST: ₹380.00
      THANK YOU VISIT AGAIN
      ''';

      final result = ReceiptParserEngine.parse(fuelReceipt);

      expect(result.merchantName, contains('INDIAN OIL CORPORATION'));
      expect(result.totalAmount, equals(3177.25));
      expect(result.taxAmount, equals(380.00));
      expect(result.currency, equals('INR'));
      expect(result.category, equals('Fuel / Gas'));
      expect(result.invoiceNumber, equals('IOC492049'));
      expect(result.confidenceScore, greaterThan(0.6));
    });

    test('Correctly parses restaurant dining bill with items', () {
      const diningReceipt = '''
      THE HIMALAYAN BISTRO
      MALL ROAD MANALI
      DATE: 2026-10-15
      TABLE: 04
      1x Veg Thali 250.00
      2x Masala Chai 60.00
      1x Paneer Butter Masala 320.00
      SUBTOTAL: 630.00
      CGST + SGST: 31.50
      GRAND TOTAL: 661.50
      ''';

      final result = ReceiptParserEngine.parse(diningReceipt);

      expect(result.merchantName, contains('THE HIMALAYAN BISTRO'));
      expect(result.totalAmount, equals(661.50));
      expect(result.category, equals('Food & Drinks'));
      expect(result.items.length, greaterThanOrEqualTo(2));
      expect(result.confidenceScore, greaterThan(0.7));
    });

    test('Defensively handles blank or corrupt OCR text', () {
      final result = ReceiptParserEngine.parse('');

      expect(result.merchantName, equals('Unknown Merchant'));
      expect(result.totalAmount, equals(0.0));
      expect(result.confidenceScore, equals(0.0));
    });
  });

  group('AQIL Multi-Viewport & Accessibility Tests: ReceiptCorrectionSheet', () {
    const viewports = [
      Size(320, 600),  // Compact Mobile
      Size(393, 852),  // Standard Mobile
      Size(412, 915),  // Large Mobile
      Size(800, 1200), // Tablet Portrait
      Size(1280, 800), // Landscape Desktop
    ];

    const testParsedData = ReceiptParsedData(
      merchantName: 'Himalayan Ridge Cafe & Adventure Gear',
      totalAmount: 1450.50,
      taxAmount: 72.50,
      currency: 'INR',
      category: 'Food & Drinks',
      items: [
        ReceiptLineItem(title: 'Himalayan Coffee', price: 180.0, quantity: 2),
        ReceiptLineItem(title: 'Nutella Waffle', price: 290.0, quantity: 1),
      ],
      confidenceScore: 0.92,
    );

    for (final viewport in viewports) {
      testWidgets('Renders zero overflow at ${viewport.width}x${viewport.height} with 1.5x font scale', (tester) async {
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        ReceiptParsedData? confirmedData;

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: viewport,
                textScaler: const TextScaler.linear(1.5),
              ),
              child: Scaffold(
                body: ReceiptCorrectionSheet(
                  initialData: testParsedData,
                  onConfirmed: (data) => confirmedData = data,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Review Receipt Scan'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);

        // Tap submit button to verify responsive callback interaction
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();

        expect(confirmedData, isNotNull);
        expect(confirmedData!.merchantName, equals('Himalayan Ridge Cafe & Adventure Gear'));
      });
    }
  });
}
