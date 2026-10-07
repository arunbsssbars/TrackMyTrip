import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/executive_ledger_data.dart';

class ExecutivePdfLedgerService {
  static final ExecutivePdfLedgerService _instance = ExecutivePdfLedgerService._internal();
  factory ExecutivePdfLedgerService() => _instance;
  ExecutivePdfLedgerService._internal();

  /// Builds a complete PDF document and returns its bytes
  Future<Uint8List> generateLedgerPdf(ExecutiveLedgerData data) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TrackMyTrip Official Financial Ledger',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal800,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Expedition: ${data.tripTitle}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Trip ID: ${data.tripId}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'Date: ${data.generatedAt.toIso8601String().split('T').first}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(thickness: 1, color: PdfColors.teal800),
            pw.SizedBox(height: 12),

            // Financial Summary Banner
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL AUDITED EXPENDITURE:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                  ),
                  pw.Text(
                    '${data.currency} ${data.totalExpenses.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                      color: PdfColors.teal900,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Expenses Table
            pw.Text(
              'Detailed Expense Ledger',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              context: context,
              cellAlignment: pw.Alignment.centerLeft,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 10,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
              headers: ['Item / Bill', 'Category', 'Paid By', 'Amount (${data.currency})'],
              data: data.expenseEntries.map((e) {
                return [
                  e['title']?.toString() ?? 'Expense',
                  e['category']?.toString() ?? 'General',
                  e['paidBy']?.toString() ?? 'Member',
                  (e['amount'] as num?)?.toStringAsFixed(2) ?? '0.00',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 16),

            // Settlement Section
            if (data.settlementNotes.isNotEmpty) ...[
              pw.Text(
                'Settlement & Balance Reconciliation',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              ...data.settlementNotes.map(
                (note) => pw.Bullet(
                  text: note,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 24),
            ],

            // Formal Sign-Off Signature Box
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CERTIFICATION & SIGN-OFF',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'We certify that this financial ledger represents a true, accurate, and final accounting of all expenses incurred during the expedition.',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 28),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(width: 160, height: 1, color: PdfColors.black),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Leader: ${data.organizerName}',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text('Date: ________________', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(width: 160, height: 1, color: PdfColors.black),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Auditor: ${data.auditorName}',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text('Date: ________________', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }
}
