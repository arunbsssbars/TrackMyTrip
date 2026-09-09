import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(double amount, {String currency = 'USD'}) {
    final symbol = getCurrencySymbol(currency);
    final formatter = NumberFormat('#,##0.00');
    return '$symbol${formatter.format(amount)}';
  }

  static String getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'INR':
        return '₹';
      case 'USD':
      case 'CAD':
      case 'AUD':
      case 'SGD':
      case 'NZD':
        return '\$';
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
        return '$currency ';
    }
  }
}
