import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/firestore_sync_service.dart';
import '../core/services/local_storage_service.dart';
import '../models/expense.dart';
import '../models/trip_audit_log.dart';
import '../core/services/user_service.dart';
import 'audit_log_provider.dart';
import 'trip_provider.dart';

import '../models/sync_mutation.dart';
import '../models/proximity_alert.dart';
import '../core/services/offline_sync_engine.dart';
import '../core/services/realtime_sync_service.dart';
import '../core/services/proximity_alert_service.dart';

class ExpenseNotifier extends StateNotifier<List<Expense>> {
  final LocalStorageService _storage;
  final Ref _ref;

  ExpenseNotifier(this._storage, this._ref) : super([]) {
    _loadAllExpenses();
  }

  void _loadAllExpenses() {
    final trips = _storage.getTrips();
    final userTripIds = trips.map((t) => t.id).toSet();
    state = _storage.getAllExpenses().where((e) => userTripIds.contains(e.tripId)).toList();
  }

  void reload() {
    _loadAllExpenses();
  }

  void reset() {
    state = [];
  }

  Future<void> addExpense(Expense expense, {bool broadcast = true}) async {
    final trips = _storage.getTrips();
    final trip = trips.where((t) => t.id == expense.tripId).firstOrNull;
    if (trip == null || trip.isDeleted) {
      return;
    }

    state = [expense, ...state.where((e) => e.id != expense.id)];
    await _storage.saveAllExpenses(state);

    try {
      _ref.read(firestoreSyncServiceProvider).pushExpense(expense);
    } catch (_) {}

    final payerName = trip.getMember(expense.paidByMemberId)?.name ?? 'A companion';

    try {
      _ref.read(allAuditLogsProvider.notifier).logAction(TripAuditLog(
        id: 'exp_${expense.id}',
        tripId: expense.tripId,
        actionType: 'add_expense',
        itemTitle: '${expense.title} (${expense.currency} ${expense.totalAmount.toStringAsFixed(0)})',
        performedByMemberId: expense.paidByMemberId,
        performedByName: payerName,
        timestamp: expense.createdAt,
        changeDetails: 'Expense registered in category ${expense.category}',
      ));
    } catch (_) {}

    if (broadcast) {
      try {
        _ref.read(realtimeSyncServiceProvider).broadcastNewExpense(expense);
      } catch (_) {}
      try {
        _ref.read(proximityAlertServiceProvider).broadcastActivityAlert(
          tripId: expense.tripId,
          type: AlertType.billAdded,
          title: 'New Bill Added',
          message: '$payerName added "${expense.title}" (${expense.currency} ${expense.totalAmount.toStringAsFixed(0)})',
          senderMemberId: expense.paidByMemberId,
          senderName: payerName,
        );
      } catch (_) {}
    }

    try {
      _ref.read(offlineSyncEngineProvider).enqueueMutation(
        action: MutationAction.addExpense,
        entityType: 'expense',
        entityId: expense.id,
        tripId: expense.tripId,
        payload: expense.toJson(),
      );
    } catch (_) {}
  }

  Future<void> updateExpense(Expense updatedExpense) async {
    final trips = _storage.getTrips();
    final trip = trips.where((t) => t.id == updatedExpense.tripId).firstOrNull;
    if (trip == null || trip.isDeleted) {
      return;
    }

    state = [
      for (final e in state)
        if (e.id == updatedExpense.id) updatedExpense else e
    ];
    await _storage.saveAllExpenses(state);

    try {
      _ref.read(firestoreSyncServiceProvider).pushExpense(updatedExpense);
    } catch (_) {}

    try {
      final payerName = trip.getMember(updatedExpense.paidByMemberId)?.name ?? 'A companion';
      _ref.read(allAuditLogsProvider.notifier).logAction(TripAuditLog(
        id: 'exp_edit_${updatedExpense.id}_${DateTime.now().millisecondsSinceEpoch}',
        tripId: updatedExpense.tripId,
        actionType: 'edit_expense',
        itemTitle: 'Updated: ${updatedExpense.title}',
        performedByMemberId: updatedExpense.paidByMemberId,
        performedByName: payerName,
        timestamp: DateTime.now(),
        changeDetails: 'Expense updated (${updatedExpense.currency} ${updatedExpense.totalAmount.toStringAsFixed(0)})',
      ));
    } catch (_) {}

    try {
      _ref.read(offlineSyncEngineProvider).enqueueMutation(
        action: MutationAction.updateExpense,
        entityType: 'expense',
        entityId: updatedExpense.id,
        tripId: updatedExpense.tripId,
        payload: updatedExpense.toJson(),
      );
    } catch (_) {}
  }

  Future<void> deleteExpense(String expenseId) async {
    final existing = state.firstWhere((e) => e.id == expenseId, orElse: () => state.first);
    state = state.where((e) => e.id != expenseId).toList();
    await _storage.saveAllExpenses(state);

    try {
      _ref.read(firestoreSyncServiceProvider).deleteExpense(existing.tripId, expenseId);
    } catch (_) {}

    try {
      final currentUser = UserService.getCurrentUser();
      _ref.read(allAuditLogsProvider.notifier).logAction(TripAuditLog(
        id: 'exp_del_${expenseId}_${DateTime.now().millisecondsSinceEpoch}',
        tripId: existing.tripId,
        actionType: 'delete_expense',
        itemTitle: 'Deleted: ${existing.title}',
        performedByMemberId: currentUser.id,
        performedByName: currentUser.displayName,
        timestamp: DateTime.now(),
        changeDetails: 'Expense deleted (${existing.currency} ${existing.totalAmount.toStringAsFixed(0)})',
      ));
    } catch (_) {}

    try {
      _ref.read(offlineSyncEngineProvider).enqueueMutation(
        action: MutationAction.deleteExpense,
        entityType: 'expense',
        entityId: expenseId,
        tripId: existing.tripId,
        payload: {'id': expenseId},
      );
    } catch (_) {}
  }
}

final allExpensesProvider = StateNotifierProvider<ExpenseNotifier, List<Expense>>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return ExpenseNotifier(storage, ref);
});

final currentTripExpensesProvider = Provider<List<Expense>>((ref) {
  final currentTrip = ref.watch(currentTripProvider);
  if (currentTrip == null) return [];

  final allExpenses = ref.watch(allExpensesProvider);
  final expenses = allExpenses.where((e) => e.tripId == currentTrip.id).toList();
  expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return expenses;
});

final stoppageExpensesProvider = Provider.family<List<Expense>, String>((ref, stoppageId) {
  final tripExpenses = ref.watch(currentTripExpensesProvider);
  return tripExpenses.where((e) => e.stoppageId == stoppageId).toList();
});

final currentTripTotalSpentProvider = Provider<double>((ref) {
  final expenses = ref.watch(currentTripExpensesProvider);
  return expenses.fold<double>(0, (sum, e) => sum + e.totalAmount);
});

final expensesByCategoryProvider = Provider<Map<String, double>>((ref) {
  final expenses = ref.watch(currentTripExpensesProvider);
  final Map<String, double> categoryTotals = {};
  for (final expense in expenses) {
    categoryTotals[expense.category] = (categoryTotals[expense.category] ?? 0) + expense.totalAmount;
  }
  return categoryTotals;
});

final userScopedExpensesProvider = Provider<List<Expense>>((ref) {
  final trips = ref.watch(tripListProvider);
  final userTripIds = trips.map((t) => t.id).toSet();
  final allExpenses = ref.watch(allExpensesProvider);
  return allExpenses.where((e) => userTripIds.contains(e.tripId)).toList();
});

final userScopedTotalSpentProvider = Provider<double>((ref) {
  final expenses = ref.watch(userScopedExpensesProvider);
  return expenses.fold<double>(0.0, (sum, e) => sum + e.totalAmount);
});
