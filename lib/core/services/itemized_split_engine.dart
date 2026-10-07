import '../../models/itemized_split_breakdown.dart';

class ItemizedSplitEngine {
  static final ItemizedSplitEngine _instance = ItemizedSplitEngine._internal();
  factory ItemizedSplitEngine() => _instance;
  ItemizedSplitEngine._internal();

  /// Splits an amount equally with rounding penny/paisa reconciliation
  ItemizedSplitBreakdown splitEqual({
    required double totalAmount,
    required List<String> memberNames,
    String currency = 'INR',
  }) {
    if (memberNames.isEmpty || totalAmount <= 0) {
      return ItemizedSplitBreakdown(
        totalAmount: totalAmount,
        currency: currency,
        splitMethod: 'equal',
        memberOwedAmounts: {},
      );
    }

    final count = memberNames.length;
    // Floor to 2 decimals
    final baseAmount = ((totalAmount / count) * 100).floorToDouble() / 100.0;
    final Map<String, double> amounts = {};

    for (final member in memberNames) {
      amounts[member] = baseAmount;
    }

    // Distribute remainder cents to first few members so total is exact
    final baseTotal = baseAmount * count;
    var remainderCents = ((totalAmount - baseTotal) * 100).round();

    for (int i = 0; i < count && remainderCents > 0; i++) {
      final m = memberNames[i];
      amounts[m] = double.parse((amounts[m]! + 0.01).toStringAsFixed(2));
      remainderCents--;
    }

    return ItemizedSplitBreakdown(
      totalAmount: totalAmount,
      currency: currency,
      splitMethod: 'equal',
      memberOwedAmounts: amounts,
    );
  }

  /// Splits amount by specified percentages (e.g. 50%, 30%, 20%)
  ItemizedSplitBreakdown splitByPercentages({
    required double totalAmount,
    required Map<String, double> memberPercentages,
    String currency = 'INR',
  }) {
    if (memberPercentages.isEmpty || totalAmount <= 0) {
      return ItemizedSplitBreakdown(
        totalAmount: totalAmount,
        currency: currency,
        splitMethod: 'percentage',
        memberOwedAmounts: {},
      );
    }

    final Map<String, double> amounts = {};
    double sum = 0.0;

    for (final entry in memberPercentages.entries) {
      final share = double.parse(((totalAmount * entry.value) / 100.0).toStringAsFixed(2));
      amounts[entry.key] = share;
      sum += share;
    }

    // Reconcile rounding delta
    final diff = double.parse((totalAmount - sum).toStringAsFixed(2));
    if (diff != 0.0 && amounts.isNotEmpty) {
      final firstKey = amounts.keys.first;
      amounts[firstKey] = double.parse((amounts[firstKey]! + diff).toStringAsFixed(2));
    }

    return ItemizedSplitBreakdown(
      totalAmount: totalAmount,
      currency: currency,
      splitMethod: 'percentage',
      memberOwedAmounts: amounts,
      roundingAdjustment: diff,
    );
  }

  /// Splits amount by custom unit shares (e.g. 2 shares, 1 share)
  ItemizedSplitBreakdown splitByShares({
    required double totalAmount,
    required Map<String, double> memberShares,
    String currency = 'INR',
  }) {
    if (memberShares.isEmpty || totalAmount <= 0) {
      return ItemizedSplitBreakdown(
        totalAmount: totalAmount,
        currency: currency,
        splitMethod: 'shares',
        memberOwedAmounts: {},
      );
    }

    final totalShares = memberShares.values.fold(0.0, (acc, s) => acc + s);
    if (totalShares <= 0) {
      return splitEqual(
        totalAmount: totalAmount,
        memberNames: memberShares.keys.toList(),
        currency: currency,
      );
    }

    final Map<String, double> amounts = {};
    double sum = 0.0;

    for (final entry in memberShares.entries) {
      final ratio = entry.value / totalShares;
      final share = double.parse((totalAmount * ratio).toStringAsFixed(2));
      amounts[entry.key] = share;
      sum += share;
    }

    final diff = double.parse((totalAmount - sum).toStringAsFixed(2));
    if (diff != 0.0 && amounts.isNotEmpty) {
      final firstKey = amounts.keys.first;
      amounts[firstKey] = double.parse((amounts[firstKey]! + diff).toStringAsFixed(2));
    }

    return ItemizedSplitBreakdown(
      totalAmount: totalAmount,
      currency: currency,
      splitMethod: 'shares',
      memberOwedAmounts: amounts,
      roundingAdjustment: diff,
    );
  }
}
