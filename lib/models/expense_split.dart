class ExpenseSplit {
  final String memberId;
  final double allocatedAmount;
  final double? percentage;
  final double? shares;
  final bool isIncluded;

  const ExpenseSplit({
    required this.memberId,
    required this.allocatedAmount,
    this.percentage,
    this.shares,
    this.isIncluded = true,
  });

  ExpenseSplit copyWith({
    String? memberId,
    double? allocatedAmount,
    double? percentage,
    double? shares,
    bool? isIncluded,
  }) {
    return ExpenseSplit(
      memberId: memberId ?? this.memberId,
      allocatedAmount: allocatedAmount ?? this.allocatedAmount,
      percentage: percentage ?? this.percentage,
      shares: shares ?? this.shares,
      isIncluded: isIncluded ?? this.isIncluded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'memberId': memberId,
      'allocatedAmount': allocatedAmount,
      'percentage': percentage,
      'shares': shares,
      'isIncluded': isIncluded,
    };
  }

  factory ExpenseSplit.fromJson(Map<String, dynamic> json) {
    return ExpenseSplit(
      memberId: json['memberId'] as String,
      allocatedAmount: (json['allocatedAmount'] as num).toDouble(),
      percentage: (json['percentage'] as num?)?.toDouble(),
      shares: (json['shares'] as num?)?.toDouble(),
      isIncluded: json['isIncluded'] as bool? ?? true,
    );
  }
}
