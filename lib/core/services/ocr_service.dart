import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String title;
  final double amount;
  final String category;
  final String date;
  final String description;

  OcrResult({
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.description = '',
  });
}

class OcrService {
  /// Extracts real text and parses data from a receipt image using ML Kit.
  static Future<OcrResult> extractFromReceipt(String imagePath) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      String rawText = recognizedText.text;
      if (rawText.isEmpty) {
        return OcrResult(
          title: 'Unknown Receipt',
          amount: 0.0,
          category: 'Emergency & Misc',
          date: DateTime.now().toIso8601String(),
          description: '',
        );
      }

      double maxAmount = 0.0;
      String storeName = 'Unknown Store';
      final lowerText = rawText.toLowerCase();
      
      // Split text into lines for parsing
      final lines = rawText.split('\n');
      final meaningfulLines = <String>[];
      
      // 1. Extract Store Name (Assume first non-empty line with text)
      for (final line in lines) {
        final clean = line.trim();
        if (clean.length > 2 && !clean.contains(RegExp(r'^\d'))) {
          if (storeName == 'Unknown Store') {
            storeName = clean;
          }
        }
        if (clean.length > 3) {
          meaningfulLines.add(clean);
        }
      }

      // 2. Extract Max Amount (Prioritize labeled Total/Grand Total/Net Amount)
      final totalLabeledRegex = RegExp(
        r'(?:grand\s*total|net\s*payable|total\s*amount|final\s*amount|total|net|paid)\s*[:=]?\s*(?:rs\.?|inr|\$|€|£|₹)?\s*([0-9]{1,7}(?:[.,][0-9]{1,2})?)',
        caseSensitive: false,
      );
      for (final line in lines) {
        final match = totalLabeledRegex.firstMatch(line);
        if (match != null) {
          final amtStr = match.group(1)?.replaceAll(',', '.') ?? '0';
          final val = double.tryParse(amtStr) ?? 0.0;
          if (val > 0 && val < 10000000) {
            maxAmount = val;
            break;
          }
        }
      }

      // Fallback 1: Look for currency patterns
      if (maxAmount == 0.0) {
        final amountRegex = RegExp(r'(?:inr|rs\.?|\$|€|£|₹)\s*[:=]?\s*([0-9]{1,6}(?:[.,][0-9]{2})?)', caseSensitive: false);
        for (final line in lines) {
          final matches = amountRegex.allMatches(line);
          for (final match in matches) {
            final amtStr = match.group(1)?.replaceAll(',', '.') ?? '0';
            final val = double.tryParse(amtStr) ?? 0.0;
            if (val > maxAmount && val < 1000000) {
              maxAmount = val;
            }
          }
        }
      }

      // Fallback 2: General decimal amount check
      if (maxAmount == 0.0) {
        final fallbackRegex = RegExp(r'(\d{1,6}[.,]\d{2})');
        for (final line in lines) {
          final matches = fallbackRegex.allMatches(line);
          for (final match in matches) {
            final amtStr = match.group(1)?.replaceAll(',', '.') ?? '0';
            final val = double.tryParse(amtStr) ?? 0.0;
            if (val > maxAmount && val < 1000000) {
              maxAmount = val;
            }
          }
        }
      }

      // 3. Intelligent Category Detection via Keyword Matching
      String detectedCategory = 'Food & Drinks'; // default common receipt type
      if (lowerText.contains(RegExp(r'\b(petrol|diesel|fuel|cng|gas station|indian oil|bharat petroleum|hpcl|shell|iocl|bpcl|pump|dispenser)\b'))) {
        detectedCategory = 'Fuel / Gas';
      } else if (lowerText.contains(RegExp(r'\b(hotel|resort|lodge|inn|motel|suites|stay|hostel|room|checkout|checkin|oyo|airbnb|tariff)\b'))) {
        detectedCategory = 'Accommodation';
      } else if (lowerText.contains(RegExp(r'\b(toll|plaza|fastag|nhai|expressway|highway|tollway|turnpike)\b'))) {
        detectedCategory = 'Transport & Toll';
      } else if (lowerText.contains(RegExp(r'\b(cab|taxi|uber|ola|flight|airline|indigo|air india|irctc|railway|train|bus|redbus|metro|auto)\b'))) {
        detectedCategory = 'Transport & Toll';
      } else if (lowerText.contains(RegExp(r'\b(ticket|entry|museum|park|cinema|movie|theatre|pass|tour|guide|safari|amusement)\b'))) {
        detectedCategory = 'Activities & Tickets';
      } else if (lowerText.contains(RegExp(r'\b(supermarket|mart|store|retail|shopping|clothes|fashion|mall|bazaar|grocery|amazon|flipkart)\b'))) {
        detectedCategory = 'Shopping & Souvenirs';
      } else if (lowerText.contains(RegExp(r'\b(cafe|coffee|tea|chai|bakery|snacks|ice cream|beverage|juice|sweets)\b'))) {
        detectedCategory = 'Snacks & Refreshment';
      } else if (lowerText.contains(RegExp(r'\b(restaurant|dining|food|kitchen|bistro|dhaba|lunch|dinner|breakfast|meal|pizza|burger|dosa|biryani|zomato|swiggy|table)\b'))) {
        detectedCategory = 'Food & Drinks';
      } else {
        detectedCategory = 'Emergency & Misc';
      }

      // 4. Extract Description / Invoice details
      String description = '';
      final invoiceMatch = RegExp(r'(?:invoice|bill|receipt|order)\s*(?:no|num|#)?\s*[:=]?\s*([a-zA-Z0-9\-_/]+)', caseSensitive: false).firstMatch(rawText);
      if (invoiceMatch != null) {
        description = 'Invoice #${invoiceMatch.group(1)}';
      } else if (meaningfulLines.length > 2) {
        // Sample first 2-3 items as summary
        description = meaningfulLines.skip(1).take(2).join(' • ');
      }

      if (storeName == 'Unknown Store') {
        storeName = 'Parsed Receipt';
      }

      return OcrResult(
        title: storeName,
        amount: maxAmount,
        category: detectedCategory,
        date: DateTime.now().toIso8601String(),
        description: description,
      );

    } catch (e) {
      return OcrResult(
        title: 'Error Parsing Receipt',
        amount: 0.0,
        category: 'Emergency & Misc',
        date: DateTime.now().toIso8601String(),
        description: '',
      );
    } finally {
      textRecognizer.close();
    }
  }
}
