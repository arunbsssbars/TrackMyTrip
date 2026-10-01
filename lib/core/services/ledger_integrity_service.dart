import 'package:flutter/foundation.dart';
import '../utils/currency_formatter.dart';
import '../../models/expense.dart';
import '../../models/settlement.dart';
import '../../models/trip_member.dart';

/// Senior-developer Enterprise Financial Ledger Integrity Validator.
/// Enforces:
/// 1. Conservation of Money Invariant: sum(splits.allocatedAmount) == expense.totalAmount
/// 2. Zero-Sum Group Settlement Invariant: sum(memberNetBalances) == 0.00
/// 3. Fixed-point integer-cent verification
class LedgerAuditReport {
  final bool isConservationValid;
  final bool isZeroSumValid;
  final double totalExpenseVolume;
  final double totalSettlementVolume;
  final double groupImbalanceDrift;
  final List<String> splitViolations;

  const LedgerAuditReport({
    required this.isConservationValid,
    required this.isZeroSumValid,
    required this.totalExpenseVolume,
    required this.totalSettlementVolume,
    required this.groupImbalanceDrift,
    required this.splitViolations,
  });

  bool get isClean => isConservationValid && isZeroSumValid && splitViolations.isEmpty;
}

class LedgerIntegrityService {
  /// Verifies that an individual expense strictly satisfies conservation of money:
  /// sum(split.allocatedAmount) == expense.totalAmount within 1 integer cent (< 0.009).
  static bool validateExpenseConservation(Expense expense) {
    if (expense.splits.isEmpty) return false;
    final totalCents = (expense.totalAmount * 100).round();
    final allocatedCents = expense.splits.fold<int>(
      0,
      (sum, s) => sum + (s.allocatedAmount * 100).round(),
    );
    return (totalCents - allocatedCents).abs() == 0;
  }

  /// Calculates net balances for all members using fixed-point integer cents
  /// to eliminate any floating-point drift.
  static Map<String, double> computeIntegerCentsBalances({
    required List<TripMember> members,
    required List<Expense> expenses,
    required List<Settlement> settlements,
  }) {
    final Map<String, int> centsBalances = {};
    for (final m in members) {
      centsBalances[m.id] = 0;
    }

    for (final exp in expenses) {
      final totalCents = (exp.totalAmount * 100).round();
      centsBalances[exp.paidByMemberId] = (centsBalances[exp.paidByMemberId] ?? 0) + totalCents;

      for (final split in exp.splits) {
        final splitCents = (split.allocatedAmount * 100).round();
        centsBalances[split.memberId] = (centsBalances[split.memberId] ?? 0) - splitCents;
      }
    }

    for (final set in settlements) {
      final setCents = (set.amount * 100).round();
      centsBalances[set.payerMemberId] = (centsBalances[set.payerMemberId] ?? 0) + setCents;
      centsBalances[set.receiverMemberId] = (centsBalances[set.receiverMemberId] ?? 0) - setCents;
    }

    final Map<String, double> finalBalances = {};
    centsBalances.forEach((id, cents) {
      finalBalances[id] = cents / 100.0;
    });

    return finalBalances;
  }

  /// Audits the entire trip financial state and produces a diagnostic report.
  static LedgerAuditReport auditTripLedger({
    required List<TripMember> members,
    required List<Expense> expenses,
    required List<Settlement> settlements,
  }) {
    final violations = <String>[];
    double totalExp = 0.0;
    double totalSet = 0.0;

    for (final exp in expenses) {
      totalExp += exp.totalAmount;
      if (!validateExpenseConservation(exp)) {
        final sumSplits = exp.splits.fold<double>(0.0, (acc, s) => acc + s.allocatedAmount);
        violations.add(
          'Expense "${exp.title}" (${exp.id}): Total (${exp.totalAmount}) != Splits sum ($sumSplits)',
        );
      }
    }

    for (final s in settlements) {
      totalSet += s.amount;
    }

    final balances = computeIntegerCentsBalances(
      members: members,
      expenses: expenses,
      settlements: settlements,
    );

    final netSum = balances.values.fold<double>(0.0, (acc, b) => acc + b);
    final drift = CurrencyFormatter.roundTo2Decimals(netSum);

    if (kDebugMode && violations.isNotEmpty) {
      debugPrint('[LedgerIntegrityService] Detected ${violations.length} conservation violation(s):');
      for (final v in violations) {
        debugPrint('  • $v');
      }
    }

    return LedgerAuditReport(
      isConservationValid: violations.isEmpty,
      isZeroSumValid: drift.abs() < 0.01,
      totalExpenseVolume: totalExp,
      totalSettlementVolume: totalSet,
      groupImbalanceDrift: drift,
      splitViolations: violations,
    );
  }
}
