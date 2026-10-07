import '../../models/receipt_parsed_data.dart';

class ReceiptParserEngine {
  /// Parses raw OCR text into structured receipt data with defensive heuristics.
  static ReceiptParsedData parse(String rawText) {
    if (rawText.trim().isEmpty) {
      return const ReceiptParsedData(
        merchantName: 'Unknown Merchant',
        totalAmount: 0.0,
        category: 'Emergency & Misc',
        confidenceScore: 0.0,
      );
    }

    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 1. Currency Detection
    final currency = _detectCurrency(rawText);

    // 2. Merchant Extraction
    final merchant = _extractMerchant(lines);

    // 3. Category Detection
    final category = _detectCategory(rawText.toLowerCase());

    // 4. Financial Amounts (Total, Tax, Subtotal)
    final amounts = _extractAmounts(lines);
    final total = amounts['total'] ?? 0.0;
    final tax = amounts['tax'] ?? 0.0;

    // 5. Line items
    final items = _extractLineItems(lines);

    // 6. Invoice / Bill number
    final invoice = _extractInvoiceNumber(rawText);

    // 7. Date parsing
    final date = _extractDate(rawText);

    // 8. Confidence Score
    var score = 0.3;
    if (total > 0) score += 0.3;
    if (merchant != 'Unknown Merchant') score += 0.2;
    if (items.isNotEmpty) score += 0.1;
    if (date != null) score += 0.1;

    return ReceiptParsedData(
      merchantName: merchant,
      totalAmount: total,
      taxAmount: tax,
      currency: currency,
      category: category,
      date: date,
      invoiceNumber: invoice,
      items: items,
      confidenceScore: score.clamp(0.0, 1.0),
      rawText: rawText,
    );
  }

  static String _detectCurrency(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('₹') || lower.contains('rs.') || lower.contains('rs ') || lower.contains('inr')) {
      return 'INR';
    }
    if (lower.contains('€') || lower.contains('eur')) {
      return 'EUR';
    }
    if (lower.contains('£') || lower.contains('gbp')) {
      return 'GBP';
    }
    if (lower.contains(r'$') || lower.contains('usd')) {
      return 'USD';
    }
    return 'INR'; // Standard default for TrackMyTrip
  }

  static String _extractMerchant(List<String> lines) {
    final ignoredPatterns = [
      RegExp(r'^(tax invoice|invoice|cash memo|bill|receipt|gstin|welcome|date|time)', caseSensitive: false),
      RegExp(r'^\d+[\s\-/]'),
      RegExp(r'^(tel|phone|ph|mobile|email|contact|www|http)', caseSensitive: false),
    ];

    for (final line in lines.take(5)) {
      final isIgnored = ignoredPatterns.any((p) => p.hasMatch(line));
      if (!isIgnored && line.length >= 3 && line.length <= 40) {
        // Strip out trailing colons or non-alphanumeric noise
        final cleaned = line.replaceAll(RegExp(r'[:#*]+$'), '').trim();
        if (cleaned.isNotEmpty) return cleaned;
      }
    }
    return lines.isNotEmpty ? lines.first : 'Unknown Merchant';
  }

  static Map<String, double> _extractAmounts(List<String> lines) {
    double total = 0.0;
    double tax = 0.0;

    final totalRegex = RegExp(
      r'(?:grand\s+total|total\s+amount|net\s+amount|total\s+payable|balance\s+due|total)\s*[:=]?\s*(?:₹|rs\.?|\$|€|£)?\s*([0-9,]+\.?[0-9]{0,2})',
      caseSensitive: false,
    );

    final taxRegex = RegExp(
      r'(?:gst|tax|vat|cgst\s*\+\s*sgst|service\s+tax)\s*[:=]?\s*(?:₹|rs\.?|\$|€|£)?\s*([0-9,]+\.?[0-9]{0,2})',
      caseSensitive: false,
    );

    for (final line in lines) {
      final totalMatch = totalRegex.firstMatch(line);
      if (totalMatch != null) {
        final val = _parseNumber(totalMatch.group(1));
        if (val > total && val < 500000) total = val;
      }

      final taxMatch = taxRegex.firstMatch(line);
      if (taxMatch != null) {
        final val = _parseNumber(taxMatch.group(1));
        if (val > tax && val < 50000) tax = val;
      }
    }

    // Fallback: If no explicit 'total' line found, find the maximum reasonable currency number
    if (total == 0.0) {
      final genericNum = RegExp(r'(?:₹|rs\.?|\$|€|£)?\s*([0-9]{1,6}(?:\.[0-9]{2}))');
      for (final line in lines) {
        final matches = genericNum.allMatches(line);
        for (final m in matches) {
          final val = _parseNumber(m.group(1));
          if (val > total && val < 200000) {
            total = val;
          }
        }
      }
    }

    return {'total': total, 'tax': tax};
  }

  static List<ReceiptLineItem> _extractLineItems(List<String> lines) {
    final items = <ReceiptLineItem>[];
    final itemPattern = RegExp(
      r'^(?:(\d+)\s*[xX*]\s+)?([A-Za-z0-9\s\-_&]{3,28})\s+(?:₹|rs\.?|\$|€|£)?\s*([0-9]+(?:\.[0-9]{2})?)$',
    );

    for (final line in lines) {
      final m = itemPattern.firstMatch(line.trim());
      if (m != null) {
        final qty = int.tryParse(m.group(1) ?? '1') ?? 1;
        final name = m.group(2)?.trim() ?? '';
        final price = _parseNumber(m.group(3));
        if (name.isNotEmpty && price > 0 && !name.toLowerCase().contains('total')) {
          items.add(ReceiptLineItem(title: name, price: price, quantity: qty));
        }
      }
    }

    return items;
  }

  static String? _extractInvoiceNumber(String text) {
    final m = RegExp(
      r'(?:invoice|bill|receipt|order|txn)\s*(?:no|num|#|id)?\s*[:=]?\s*([a-zA-Z0-9\-_/]{4,20})',
      caseSensitive: false,
    ).firstMatch(text);
    return m?.group(1);
  }

  static DateTime? _extractDate(String text) {
    // Matches 24/12/2026, 2026-12-24, 24-Dec-2026
    final dateMatch = RegExp(
      r'\b(\d{1,2})[\/\-\.](\d{1,2}|[A-Za-z]{3})[\/\-\.](\d{2,4})\b',
    ).firstMatch(text);

    if (dateMatch != null) {
      final part1 = dateMatch.group(1)!;
      final part2 = dateMatch.group(2)!;
      final part3 = dateMatch.group(3)!;

      final day = int.tryParse(part1);
      final year = int.tryParse(part3.length == 2 ? '20$part3' : part3);
      final month = int.tryParse(part2);

      if (day != null && year != null && month != null && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  static String _detectCategory(String lower) {
    if (lower.contains(RegExp(r'\b(restaurant|dining|food|kitchen|bistro|dhaba|lunch|dinner|breakfast|meal|pizza|burger|biryani|thali|paneer|chai|coffee|bakery|snacks|cafe)\b'))) {
      return 'Food & Drinks';
    }
    if (lower.contains(RegExp(r'\b(petrol|diesel|fuel|cng|gas station|iocl|bpcl|hpcl|shell|pump)\b'))) {
      return 'Fuel / Gas';
    }
    if (lower.contains(RegExp(r'\b(hotel|resort|lodge|inn|motel|suites|stay|hostel|room|checkout|airbnb)\b'))) {
      return 'Accommodation';
    }
    if (lower.contains(RegExp(r'\b(toll|fastag|nhai|expressway|highway)\b'))) {
      return 'Transport & Toll';
    }
    if (lower.contains(RegExp(r'\b(cab|taxi|uber|ola|flight|railway|train|bus|metro)\b'))) {
      return 'Transport & Toll';
    }
    if (lower.contains(RegExp(r'\b(ticket|entry|museum|park|cinema|tour|safari|amusement)\b'))) {
      return 'Activities & Tickets';
    }
    if (lower.contains(RegExp(r'\b(supermarket|mart|store|retail|shopping|clothes|mall|grocery)\b'))) {
      return 'Shopping & Souvenirs';
    }
    return 'Food & Drinks';
  }

  static double _parseNumber(String? s) {
    if (s == null) return 0.0;
    final cleaned = s.replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }
}
