import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../models/trip.dart';
import '../../models/stoppage.dart';
import '../../models/expense.dart';
import '../utils/date_formatter.dart';
import '../utils/debt_simplifier.dart';

class PdfExportService {
  static Future<void> exportTripSummaryPdf({
    required Trip trip,
    required List<Stoppage> stoppages,
    required List<Expense> expenses,
    required Map<String, double> netBalances,
    required List<DebtTransfer> transfers,
  }) async {
    final pdf = pw.Document();

    final totalSpent = expenses.fold<double>(0, (sum, e) => sum + e.totalAmount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.teal800,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    trip.title,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${DateFormatter.formatShortDate(trip.startDate)} - ${DateFormatter.formatShortDate(trip.endDate)}',
                    style: const pw.TextStyle(color: PdfColors.teal100, fontSize: 13),
                  ),
                  if (trip.description != null && trip.description!.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Text(
                      trip.description!,
                      style: const pw.TextStyle(color: PdfColors.white, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Summary Stats Row
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildStatBox('Total Expenditure', _formatPdfCurrency(totalSpent, currency: trip.defaultCurrency)),
                _buildStatBox('Total Stoppages', '${stoppages.length} stops'),
                _buildStatBox('Travel Companions', '${trip.members.length} members'),
              ],
            ),
            pw.SizedBox(height: 24),

            // Stoppages & Itinerary
            pw.Text(
              'Itinerary & Stoppages',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
            ),
            pw.Divider(color: PdfColors.teal400, thickness: 1),
            pw.SizedBox(height: 8),
            if (stoppages.isEmpty)
              pw.Text('No stoppages recorded.', style: const pw.TextStyle(color: PdfColors.grey700))
            else
              pw.ListView.builder(
                itemCount: stoppages.length,
                itemBuilder: (context, index) {
                  final stop = stoppages[index];
                  final stopExpenses = expenses.where((e) => e.stoppageId == stop.id).toList();
                  final stopTotal = stopExpenses.fold<double>(0, (sum, e) => sum + e.totalAmount);

                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 8),
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 24,
                          height: 24,
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.teal700,
                            shape: pw.BoxShape.circle,
                          ),
                          child: pw.Center(
                            child: pw.Text('${index + 1}',
                                style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(stop.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                              if (stop.address != null)
                                pw.Text(stop.address!, style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9)),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'Category: ${stop.category}  |  Arrived: ${DateFormatter.formatDateTime(stop.arrivedAt)}',
                                style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
                              ),
                              if (stop.notes != null)
                                pw.Text('Note: ${stop.notes!}',
                                    style: pw.TextStyle(color: PdfColors.grey800, fontStyle: pw.FontStyle.italic, fontSize: 9)),
                            ],
                          ),
                        ),
                        if (stopTotal > 0)
                          pw.Text(
                            _formatPdfCurrency(stopTotal, currency: trip.defaultCurrency),
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.teal800, fontSize: 11),
                          ),
                      ],
                    ),
                  );
                },
              ),

            pw.SizedBox(height: 20),

            // Expense Breakdown Table
            pw.Text(
              'Itemized Activity & Stoppage Expenses',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
            ),
            pw.Divider(color: PdfColors.teal400, thickness: 1),
            pw.SizedBox(height: 8),

            pw.TableHelper.fromTextArray(
              headers: ['Expense Title', 'Category', 'Stoppage', 'Paid By', 'Amount'],
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
              cellStyle: const pw.TextStyle(fontSize: 9),
              data: expenses.map((e) {
                String stopName = 'General Trip';
                if (e.stoppageId != null) {
                  for (final s in stoppages) {
                    if (s.id == e.stoppageId) {
                      stopName = s.name;
                      break;
                    }
                  }
                }
                final payerName = trip.getMemberName(e.paidByMemberId);
                return [
                  e.title,
                  e.category,
                  stopName,
                  payerName,
                  _formatPdfCurrency(e.totalAmount, currency: e.currency),
                ];
              }).toList(),
            ),

            pw.SizedBox(height: 24),

            // Debt Settlement & Balances
            pw.Text(
              'Final Debt Settlement & Balances',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
            ),
            pw.Divider(color: PdfColors.teal400, thickness: 1),
            pw.SizedBox(height: 8),

            if (transfers.isEmpty)
              pw.Text('All accounts are balanced and settled!',
                  style: pw.TextStyle(color: PdfColors.green700, fontWeight: pw.FontWeight.bold))
            else
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: transfers.map((t) {
                  final fromName = trip.getMemberName(t.fromMemberId);
                  final toName = trip.getMemberName(t.toMemberId);
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 6),
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.orange50,
                      border: pw.Border.all(color: PdfColors.orange200),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('$fromName owes $toName',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text(
                          _formatPdfCurrency(t.amount, currency: trip.defaultCurrency),
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, color: PdfColors.orange900, fontSize: 11),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

            pw.SizedBox(height: 24),
            pw.Center(
              child: pw.Text(
                'Generated with TrackMyTrip  |  The Stoppage & Memory Expense Companion',
                style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
              ),
            ),
          ];
        },
      ),
    );

    final cleanTitle = trip.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${cleanTitle.isNotEmpty ? cleanTitle : "Trip"}_Summary',
    );
  }

  static pw.Widget _buildStatBox(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.teal900)),
        ],
      ),
    );
  }

  static String _formatPdfCurrency(double amount, {String? currency}) {
    final cur = (currency ?? 'INR').trim();
    final formattedNum = NumberFormat('#,##,##0.00').format(amount);
    if (cur.toUpperCase() == 'INR' || cur.contains('₹')) {
      return 'INR $formattedNum';
    }
    if (cur.toUpperCase() == 'USD' || cur == r'$') {
      return r'$' + formattedNum;
    }
    if (cur.toUpperCase() == 'EUR' || cur == '€') {
      return 'EUR $formattedNum';
    }
    if (cur.toUpperCase() == 'GBP' || cur == '£') {
      return 'GBP $formattedNum';
    }
    final cleanCur = cur.replaceAll(RegExp(r'[^\x00-\x7F]'), '').trim();
    final prefix = cleanCur.isNotEmpty ? cleanCur : 'INR';
    return '$prefix $formattedNum';
  }
}
