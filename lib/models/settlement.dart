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
  final bool isAdvance; // True if this is an advance contribution to the trip pool

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
    this.isAdvance = false,
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
    bool? isAdvance,
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
      isAdvance: isAdvance ?? this.isAdvance,
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
      'isAdvance': isAdvance,
    };
  }

  factory Settlement.fromJson(Map<String, dynamic> json) {
    return Settlement(
      id: json['id'] as String? ?? '',
      tripId: json['tripId'] as String? ?? '',
      payerMemberId: json['payerMemberId'] as String? ?? '',
      receiverMemberId: json['receiverMemberId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'INR',
      settledAt: json['settledAt'] != null
          ? (DateTime.tryParse(json['settledAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      notes: json['notes'] as String?,
      paymentMethod: json['paymentMethod'] as String? ?? 'Cash',
      isAdvance: json['isAdvance'] as bool? ?? false,
    );
  }
}
