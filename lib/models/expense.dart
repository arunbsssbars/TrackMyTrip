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
  final double totalAmount; // Converted / stored in trip base currency
  final String currency; // Base trip currency
  final String category;
  final String paidByMemberId;
  final SplitType splitType;
  final List<ExpenseSplit> splits;
  final String? receiptImagePath;
  final String? notes;
  final DateTime createdAt;

  // Multi-Currency / Foreign Exchange fields
  final String? originalCurrency;
  final double? originalAmount;
  final double? exchangeRate;
  final bool isPersonal;

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
    this.originalCurrency,
    this.originalAmount,
    this.exchangeRate,
    this.isPersonal = false,
  });

  bool get hasForeignConversion =>
      originalCurrency != null &&
      originalCurrency!.isNotEmpty &&
      originalCurrency!.toUpperCase() != currency.toUpperCase() &&
      originalAmount != null &&
      originalAmount! > 0;

  String? get locationName {
    if (notes == null) return null;
    final match = RegExp(r'📍 Location:\s*([^\n]+)').firstMatch(notes!);
    return match?.group(1)?.trim();
  }

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
    String? originalCurrency,
    double? originalAmount,
    double? exchangeRate,
    bool? isPersonal,
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
      originalCurrency: originalCurrency ?? this.originalCurrency,
      originalAmount: originalAmount ?? this.originalAmount,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      isPersonal: isPersonal ?? this.isPersonal,
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
      'originalCurrency': originalCurrency,
      'originalAmount': originalAmount,
      'exchangeRate': exchangeRate,
      'isPersonal': isPersonal,
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
      originalCurrency: json['originalCurrency'] as String?,
      originalAmount: (json['originalAmount'] as num?)?.toDouble(),
      exchangeRate: (json['exchangeRate'] as num?)?.toDouble(),
      isPersonal: json['isPersonal'] == true || json['isPersonal'] == 1,
    );
  }
}
