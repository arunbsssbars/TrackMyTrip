import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/firestore_sync_service.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/offline_sync_engine.dart';
import '../core/services/proximity_alert_service.dart';
import '../core/services/user_service.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/debt_simplifier.dart';
import '../models/proximity_alert.dart';
import '../models/settlement.dart';
import '../models/sync_mutation.dart';
import '../models/trip_audit_log.dart';
import 'audit_log_provider.dart';
import 'expense_provider.dart';
import 'trip_provider.dart';

class SettlementNotifier extends StateNotifier<List<Settlement>> {
  final LocalStorageService _storage;
  final Ref _ref;

  SettlementNotifier(this._storage, this._ref) : super([]) {
    _loadAllSettlements();
  }

  void _loadAllSettlements() {
    final trips = _storage.getTrips();
    final userTripIds = trips.map((t) => t.id).toSet();
    state = _storage.getAllSettlements().where((s) => userTripIds.contains(s.tripId)).toList();
  }

  void reload() {
    _loadAllSettlements();
  }

  void reset() {
    state = [];
  }

  /// Ingests remote settlement from Firestore subscription
  void receiveRemoteSettlement(Settlement settlement) {
    final exists = state.any((s) => s.id == settlement.id);
    if (exists) {
      state = state.map((s) => s.id == settlement.id ? settlement : s).toList();
    } else {
      state = [settlement, ...state];
    }
    _storage.saveAllSettlements(state);
  }

  /// Removes settlement from local state without cloud push (e.g. on remote removal)
  void deleteSettlementLocally(String settlementId) {
    state = state.where((s) => s.id != settlementId).toList();
    _storage.saveAllSettlements(state);
  }

  Future<void> addSettlement(Settlement settlement) async {
    if (settlement.amount <= 0 || settlement.payerMemberId == settlement.receiverMemberId) {
      return;
    }
    state = [settlement, ...state.where((s) => s.id != settlement.id)];
    await _storage.saveAllSettlements(state);

    try {
      _ref.read(firestoreSyncServiceProvider).pushSettlement(settlement);
    } catch (_) {}

    try {
      _ref.read(offlineSyncEngineProvider).enqueueMutation(
        action: MutationAction.addSettlement,
        entityType: 'settlement',
        entityId: settlement.id,
        tripId: settlement.tripId,
        payload: settlement.toJson(),
      );
    } catch (_) {}

    try {
      final trips = _storage.getTrips();
      final trip = trips.where((t) => t.id == settlement.tripId).firstOrNull;
      final payerName = trip?.getMemberName(settlement.payerMemberId) ?? 'Member';
      final payeeName = trip?.getMemberName(settlement.receiverMemberId) ?? 'Member';
      final isAdv = settlement.isAdvance;

      _ref.read(allAuditLogsProvider.notifier).logAction(TripAuditLog(
        id: 'settle_${settlement.id}',
        tripId: settlement.tripId,
        actionType: isAdv ? 'advance_payment' : 'settlement',
        itemTitle: isAdv
            ? 'Advance Paid: $payerName → $payeeName (${settlement.currency} ${settlement.amount.toStringAsFixed(0)})'
            : 'Settlement: $payerName → $payeeName (${settlement.currency} ${settlement.amount.toStringAsFixed(0)})',
        performedByMemberId: settlement.payerMemberId,
        performedByName: payerName,
        timestamp: settlement.settledAt,
        changeDetails: isAdv
            ? 'Advance contribution recorded via ${settlement.paymentMethod}'
            : 'Payment recorded via ${settlement.paymentMethod}',
      ));

      _ref.read(proximityAlertServiceProvider).broadcastActivityAlert(
        id: 'alert_settle_${settlement.id}',
        tripId: settlement.tripId,
        type: AlertType.settlementRecorded,
        title: isAdv ? 'Advance Payment Recorded' : 'Settlement Payment Recorded',
        message: isAdv
            ? '$payerName paid $payeeName an advance of ${settlement.currency} ${settlement.amount.toStringAsFixed(0)}'
            : '$payerName paid $payeeName ${settlement.currency} ${settlement.amount.toStringAsFixed(0)} to settle balance',
        itemId: settlement.id,
        itemType: 'settlement',
        showLocalBanner: true,
      );
    } catch (_) {}
  }

  Future<void> updateSettlement(Settlement updated) async {
    state = state.map((s) => s.id == updated.id ? updated : s).toList();
    await _storage.saveAllSettlements(state);

    try {
      _ref.read(firestoreSyncServiceProvider).pushSettlement(updated);
    } catch (_) {}

    try {
      _ref.read(offlineSyncEngineProvider).enqueueMutation(
        action: MutationAction.updateSettlement,
        entityType: 'settlement',
        entityId: updated.id,
        tripId: updated.tripId,
        payload: updated.toJson(),
      );
    } catch (_) {}

    try {
      final trips = _storage.getTrips();
      final trip = trips.where((t) => t.id == updated.tripId).firstOrNull;
      final payerName = trip?.getMemberName(updated.payerMemberId) ?? 'Member';

      _ref.read(allAuditLogsProvider.notifier).logAction(TripAuditLog(
        id: 'settle_edit_${updated.id}_${DateTime.now().millisecondsSinceEpoch}',
        tripId: updated.tripId,
        actionType: 'edit_settlement',
        itemTitle: 'Updated Settlement: ${updated.currency} ${updated.amount.toStringAsFixed(0)}',
        performedByMemberId: updated.payerMemberId,
        performedByName: payerName,
        timestamp: DateTime.now(),
        changeDetails: 'Payment updated via ${updated.paymentMethod}',
      ));
    } catch (_) {}
  }

  Future<void> deleteSettlement(String settlementId) async {
    final existing = state.firstWhere((s) => s.id == settlementId, orElse: () => state.first);
    state = state.where((s) => s.id != settlementId).toList();
    await _storage.saveAllSettlements(state);

    try {
      _ref.read(firestoreSyncServiceProvider).deleteSettlement(existing.tripId, settlementId);
    } catch (_) {}

    try {
      _ref.read(offlineSyncEngineProvider).enqueueMutation(
        action: MutationAction.deleteSettlement,
        entityType: 'settlement',
        entityId: settlementId,
        tripId: existing.tripId,
        payload: {'id': settlementId},
      );
    } catch (_) {}

    try {
      final trips = _storage.getTrips();
      final trip = trips.where((t) => t.id == existing.tripId).firstOrNull;
      final fromName = trip?.getMemberName(existing.payerMemberId) ?? 'Member';
      final toName = trip?.getMemberName(existing.receiverMemberId) ?? 'Member';
      final currentUser = UserService.getCurrentUser();

      _ref.read(allAuditLogsProvider.notifier).logAction(TripAuditLog(
        id: 'settle_del_${settlementId}_${DateTime.now().millisecondsSinceEpoch}',
        tripId: existing.tripId,
        actionType: 'delete_settlement',
        itemTitle: 'Deleted Settlement (${existing.currency} ${existing.amount.toStringAsFixed(0)})',
        performedByMemberId: currentUser.id,
        performedByName: currentUser.displayName,
        timestamp: DateTime.now(),
        changeDetails: 'Settlement deleted between $fromName and $toName',
      ));
    } catch (_) {}
  }
}

final allSettlementsProvider = StateNotifierProvider<SettlementNotifier, List<Settlement>>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return SettlementNotifier(storage, ref);
});

final currentTripSettlementsProvider = Provider<List<Settlement>>((ref) {
  final currentTrip = ref.watch(currentTripProvider);
  if (currentTrip == null) return [];

  final allSettlements = ref.watch(allSettlementsProvider);
  return allSettlements.where((s) => s.tripId == currentTrip.id).toList();
});

/// Calculates each member's net balance:
/// Positive = member is owed money (creditor)
/// Negative = member owes money to the group (debtor)
/// Zero = perfectly settled
final tripNetBalancesProvider = Provider<Map<String, double>>((ref) {
  final currentTrip = ref.watch(currentTripProvider);
  if (currentTrip == null) return {};

  final expenses = ref.watch(currentTripExpensesProvider);
  final settlements = ref.watch(currentTripSettlementsProvider);

  final Map<String, double> balances = {};

  // Initialize all members with 0.0
  for (final member in currentTrip.members) {
    balances[member.id] = 0.0;
  }

  // Factor in all trip expenses (exclude personal expenses - they have no group split debt)
  for (final expense in expenses) {
    if (expense.isPersonal) continue;
    // Payer is credited the total amount they paid upfront
    balances[expense.paidByMemberId] = (balances[expense.paidByMemberId] ?? 0.0) + expense.totalAmount;

    // Consumers are debited their allocated share
    for (final split in expense.splits) {
      balances[split.memberId] = (balances[split.memberId] ?? 0.0) - split.allocatedAmount;
    }
  }

  // Factor in all direct settlements recorded
  for (final settlement in settlements) {
    // Payer sent money, so their balance goes up (less debt)
    balances[settlement.payerMemberId] = (balances[settlement.payerMemberId] ?? 0.0) + settlement.amount;
    // Receiver got money, so their balance goes down (less credit owed to them)
    balances[settlement.receiverMemberId] = (balances[settlement.receiverMemberId] ?? 0.0) - settlement.amount;
  }

  // Round each balance to exact cents to eliminate IEEE 754 floating point dust
  final Map<String, double> roundedBalances = {};
  balances.forEach((memberId, bal) {
    final rounded = CurrencyFormatter.roundTo2Decimals(bal);
    roundedBalances[memberId] = rounded.abs() < 0.001 ? 0.0 : rounded;
  });

  return roundedBalances;
});

/// Verifies the zero-sum ledger invariant: sum(netBalances) == 0.00
final ledgerImbalanceProvider = Provider<double>((ref) {
  final balances = ref.watch(tripNetBalancesProvider);
  if (balances.isEmpty) return 0.0;
  final sum = balances.values.fold<double>(0.0, (acc, b) => acc + b);
  return CurrencyFormatter.roundTo2Decimals(sum);
});

/// Computes the minimal number of direct transfers to settle all trip debts
final simplifiedTransfersProvider = Provider<List<DebtTransfer>>((ref) {
  final balances = ref.watch(tripNetBalancesProvider);
  return DebtSimplifier.simplifyDebts(balances);
});
