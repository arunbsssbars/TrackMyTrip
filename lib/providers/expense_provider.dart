import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/cloud_trip_sync_service.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/trip_share_service.dart';
import '../models/expense.dart';
import 'trip_provider.dart';

import '../models/sync_mutation.dart';
import '../core/services/offline_sync_engine.dart';
import '../core/services/realtime_sync_service.dart';

class ExpenseNotifier extends StateNotifier<List<Expense>> {
  final LocalStorageService _storage;
  final Ref _ref;

  ExpenseNotifier(this._storage, this._ref) : super([]) {
    _loadAllExpenses();
  }

  void _loadAllExpenses() {
    state = _storage.getAllExpenses();
  }

  void reload() {
    _loadAllExpenses();
  }

  Future<void> addExpense(Expense expense, {bool broadcast = true}) async {
    state = [expense, ...state];
    await _storage.saveAllExpenses(state);
    _syncToCloud(expense.tripId);

    if (broadcast) {
      try {
        _ref.read(realtimeSyncServiceProvider).broadcastNewExpense(expense);
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
    state = [
      for (final e in state)
        if (e.id == updatedExpense.id) updatedExpense else e
    ];
    await _storage.saveAllExpenses(state);
    _syncToCloud(updatedExpense.tripId);

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
    _syncToCloud(existing.tripId);

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

  void _syncToCloud(String tripId) {
    try {
      final trips = _storage.getTrips();
      final trip = trips.firstWhere((t) => t.id == tripId);
      final package = TripPackage(
        trip: trip,
        stoppages: _storage.getAllStoppages().where((s) => s.tripId == tripId).toList(),
        expenses: state.where((e) => e.tripId == tripId).toList(),
        memories: _storage.getAllMemories().where((m) => m.tripId == tripId).toList(),
        settlements: _storage.getAllSettlements().where((s) => s.tripId == tripId).toList(),
      );
      CloudTripSyncService.publishTrip(package);
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
