import 'currency_formatter.dart';

class DebtTransfer {
  final String fromMemberId;
  final String toMemberId;
  final double amount;

  const DebtTransfer({
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
  });

  @override
  String toString() => '$fromMemberId pays $amount to $toMemberId';
}

class DebtSimplifier {
  /// Takes a map of memberId -> netBalance (positive = owed money, negative = owes money)
  /// and returns the minimal list of direct transfers needed to settle all debts.
  static List<DebtTransfer> simplifyDebts(Map<String, double> netBalances) {
    final List<DebtTransfer> transfers = [];

    // Filter out zero balances and make a mutable copy with 2-decimal rounded precision
    final Map<String, double> balances = {};
    netBalances.forEach((memberId, balance) {
      final rounded = CurrencyFormatter.roundTo2Decimals(balance);
      if (rounded.abs() >= 0.01) {
        balances[memberId] = rounded;
      }
    });

    // Safety loop guard to prevent infinite looping on precision drift
    final int maxSteps = balances.length * 3 + 10;
    int stepCount = 0;

    while (balances.isNotEmpty && stepCount < maxSteps) {
      stepCount++;
      String? maxDebtorId;
      double minBalance = 0; // Most negative

      String? maxCreditorId;
      double maxBalance = 0; // Most positive

      balances.forEach((id, bal) {
        if (bal < minBalance) {
          minBalance = bal;
          maxDebtorId = id;
        }
        if (bal > maxBalance) {
          maxBalance = bal;
          maxCreditorId = id;
        }
      });

      if (maxDebtorId == null || maxCreditorId == null) {
        break;
      }

      final double debtorAmount = -minBalance;
      final double creditorAmount = maxBalance;

      final double rawTransfer = debtorAmount < creditorAmount ? debtorAmount : creditorAmount;
      final double transferAmount = CurrencyFormatter.roundTo2Decimals(rawTransfer);

      if (transferAmount >= 0.01) {
        transfers.add(
          DebtTransfer(
            fromMemberId: maxDebtorId!,
            toMemberId: maxCreditorId!,
            amount: transferAmount,
          ),
        );
      } else {
        // If remaining difference is sub-cent dust (< 0.01), prune both and break
        balances.remove(maxDebtorId);
        balances.remove(maxCreditorId);
        break;
      }

      final newDebtorBal = CurrencyFormatter.roundTo2Decimals(balances[maxDebtorId!]! + transferAmount);
      final newCreditorBal = CurrencyFormatter.roundTo2Decimals(balances[maxCreditorId!]! - transferAmount);

      if (newDebtorBal.abs() < 0.01) {
        balances.remove(maxDebtorId);
      } else {
        balances[maxDebtorId!] = newDebtorBal;
      }

      if (newCreditorBal.abs() < 0.01) {
        balances.remove(maxCreditorId);
      } else {
        balances[maxCreditorId!] = newCreditorBal;
      }
    }

    return transfers;
  }
}
