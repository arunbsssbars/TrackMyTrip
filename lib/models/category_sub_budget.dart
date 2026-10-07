import 'package:flutter/material.dart';

class CategorySubBudget {
  final String category;
  final double allocatedAmount;
  final double spentAmount;
  final String currencyCode;

  const CategorySubBudget({
    required this.category,
    required this.allocatedAmount,
    this.spentAmount = 0.0,
    this.currencyCode = 'INR',
  });

  double get remainingAmount => allocatedAmount - spentAmount;
  double get utilizationRatio => allocatedAmount > 0 ? (spentAmount / allocatedAmount) : 0.0;
  double get utilizationPercent => (utilizationRatio * 100).clamp(0.0, 999.0);

  bool get isExceeded => spentAmount > allocatedAmount;
  bool get isNearLimit => !isExceeded && utilizationRatio >= 0.8;

  Color get statusColor {
    if (isExceeded) return Colors.red.shade600;
    if (isNearLimit) return Colors.amber.shade700;
    return Colors.teal.shade600;
  }

  String get statusLabel {
    if (isExceeded) {
      final over = (spentAmount - allocatedAmount).toStringAsFixed(0);
      return 'Exceeded by $currencyCode $over';
    }
    if (isNearLimit) {
      return 'Warning: ${(utilizationRatio * 100).toStringAsFixed(0)}% used';
    }
    return '${(utilizationRatio * 100).toStringAsFixed(0)}% allocated';
  }

  Map<String, dynamic> toJson() => {
        'category': category,
        'allocatedAmount': allocatedAmount,
        'spentAmount': spentAmount,
        'currencyCode': currencyCode,
      };

  factory CategorySubBudget.fromJson(Map<String, dynamic> json) {
    return CategorySubBudget(
      category: json['category'] as String? ?? 'General',
      allocatedAmount: (json['allocatedAmount'] as num?)?.toDouble() ?? 0.0,
      spentAmount: (json['spentAmount'] as num?)?.toDouble() ?? 0.0,
      currencyCode: json['currencyCode'] as String? ?? 'INR',
    );
  }

  CategorySubBudget copyWith({
    String? category,
    double? allocatedAmount,
    double? spentAmount,
    String? currencyCode,
  }) {
    return CategorySubBudget(
      category: category ?? this.category,
      allocatedAmount: allocatedAmount ?? this.allocatedAmount,
      spentAmount: spentAmount ?? this.spentAmount,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }
}
