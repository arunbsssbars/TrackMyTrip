import 'package:url_launcher/url_launcher.dart';
import '../../models/upi_payment_intent.dart';

class UpiSettlementService {
  static final UpiSettlementService _instance = UpiSettlementService._internal();
  factory UpiSettlementService() => _instance;
  UpiSettlementService._internal();

  /// Creates a validated UPI payment intent
  UpiPaymentIntent createIntent({
    required String payeeVpa,
    required String payeeName,
    required double amount,
    String? tripTitle,
  }) {
    final note = tripTitle != null && tripTitle.isNotEmpty
        ? 'Settlement: $tripTitle'
        : 'Trip Settlement';

    return UpiPaymentIntent(
      payeeVpa: payeeVpa.trim(),
      payeeName: payeeName.trim(),
      amount: double.parse(amount.toStringAsFixed(2)),
      transactionNote: note,
    );
  }

  /// Attempts to launch UPI app via platform url launcher
  Future<bool> launchUpiPayment(UpiPaymentIntent intent) async {
    final uri = Uri.parse(intent.upiUriString);
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
