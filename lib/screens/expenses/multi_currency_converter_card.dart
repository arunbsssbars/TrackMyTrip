import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/currency_exchange_service.dart';
import '../../core/theme/app_theme.dart';

class MultiCurrencyConverterCard extends StatefulWidget {
  final String initialFromCurrency;
  final String initialToCurrency;

  const MultiCurrencyConverterCard({
    super.key,
    this.initialFromCurrency = 'EUR',
    this.initialToCurrency = 'INR',
  });

  @override
  State<MultiCurrencyConverterCard> createState() => _MultiCurrencyConverterCardState();
}

class _MultiCurrencyConverterCardState extends State<MultiCurrencyConverterCard> {
  late TextEditingController _amountController;
  late String _fromCurrency;
  late String _toCurrency;
  double _convertedValue = 0.0;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: '100');
    _fromCurrency = widget.initialFromCurrency;
    _toCurrency = widget.initialToCurrency;
    _recalculate();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _recalculate() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    setState(() {
      _convertedValue = CurrencyExchangeService.convert(
        amount,
        from: _fromCurrency,
        to: _toCurrency,
      );
    });
  }

  void _swapCurrencies() {
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
      _recalculate();
    });
  }

  Widget _buildDropdown(String label, String value, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      items: AppConstants.defaultCurrencies
          .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rateText = CurrencyExchangeService.formatRateExplanation(_fromCurrency, _toCurrency);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row with robust ellipsis safeguards
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.currency_exchange_rounded, color: AppTheme.primary, size: 18),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Currency Calculator',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    rateText,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Amount Field
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _recalculate(),
              decoration: InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),

            // Currency Selectors Row
            Row(
              children: [
                Expanded(
                  child: _buildDropdown('From', _fromCurrency, (val) {
                    if (val != null) {
                      setState(() => _fromCurrency = val);
                      _recalculate();
                    }
                  }),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: const Icon(Icons.swap_horiz_rounded, color: AppTheme.primary),
                  tooltip: 'Swap Currencies',
                  onPressed: _swapCurrencies,
                ),
                Expanded(
                  child: _buildDropdown('To', _toCurrency, (val) {
                    if (val != null) {
                      setState(() => _toCurrency = val);
                      _recalculate();
                    }
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Conversion Result Box with Wrap
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 4,
                children: [
                  const Text('Converted Value:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  Text(
                    '$_toCurrency ${_convertedValue.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
