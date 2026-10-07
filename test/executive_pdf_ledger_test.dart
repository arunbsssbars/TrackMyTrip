import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/models/executive_ledger_data.dart';
import 'package:trackmytrip/core/services/executive_pdf_ledger_service.dart';
import 'package:trackmytrip/screens/expenses/pdf_ledger_preview_dialog.dart';

void main() {
  group('ExecutivePdfLedgerService PDF Generation Tests', () {
    final service = ExecutivePdfLedgerService();

    final testData = ExecutiveLedgerData(
      tripTitle: 'Himalayan High Altitude Pass 2026',
      tripId: 'trip_him_01',
      generatedAt: DateTime.utc(2026, 10, 8, 14, 0),
      totalExpenses: 28500.0,
      currency: 'INR',
      expenseEntries: [
        {'title': 'Convoy Diesel Refill', 'category': 'Fuel', 'paidBy': 'Arun', 'amount': 8200.0},
        {'title': 'Basecamp Tent Rental', 'category': 'Stay', 'paidBy': 'Priya', 'amount': 14000.0},
        {'title': 'Permits & Tolls', 'category': 'Permits', 'paidBy': 'Rahul', 'amount': 6300.0},
      ],
      settlementNotes: [
        'Arun is owed INR 2,100 by Rahul',
        'Priya is fully settled',
      ],
      organizerName: 'Arun Kumar',
      auditorName: 'Priya Sharma (Auditor)',
    );

    test('Generates valid non-empty PDF binary bytes', () async {
      final pdfBytes = await service.generateLedgerPdf(testData);

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000)); // Real PDF header and tables
      // Verify PDF magic bytes '%PDF'
      expect(String.fromCharCodes(pdfBytes.take(4)), '%PDF');
    });

    test('Json serialization and deserialization retains accuracy', () {
      final json = testData.toJson();
      final restored = ExecutiveLedgerData.fromJson(json);

      expect(restored.tripTitle, testData.tripTitle);
      expect(restored.totalExpenses, 28500.0);
      expect(restored.expenseEntries.length, 3);
      expect(restored.organizerName, 'Arun Kumar');
    });
  });

  group('AQIL Multi-Viewport & Accessibility Tests for PdfLedgerPreviewDialog', () {
    final testData = ExecutiveLedgerData(
      tripTitle: 'Goa Annual Offsite',
      tripId: 'trip_goa_09',
      generatedAt: DateTime.now(),
      totalExpenses: 45000.0,
      expenseEntries: [
        {'title': 'Resort Villa', 'category': 'Stay', 'paidBy': 'Arun', 'amount': 30000.0},
      ],
      settlementNotes: ['All balances cleared via UPI'],
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
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: PdfLedgerPreviewDialog(data: testData),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Executive Trip Ledger'), findsOneWidget);
        expect(find.byType(PdfLedgerPreviewDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Renders with 1.5x font scale without overflow and triggers export', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool exportCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              textScaler: const TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: Center(
                child: PdfLedgerPreviewDialog(
                  data: testData,
                  onPrintOrShare: () => exportCalled = true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Executive Trip Ledger'), findsOneWidget);

      final exportBtn = find.text('Export PDF Ledger');
      await tester.ensureVisible(exportBtn);
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      expect(exportCalled, true);
      expect(tester.takeException(), isNull);
    });
  });
}
