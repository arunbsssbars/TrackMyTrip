class UpiPaymentIntent {
  final String payeeVpa;
  final String payeeName;
  final double amount;
  final String transactionNote;
  final String currency;

  const UpiPaymentIntent({
    required this.payeeVpa,
    required this.payeeName,
    required this.amount,
    this.transactionNote = 'Trip Settlement',
    this.currency = 'INR',
  });

  /// Canonical NPCI UPI specification format
  String get upiUriString {
    final encodedPn = Uri.encodeComponent(payeeName);
    final encodedTn = Uri.encodeComponent(transactionNote);
    final formattedAmt = amount.toStringAsFixed(2);
    return 'upi://pay?pa=$payeeVpa&pn=$encodedPn&am=$formattedAmt&cu=$currency&tn=$encodedTn';
  }

  bool get isValidVpa {
    // Standard VPA format: identifier@psp (e.g. user@okhdfcbank, 9876543210@upi)
    final regex = RegExp(r'^[\w.\-]+@[\w.\-]+$');
    return regex.hasMatch(payeeVpa.trim());
  }

  Map<String, dynamic> toJson() => {
        'payeeVpa': payeeVpa,
        'payeeName': payeeName,
        'amount': amount,
        'transactionNote': transactionNote,
        'currency': currency,
      };

  factory UpiPaymentIntent.fromJson(Map<String, dynamic> json) {
    return UpiPaymentIntent(
      payeeVpa: json['payeeVpa'] as String? ?? '',
      payeeName: json['payeeName'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      transactionNote: json['transactionNote'] as String? ?? 'Trip Settlement',
      currency: json['currency'] as String? ?? 'INR',
    );
  }
}
