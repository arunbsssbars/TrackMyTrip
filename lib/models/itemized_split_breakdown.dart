class ItemizedSplitBreakdown {
  final double totalAmount;
  final String currency;
  final String splitMethod; // 'equal', 'percentage', 'shares'
  final Map<String, double> memberOwedAmounts;
  final double roundingAdjustment;

  const ItemizedSplitBreakdown({
    required this.totalAmount,
    this.currency = 'INR',
    required this.splitMethod,
    required this.memberOwedAmounts,
    this.roundingAdjustment = 0.0,
  });

  double get calculatedSum =>
      memberOwedAmounts.values.fold(0.0, (acc, val) => acc + val);

  bool get isReconciled =>
      (calculatedSum - totalAmount).abs() < 0.02; // Within 2 paise/cents

  Map<String, dynamic> toJson() => {
        'totalAmount': totalAmount,
        'currency': currency,
        'splitMethod': splitMethod,
        'memberOwedAmounts': memberOwedAmounts,
        'roundingAdjustment': roundingAdjustment,
      };

  factory ItemizedSplitBreakdown.fromJson(Map<String, dynamic> json) {
    return ItemizedSplitBreakdown(
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'INR',
      splitMethod: json['splitMethod'] as String? ?? 'equal',
      memberOwedAmounts: (json['memberOwedAmounts'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
          ) ??
          {},
      roundingAdjustment:
          (json['roundingAdjustment'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
