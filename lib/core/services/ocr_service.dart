import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String title;
  final double amount;
  final String category;
  final String date;

  OcrResult({
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
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
          category: 'Miscellaneous',
          date: DateTime.now().toIso8601String(),
        );
      }

      double maxAmount = 0.0;
      String storeName = 'Unknown Store';
      
      // Split text into lines for parsing
      final lines = rawText.split('\n');
      
      // 1. Extract Store Name (Assume first non-empty line with text)
      for (final line in lines) {
        final clean = line.trim();
        if (clean.length > 2 && !clean.contains(RegExp(r'^\d'))) {
          storeName = clean;
          break;
        }
      }

      // 2. Extract Max Amount (Look for currency patterns)
      final amountRegex = RegExp(r'\$?\s*(\d{1,4}[.,]\d{2})');
      for (final line in lines) {
        final matches = amountRegex.allMatches(line);
        for (final match in matches) {
          final amtStr = match.group(1)?.replaceAll(',', '.') ?? '0';
          final val = double.tryParse(amtStr) ?? 0.0;
          if (val > maxAmount && val < 10000) { // arbitrary cap to avoid huge numbers like dates/phones being parsed
            maxAmount = val;
          }
        }
      }

      // 3. Fallback logic
      if (storeName == 'Unknown Store') {
        storeName = 'Parsed Receipt';
      }

      return OcrResult(
        title: storeName,
        amount: maxAmount,
        category: 'Miscellaneous',
        date: DateTime.now().toIso8601String(),
      );

    } catch (e) {
      return OcrResult(
        title: 'Error Parsing Receipt',
        amount: 0.0,
        category: 'Error',
        date: DateTime.now().toIso8601String(),
      );
    } finally {
      textRecognizer.close();
    }
  }
}
