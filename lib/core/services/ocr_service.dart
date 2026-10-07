import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../models/receipt_parsed_data.dart';
import 'receipt_parser_engine.dart';

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
  /// Extracts structured receipt data from image using ML Kit and ReceiptParserEngine.
  static Future<ReceiptParsedData> extractStructuredReceipt(String imagePath) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      return ReceiptParserEngine.parse(recognizedText.text);
    } catch (e) {
      if (kDebugMode) debugPrint('[OcrService] Error processing image: $e');
      return const ReceiptParsedData(
        merchantName: 'Unknown Store',
        totalAmount: 0.0,
        category: 'Emergency & Misc',
        confidenceScore: 0.0,
      );
    } finally {
      textRecognizer.close();
    }
  }

  /// Extracts text and parses into legacy OcrResult for backward compatibility.
  static Future<OcrResult> extractFromReceipt(String imagePath) async {
    final parsed = await extractStructuredReceipt(imagePath);
    return OcrResult(
      title: parsed.merchantName.isNotEmpty ? parsed.merchantName : 'Parsed Receipt',
      amount: parsed.totalAmount,
      category: parsed.category,
      date: (parsed.date ?? DateTime.now()).toIso8601String(),
      description: parsed.invoiceNumber != null ? 'Invoice #${parsed.invoiceNumber}' : '',
    );
  }
}
