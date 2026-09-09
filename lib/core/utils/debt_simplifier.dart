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

    // Filter out zero balances and make a mutable copy
    final Map<String, double> balances = {};
    netBalances.forEach((memberId, balance) {
      if (balance.abs() > 0.01) {
        balances[memberId] = balance;
      }
    });

    while (balances.isNotEmpty) {
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

      final double transferAmount = debtorAmount < creditorAmount ? debtorAmount : creditorAmount;

      if (transferAmount > 0.01) {
        transfers.add(
          DebtTransfer(
            fromMemberId: maxDebtorId!,
            toMemberId: maxCreditorId!,
            amount: double.parse(transferAmount.toStringAsFixed(2)),
          ),
        );
      }

      final newDebtorBal = balances[maxDebtorId!]! + transferAmount;
      final newCreditorBal = balances[maxCreditorId!]! - transferAmount;

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
