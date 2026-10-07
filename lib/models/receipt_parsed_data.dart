class ReceiptLineItem {
  final String title;
  final double price;
  final int quantity;

  const ReceiptLineItem({
    required this.title,
    required this.price,
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'price': price,
    'quantity': quantity,
  };

  factory ReceiptLineItem.fromJson(Map<String, dynamic> json) => ReceiptLineItem(
    title: json['title'] as String? ?? 'Item',
    price: (json['price'] as num?)?.toDouble() ?? 0.0,
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
  );
}

class ReceiptParsedData {
  final String merchantName;
  final double totalAmount;
  final double taxAmount;
  final String currency;
  final String category;
  final DateTime? date;
  final String? invoiceNumber;
  final List<ReceiptLineItem> items;
  final double confidenceScore; // 0.0 to 1.0
  final String rawText;

  const ReceiptParsedData({
    required this.merchantName,
    required this.totalAmount,
    this.taxAmount = 0.0,
    this.currency = 'INR',
    required this.category,
    this.date,
    this.invoiceNumber,
    this.items = const [],
    this.confidenceScore = 0.8,
    this.rawText = '',
  });

  ReceiptParsedData copyWith({
    String? merchantName,
    double? totalAmount,
    double? taxAmount,
    String? currency,
    String? category,
    DateTime? date,
    String? invoiceNumber,
    List<ReceiptLineItem>? items,
    double? confidenceScore,
    String? rawText,
  }) {
    return ReceiptParsedData(
      merchantName: merchantName ?? this.merchantName,
      totalAmount: totalAmount ?? this.totalAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      date: date ?? this.date,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      items: items ?? this.items,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      rawText: rawText ?? this.rawText,
    );
  }
}
