import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/receipt_parsed_data.dart';

class ReceiptCorrectionSheet extends StatefulWidget {
  final ReceiptParsedData initialData;
  final ValueChanged<ReceiptParsedData> onConfirmed;

  const ReceiptCorrectionSheet({
    super.key,
    required this.initialData,
    required this.onConfirmed,
  });

  static Future<ReceiptParsedData?> show(
    BuildContext context, {
    required ReceiptParsedData initialData,
  }) {
    return showModalBottomSheet<ReceiptParsedData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReceiptCorrectionSheet(
        initialData: initialData,
        onConfirmed: (data) => Navigator.pop(ctx, data),
      ),
    );
  }

  @override
  State<ReceiptCorrectionSheet> createState() => _ReceiptCorrectionSheetState();
}

class _ReceiptCorrectionSheetState extends State<ReceiptCorrectionSheet> {
  late TextEditingController _merchantController;
  late TextEditingController _amountController;
  late TextEditingController _taxController;
  late String _currency;
  late String _category;
  late List<ReceiptLineItem> _items;

  final List<String> _categories = [
    'Food & Drinks',
    'Fuel / Gas',
    'Accommodation',
    'Transport & Toll',
    'Activities & Tickets',
    'Shopping & Souvenirs',
    'Snacks & Refreshment',
    'Emergency & Misc',
  ];

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(text: widget.initialData.merchantName);
    _amountController = TextEditingController(
      text: widget.initialData.totalAmount > 0 ? widget.initialData.totalAmount.toStringAsFixed(2) : '',
    );
    _taxController = TextEditingController(
      text: widget.initialData.taxAmount > 0 ? widget.initialData.taxAmount.toStringAsFixed(2) : '',
    );
    _currency = widget.initialData.currency;
    _category = _categories.contains(widget.initialData.category)
        ? widget.initialData.category
        : 'Food & Drinks';
    _items = List.from(widget.initialData.items);
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _taxController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final tax = double.tryParse(_taxController.text.trim()) ?? 0.0;
    final merchant = _merchantController.text.trim().isEmpty ? 'Receipt Expense' : _merchantController.text.trim();

    final result = widget.initialData.copyWith(
      merchantName: merchant,
      totalAmount: amount,
      taxAmount: tax,
      currency: _currency,
      category: _category,
      items: _items,
    );
    widget.onConfirmed(result);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: (screenHeight * 0.9).clamp(400.0, 750.0),
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 20 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(100),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header row with confidence badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.document_scanner_rounded, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Review Receipt Scan',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'AI Confidence: ${(widget.initialData.confidenceScore * 100).toInt()}% • Verify details',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 24),
          // Scrollable inputs
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Merchant input
                  const Text('Merchant / Vendor Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _merchantController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Mountain Cafe or Shell Fuel',
                      prefixIcon: const Icon(Icons.storefront_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Amount & Currency Row (Adaptive AQIL layout)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final amountWidget = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Amount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              prefixIcon: const Icon(Icons.payments_rounded, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ],
                      );

                      final currencyWidget = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Currency', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: AppConstants.defaultCurrencies.contains(_currency) ? _currency : 'INR',
                            items: AppConstants.defaultCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _currency = val);
                            },
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            ),
                          ),
                        ],
                      );

                      if (constraints.maxWidth < 360) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            amountWidget,
                            const SizedBox(height: 12),
                            currencyWidget,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: amountWidget),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: currencyWidget),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // Category Chips
                  const Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final selected = _category == cat;
                      return ChoiceChip(
                        label: Text(cat, style: TextStyle(fontSize: 11, color: selected ? Colors.white : null)),
                        selected: selected,
                        selectedColor: AppTheme.primary,
                        onSelected: (_) => setState(() => _category = cat),
                      );
                    }).toList(),
                  ),

                  // Optional Line Items section
                  if (_items.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Detected Line Items', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withAlpha(50)),
                      ),
                      child: Column(
                        children: _items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Text('${item.quantity}x ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Expanded(child: Text(item.title, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                Text('$_currency ${item.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Action button
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Accept & Pre-fill Expense', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
