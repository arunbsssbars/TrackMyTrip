import 'package:intl/intl.dart';

class CurrencyFormatter {
  static const String fallbackCurrency = 'INR';

  static const List<String> commonCurrencies = [
    'INR', 'USD', 'EUR', 'GBP', 'AED', 'THB', 'SGD', 'JPY', 
    'CAD', 'AUD', 'CHF', 'MYR', 'IDR', 'SAR', 'QAR', 'KWD', 'TRY', 'RUB'
  ];

  /// Format an amount into a currency string gracefully.
  /// Never defaults to '$' unless currency is explicitly USD.
  static String format(double amount, {String? currency}) {
    final cur = (currency != null && currency.trim().isNotEmpty) ? currency.trim() : fallbackCurrency;
    final symbol = getCurrencySymbol(cur);
    
    // Use Indian Lakh/Crore grouping for INR, standard international for others
    final NumberFormat formatter;
    if (cur.toUpperCase() == 'INR' || symbol == '₹') {
      formatter = NumberFormat('#,##,##0.00');
    } else {
      formatter = NumberFormat('#,##0.00');
    }
    
    return '$symbol${formatter.format(amount)}';
  }

  /// Compact formatting (e.g. ₹5K or $12.5K)
  static String formatCompact(double amount, {String? currency}) {
    final cur = (currency != null && currency.trim().isNotEmpty) ? currency.trim() : fallbackCurrency;
    final symbol = getCurrencySymbol(cur);
    final formatter = NumberFormat.compact();
    return '$symbol${formatter.format(amount)}';
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
        return '$trimmed ';
    }
  }
}
