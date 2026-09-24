import 'expense_split.dart';

enum SplitType {
  equal,
  exact,
  percentage,
  shares,
}

class Expense {
  final String id;
  final String tripId;
  final String? stoppageId; // Anchored to a stoppage / stop
  final String title;
  final double totalAmount;
  final String currency;
  final String category;
  final String paidByMemberId;
  final SplitType splitType;
  final List<ExpenseSplit> splits;
  final String? receiptImagePath;
  final String? notes;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.tripId,
    this.stoppageId,
    required this.title,
    required this.totalAmount,
    required this.currency,
    required this.category,
    required this.paidByMemberId,
    required this.splitType,
    required this.splits,
    this.receiptImagePath,
    this.notes,
    required this.createdAt,
  });

  Expense copyWith({
    String? id,
    String? tripId,
    String? stoppageId,
    String? title,
    double? totalAmount,
    String? currency,
    String? category,
    String? paidByMemberId,
    SplitType? splitType,
    List<ExpenseSplit>? splits,
    String? receiptImagePath,
    String? notes,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      stoppageId: stoppageId ?? this.stoppageId,
      title: title ?? this.title,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      paidByMemberId: paidByMemberId ?? this.paidByMemberId,
      splitType: splitType ?? this.splitType,
      splits: splits ?? this.splits,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'stoppageId': stoppageId,
      'title': title,
      'totalAmount': totalAmount,
      'currency': currency,
      'category': category,
      'paidByMemberId': paidByMemberId,
      'splitType': splitType.name,
      'splits': splits.map((s) => s.toJson()).toList(),
      'receiptImagePath': receiptImagePath,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      stoppageId: json['stoppageId'] as String?,
      title: json['title'] as String,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      currency: json['currency'] as String,
      category: json['category'] as String,
      paidByMemberId: json['paidByMemberId'] as String,
      splitType: SplitType.values.firstWhere(
        (e) => e.name == json['splitType'],
        orElse: () => SplitType.equal,
      ),
      splits: (json['splits'] as List<dynamic>?)
              ?.map((e) => ExpenseSplit.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      receiptImagePath: json['receiptImagePath'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
