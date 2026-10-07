import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/models/upi_payment_intent.dart';
import 'package:trackmytrip/core/services/upi_settlement_service.dart';
import 'package:trackmytrip/screens/expenses/upi_payment_qr_sheet.dart';

void main() {
  group('UpiSettlementService & UpiPaymentIntent Logic Tests', () {
    final service = UpiSettlementService();

    test('Generates canonical NPCI UPI URI string accurately', () {
      final intent = service.createIntent(
        payeeVpa: 'arun@okaxis',
        payeeName: 'Arun Kumar',
        amount: 1450.50,
        tripTitle: 'Manali Expedition',
      );

      expect(intent.payeeVpa, 'arun@okaxis');
      expect(intent.amount, 1450.50);
      expect(intent.isValidVpa, true);

      final uriString = intent.upiUriString;
      expect(uriString, startsWith('upi://pay?'));
      expect(uriString, contains('pa=arun@okaxis'));
      expect(uriString, contains('am=1450.50'));
      expect(uriString, contains('cu=INR'));
      expect(uriString, contains('pn=Arun%20Kumar'));
    });

    test('Validates VPA format regex correctly', () {
      const valid1 = UpiPaymentIntent(payeeVpa: 'user@okhdfcbank', payeeName: 'A', amount: 100);
      const valid2 = UpiPaymentIntent(payeeVpa: '9876543210@paytm', payeeName: 'B', amount: 100);
      const invalid1 = UpiPaymentIntent(payeeVpa: 'not-an-upi-id', payeeName: 'C', amount: 100);
      const invalid2 = UpiPaymentIntent(payeeVpa: 'user@', payeeName: 'D', amount: 100);

      expect(valid1.isValidVpa, true);
      expect(valid2.isValidVpa, true);
      expect(invalid1.isValidVpa, false);
      expect(invalid2.isValidVpa, false);
    });

    test('Json serialization and deserialization retains accuracy', () {
      const intent = UpiPaymentIntent(
        payeeVpa: 'priya@icici',
        payeeName: 'Priya Sharma',
        amount: 820.00,
        transactionNote: 'Hotel Split',
        currency: 'INR',
      );

      final json = intent.toJson();
      final restored = UpiPaymentIntent.fromJson(json);

      expect(restored.payeeVpa, 'priya@icici');
      expect(restored.payeeName, 'Priya Sharma');
      expect(restored.amount, 820.00);
      expect(restored.transactionNote, 'Hotel Split');
    });
  });

  group('AQIL Multi-Viewport & Accessibility Tests for UpiPaymentQrSheet', () {
    const intent = UpiPaymentIntent(
      payeeVpa: 'trip.settle@okhdfcbank',
      payeeName: 'Vikram Singhaniya',
      amount: 2750.00,
      transactionNote: 'Expedition Settlement',
    );

    final viewports = <String, Size>{
      'Compact Mobile (320px)': const Size(320, 568),
      'Standard Mobile (393px)': const Size(393, 852),
      'Large Mobile (412px)': const Size(412, 915),
      'Tablet Portrait (800px)': const Size(800, 1280),
      'Desktop Landscape (1280px)': const Size(1280, 800),
    };

    for (final entry in viewports.entries) {
      testWidgets('Renders zero overflow on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UpiPaymentQrSheet(intent: intent),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Instant UPI Settle'), findsOneWidget);
        expect(find.byType(UpiPaymentQrSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Renders with 1.5x font scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              textScaler: const TextScaler.linear(1.5),
            ),
            child: const Scaffold(
              body: UpiPaymentQrSheet(intent: intent),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Instant UPI Settle'), findsOneWidget);

      final copyBtn = find.text('Copy UPI Link');
      await tester.ensureVisible(copyBtn);
      await tester.tap(copyBtn);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
