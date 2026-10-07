import 'package:flutter/material.dart';
import '../../models/executive_ledger_data.dart';
import '../../core/services/executive_pdf_ledger_service.dart';

class PdfLedgerPreviewDialog extends StatefulWidget {
  final ExecutiveLedgerData data;
  final VoidCallback? onPrintOrShare;

  const PdfLedgerPreviewDialog({
    super.key,
    required this.data,
    this.onPrintOrShare,
  });

  @override
  State<PdfLedgerPreviewDialog> createState() => _PdfLedgerPreviewDialogState();
}

class _PdfLedgerPreviewDialogState extends State<PdfLedgerPreviewDialog> {
  bool _isGenerating = false;

  Future<void> _handleGenerate() async {
    setState(() => _isGenerating = true);
    try {
      await ExecutivePdfLedgerService().generateLedgerPdf(widget.data);
      widget.onPrintOrShare?.call();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.data;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 440, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.teal.withAlpha(40),
                      child: Icon(Icons.picture_as_pdf_rounded, color: Colors.teal.shade800, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Executive Trip Ledger',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            data.tripTitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Summary info box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Audited Total', '${data.currency} ${data.totalExpenses.toStringAsFixed(2)}'),
                      const SizedBox(height: 6),
                      _buildInfoRow('Total Transactions', '${data.expenseEntries.length} items'),
                      const SizedBox(height: 6),
                      _buildInfoRow('Lead Certifier', data.organizerName),
                      const SizedBox(height: 6),
                      _buildInfoRow('Auditor Sign-off', data.auditorName),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  'Includes ISO compliance signature block, transaction ledger, and final settlement balances.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),

                // Action buttons - Responsive Wrap
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context, rootNavigator: true).maybePop(),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                        ),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isGenerating ? null : _handleGenerate,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isGenerating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.print_rounded, size: 18),
                        label: Text(_isGenerating ? 'Rendering...' : 'Export PDF Ledger'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
