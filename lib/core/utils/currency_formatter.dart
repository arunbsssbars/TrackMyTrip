import 'package:intl/intl.dart';

class CurrencyFormatter {
  static const String fallbackCurrency = 'INR';

  static const List<String> commonCurrencies = [
    'INR', 'USD', 'EUR', 'GBP', 'AED', 'THB', 'SGD', 'JPY', 
    'CAD', 'AUD', 'CHF', 'MYR', 'IDR', 'SAR', 'QAR', 'KWD', 'TRY', 'RUB'
  ];

  /// Format an amount into a currency string gracefully.
  /// Never defaults to '$' unless currency is explicitly USD.
  /// Non-finite amounts render as zero; negatives render as `-₹50.00`.
  static String format(double amount, {String? currency}) {
    final cur = (currency != null && currency.trim().isNotEmpty) ? currency.trim() : fallbackCurrency;
    final symbol = getCurrencySymbol(cur);
    final safe = _sanitize(amount);

    // Use Indian Lakh/Crore grouping for INR, standard international for others
    final NumberFormat formatter;
    if (cur.toUpperCase() == 'INR' || symbol == '₹') {
      formatter = NumberFormat('#,##,##0.00');
    } else {
      formatter = NumberFormat('#,##0.00');
    }

    final sign = safe < 0 ? '-' : '';
    return '$sign$symbol${formatter.format(safe.abs())}';
  }

  /// Converts NaN/Infinity to 0 and collapses negative-zero rounding artefacts.
  static double _sanitize(double amount) {
    if (amount.isNaN || amount.isInfinite) return 0.0;
    final rounded = roundTo2Decimals(amount);
    return rounded == 0 ? 0.0 : rounded;
  }

  /// Reliably rounds any double to 2 decimal places without IEEE-754 binary floating drift.
  static double roundTo2Decimals(double value) {
    if (value.isNaN || value.isInfinite) return 0.0;
    return ((value * 100).round()) / 100.0;
  }

  /// Compact formatting (e.g. ₹5K or $12.5K)
  static String formatCompact(double amount, {String? currency}) {
    final cur = (currency != null && currency.trim().isNotEmpty) ? currency.trim() : fallbackCurrency;
    final symbol = getCurrencySymbol(cur);
    final safe = _sanitize(amount);
    final formatter = NumberFormat.compact();
    final sign = safe < 0 ? '-' : '';
    return '$sign$symbol${formatter.format(safe.abs())}';
  }

  /// Format an amount with secondary foreign currency conversion tag
  static String formatWithConversion({
    required double baseAmount,
    required String baseCurrency,
    double? originalAmount,
    String? originalCurrency,
    double? exchangeRate,
  }) {
    final baseFormatted = format(baseAmount, currency: baseCurrency);
    if (originalAmount != null &&
        originalCurrency != null &&
        originalCurrency.toUpperCase() != baseCurrency.toUpperCase()) {
      final foreignFormatted = format(originalAmount, currency: originalCurrency);
      final rateTag = exchangeRate != null ? ' @ ${exchangeRate.toStringAsFixed(2)}' : '';
      return '$baseFormatted ($foreignFormatted$rateTag)';
    }
    return baseFormatted;
  }

  /// Returns the appropriate symbol for any currency code or symbol.
  static String getCurrencySymbol(String? currency) {
    if (currency == null || currency.trim().isEmpty) {
      return '₹';
    }

    final trimmed = currency.trim();
    // If already a symbol, return as is
    if (trimmed == '₹' || trimmed == '€' || trimmed == '£' || trimmed == '\$' ||
        trimmed == '¥' || trimmed == '฿' || trimmed == '₺' || trimmed == '₽' ||
        trimmed == '৳' || trimmed == '₩' || trimmed == 'CHF') {
      return trimmed == 'CHF' ? 'CHF ' : trimmed;
    }

    switch (trimmed.toUpperCase()) {
      case 'INR':
        return '₹';
      case 'USD':
        return '\$';
      case 'CAD':
        return 'CA\$';
      case 'AUD':
        return 'A\$';
      case 'SGD':
        return 'S\$';
      case 'NZD':
        return 'NZ\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
      case 'CNY':
        return '¥';
      case 'AED':
        return 'AED ';
      case 'SAR':
        return 'SAR ';
      case 'QAR':
        return 'QAR ';
      case 'KWD':
        return 'KWD ';
      case 'OMR':
        return 'OMR ';
      case 'BHD':
        return 'BHD ';
      case 'CHF':
        return 'CHF ';
      case 'THB':
        return '฿';
      case 'MYR':
        return 'RM ';
      case 'IDR':
        return 'Rp ';
      case 'KRW':
        return '₩';
      case 'TRY':
        return '₺';
      case 'BRL':
        return 'R\$ ';
      case 'MXN':
        return 'Mex\$ ';
      case 'ZAR':
        return 'R ';
      case 'RUB':
        return '₽';
      case 'NPR':
      case 'PKR':
      case 'LKR':
        return 'Rs ';
      case 'BDT':
        return '৳';
      default:
        // Only echo plausible ISO-4217 codes; junk ("null", long strings) falls back.
        final upper = trimmed.toUpperCase();
        if (RegExp(r'^[A-Z]{3}$').hasMatch(upper)) return '$upper ';
        return '₹';
    }
  }

  /// Estimated baseline exchange rate against INR for multi-currency previews
  static double getEstimatedRateToInr(String currency) {
    switch (currency.toUpperCase()) {
      case 'INR': return 1.0;
      case 'USD': return 86.50;
      case 'EUR': return 93.80;
      case 'GBP': return 110.20;
      case 'AED': return 23.55;
      case 'SGD': return 64.20;
      case 'THB': return 2.50;
      case 'JPY': return 0.58;
      case 'CAD': return 63.40;
      case 'AUD': return 56.10;
      default: return 86.50;
    }
  }

  /// Converts an amount between currencies using estimated benchmark rates
  static double convertEstimated(double amount, String fromCurrency, String toCurrency) {
    if (fromCurrency.toUpperCase() == toCurrency.toUpperCase()) return amount;
    final inrRateFrom = getEstimatedRateToInr(fromCurrency);
    final inrRateTo = getEstimatedRateToInr(toCurrency);
    if (inrRateTo <= 0) return amount;
    final inrAmount = amount * inrRateFrom;
    return inrAmount / inrRateTo;
  }
}
