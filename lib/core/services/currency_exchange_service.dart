import '../utils/currency_formatter.dart';

class CurrencyExchangeService {
  // Baseline rates pegged against USD (USD = 1.0)
  static final Map<String, double> _ratesAgainstUsd = {
    'USD': 1.0,
    'INR': 83.50,
    'EUR': 0.92,
    'GBP': 0.79,
    'AED': 3.67,
    'JPY': 152.20,
    'AUD': 1.52,
    'CAD': 1.37,
    'SGD': 1.34,
  };

  // User-customized local overrides (e.g. custom cash exchange rates)
  static final Map<String, double> _customOverrides = {};

  /// Retrieves the exchange rate between two currencies (from -> to).
  static double getRate(String from, String to) {
    final fromUpper = from.trim().toUpperCase();
    final toUpper = to.trim().toUpperCase();

    if (fromUpper == toUpper) return 1.0;

    // Check custom override pair e.g. "EUR_INR"
    final pairKey = '${fromUpper}_$toUpper';
    if (_customOverrides.containsKey(pairKey)) {
      return _customOverrides[pairKey]!;
    }

    final fromUsdRate = _ratesAgainstUsd[fromUpper] ?? 1.0;
    final toUsdRate = _ratesAgainstUsd[toUpper] ?? 1.0;

    // Rate = (to / USD) / (from / USD)
    if (fromUsdRate <= 0.0) return 1.0;
    return toUsdRate / fromUsdRate;
  }

  /// Converts an amount from one currency to another with 2-decimal rounded precision.
  static double convert(double amount, {required String from, required String to}) {
    if (amount == 0.0) return 0.0;
    final rate = getRate(from, to);
    final raw = amount * rate;
    return CurrencyFormatter.roundTo2Decimals(raw);
  }

  /// Sets a custom exchange rate for a specific currency pair (e.g. 1 EUR = 91.50 INR).
  static void setCustomRate(String from, String to, double rate) {
    if (rate <= 0.0) return;
    final fromUpper = from.trim().toUpperCase();
    final toUpper = to.trim().toUpperCase();
    _customOverrides['${fromUpper}_$toUpper'] = rate;
    _customOverrides['${toUpper}_$fromUpper'] = 1.0 / rate;
  }

  /// Resets custom overrides back to defaults.
  static void resetToDefaultRates() {
    _customOverrides.clear();
  }

  /// Formatted explanation string, e.g. "1 EUR = 90.76 INR"
  static String formatRateExplanation(String from, String to) {
    final rate = getRate(from, to);
    final formattedRate = (rate >= 10.0)
        ? rate.toStringAsFixed(2)
        : rate.toStringAsFixed(4);
    return '1 $from = $formattedRate $to';
  }

  /// Formats the converted result with localized symbol
  static String formatConverted(double amount, {required String from, required String to}) {
    final converted = convert(amount, from: from, to: to);
    return CurrencyFormatter.format(converted, currency: to);
  }
}
