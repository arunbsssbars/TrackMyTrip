import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/cloud_trip_sync_service.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/trip_share_service.dart';
import '../core/utils/debt_simplifier.dart';
import '../models/settlement.dart';
import 'expense_provider.dart';
import 'trip_provider.dart';

import '../models/proximity_alert.dart';
import '../core/services/proximity_alert_service.dart';

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

  Future<void> addSettlement(Settlement settlement) async {
    state = [settlement, ...state];
    await _storage.saveAllSettlements(state);
    _syncToCloud(settlement.tripId);
    try {
      final trips = _storage.getTrips();
      final trip = trips.where((t) => t.id == settlement.tripId).firstOrNull;
      final payerName = trip?.getMember(settlement.payerMemberId)?.name ?? 'Member';
      final payeeName = trip?.getMember(settlement.receiverMemberId)?.name ?? 'Member';
      _ref.read(proximityAlertServiceProvider).broadcastActivityAlert(
        tripId: settlement.tripId,
        type: AlertType.settlementRecorded,
        title: 'Settlement Payment Recorded',
        message: '$payerName paid $payeeName ${settlement.currency} ${settlement.amount.toStringAsFixed(0)} to settle balance',
      );
    } catch (_) {}
  }

  Future<void> updateSettlement(Settlement updated) async {
    state = state.map((s) => s.id == updated.id ? updated : s).toList();
    await _storage.saveAllSettlements(state);
    _syncToCloud(updated.tripId);
  }

  Future<void> deleteSettlement(String settlementId) async {
    final existing = state.firstWhere((s) => s.id == settlementId, orElse: () => state.first);
    state = state.where((s) => s.id != settlementId).toList();
    await _storage.saveAllSettlements(state);
    _syncToCloud(existing.tripId);
  }

  void _syncToCloud(String tripId) {
    try {
      final trips = _storage.getTrips();
      final trip = trips.firstWhere((t) => t.id == tripId);
      final package = TripPackage(
        trip: trip,
        stoppages: _storage.getAllStoppages().where((s) => s.tripId == tripId).toList(),
        expenses: _storage.getAllExpenses().where((e) => e.tripId == tripId).toList(),
        memories: _storage.getAllMemories().where((m) => m.tripId == tripId).toList(),
        settlements: state.where((s) => s.tripId == tripId).toList(),
      );
      CloudTripSyncService.publishTrip(package);
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

  // Factor in all trip expenses
  for (final expense in expenses) {
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

  return balances;
});

/// Computes the minimal number of direct transfers to settle all trip debts
final simplifiedTransfersProvider = Provider<List<DebtTransfer>>((ref) {
  final balances = ref.watch(tripNetBalancesProvider);
  return DebtSimplifier.simplifyDebts(balances);
});
