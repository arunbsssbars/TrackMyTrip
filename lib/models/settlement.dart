class Settlement {
  final String id;
  final String tripId;
  final String payerMemberId;
  final String receiverMemberId;
  final double amount;
  final String currency;
  final DateTime settledAt;
  final String? notes;
  final String paymentMethod; // Cash, UPI, Venmo, PayPal, Bank Transfer

  const Settlement({
    required this.id,
    required this.tripId,
    required this.payerMemberId,
    required this.receiverMemberId,
    required this.amount,
    required this.currency,
    required this.settledAt,
    this.notes,
    this.paymentMethod = 'Cash',
  });

  Settlement copyWith({
    String? id,
    String? tripId,
    String? payerMemberId,
    String? receiverMemberId,
    double? amount,
    String? currency,
    DateTime? settledAt,
    String? notes,
    String? paymentMethod,
  }) {
    return Settlement(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      payerMemberId: payerMemberId ?? this.payerMemberId,
      receiverMemberId: receiverMemberId ?? this.receiverMemberId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      settledAt: settledAt ?? this.settledAt,
      notes: notes ?? this.notes,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'payerMemberId': payerMemberId,
      'receiverMemberId': receiverMemberId,
      'amount': amount,
      'currency': currency,
      'settledAt': settledAt.toIso8601String(),
      'notes': notes,
      'paymentMethod': paymentMethod,
    };
  }

  factory Settlement.fromJson(Map<String, dynamic> json) {
    return Settlement(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      payerMemberId: json['payerMemberId'] as String,
      receiverMemberId: json['receiverMemberId'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      settledAt: DateTime.parse(json['settledAt'] as String),
      notes: json['notes'] as String?,
      paymentMethod: json['paymentMethod'] as String? ?? 'Cash',
    );
  }
}
