import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/firestore_sync_service.dart';
import '../core/services/local_storage_service.dart';
import '../models/expense.dart';
import '../models/expense_split.dart';
import '../models/trip_audit_log.dart';
import '../core/services/user_service.dart';
import 'audit_log_provider.dart';
import 'trip_provider.dart';

import '../models/sync_mutation.dart';
import '../models/proximity_alert.dart';
import '../core/services/offline_sync_engine.dart';
import '../core/services/realtime_sync_service.dart';
import '../core/services/proximity_alert_service.dart';
import '../core/services/tombstone_service.dart';
import '../core/services/media_cache_service.dart';

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
    if (TombstoneService.isTombstoned(expense.tripId)) {
      return;
    }

    Expense effectiveExpense = expense;
    if (!effectiveExpense.isPersonal &&
        (effectiveExpense.splits.isEmpty ||
            effectiveExpense.splits.every((s) => s.allocatedAmount <= 0))) {
      final trips = _storage.getTrips();
      final trip = trips.where((t) => t.id == effectiveExpense.tripId).firstOrNull;
      final members = trip?.members ?? [];
      if (members.isNotEmpty) {
        final totalCents = (effectiveExpense.totalAmount * 100).round();
        final baseCents = totalCents ~/ members.length;
        final remainder = totalCents % members.length;
        final List<ExpenseSplit> fallbackSplits = [];
        for (int i = 0; i < members.length; i++) {
          final cents = baseCents + (i < remainder ? 1 : 0);
          fallbackSplits.add(
            ExpenseSplit(
              memberId: members[i].id,
              allocatedAmount: cents / 100.0,
              isIncluded: true,
            ),
          );
        }
        effectiveExpense = effectiveExpense.copyWith(splits: fallbackSplits);
      }
    }

    state = [effectiveExpense, ...state.where((e) => e.id != effectiveExpense.id)];
    await _storage.saveExpense(effectiveExpense);

    if (broadcast) {
      try {
        _ref.read(firestoreSyncServiceProvider).pushExpense(effectiveExpense);
      } catch (_) {}

      final trips = _storage.getTrips();
      final trip = trips.where((t) => t.id == effectiveExpense.tripId).firstOrNull;
      final payerName = trip?.getMember(effectiveExpense.paidByMemberId)?.name ?? 'A companion';

      if (!effectiveExpense.isPersonal) {
        try {
          _ref.read(allAuditLogsProvider.notifier).logAction(TripAuditLog(
            id: 'exp_${effectiveExpense.id}',
            tripId: effectiveExpense.tripId,
            actionType: 'add_expense',
            itemTitle: effectiveExpense.title,
            performedByMemberId: effectiveExpense.paidByMemberId,
            performedByName: payerName,
            timestamp: effectiveExpense.createdAt,
            changeDetails: 'Expense registered in category ${effectiveExpense.category}',
            amount: effectiveExpense.totalAmount,
            currency: effectiveExpense.currency,
            targetItemId: effectiveExpense.id,
          ));
        } catch (_) {}

        try {
          _ref.read(realtimeSyncServiceProvider).broadcastNewExpense(effectiveExpense);
        } catch (_) {}
        try {
          _ref.read(proximityAlertServiceProvider).broadcastActivityAlert(
            id: 'alert_exp_${effectiveExpense.id}',
            tripId: effectiveExpense.tripId,
            type: AlertType.billAdded,
            title: 'Bill Added',
            message: '$payerName added "${effectiveExpense.title}" (${effectiveExpense.currency} ${effectiveExpense.totalAmount.toStringAsFixed(0)})',
            senderMemberId: effectiveExpense.paidByMemberId,
            senderName: payerName,
            itemId: effectiveExpense.id,
            itemType: 'bill',
            amount: effectiveExpense.totalAmount,
            currency: effectiveExpense.currency,
            showLocalBanner: true,
          );
        } catch (_) {}
      } else {
        // Point 25: Personal spendings are strictly local to this user - no companion notifications
        try {
          _ref.read(allAuditLogsProvider.notifier).logAction(TripAuditLog(
            id: 'personal_exp_${effectiveExpense.id}',
            tripId: effectiveExpense.tripId,
            actionType: 'personal_expense',
            itemTitle: '🔒 ${effectiveExpense.title}',
            performedByMemberId: effectiveExpense.paidByMemberId,
            performedByName: payerName,
            timestamp: effectiveExpense.createdAt,
            changeDetails: 'Personal expense recorded (private to you)',
            amount: effectiveExpense.totalAmount,
            currency: effectiveExpense.currency,
            targetItemId: effectiveExpense.id,
          ));
        } catch (_) {}
      }

      try {
        _ref.read(offlineSyncEngineProvider).enqueueMutation(
          action: MutationAction.addExpense,
          entityType: 'expense',
          entityId: effectiveExpense.id,
          tripId: effectiveExpense.tripId,
          payload: effectiveExpense.toJson(),
        );
      } catch (_) {}
    }
  }

  Future<void> updateExpense(Expense updatedExpense, {bool broadcast = true}) async {
    if (TombstoneService.isTombstoned(updatedExpense.tripId)) {
      return;
    }

    final exists = state.any((e) => e.id == updatedExpense.id);
    state = exists
        ? [
            for (final e in state)
              if (e.id == updatedExpense.id) updatedExpense else e
          ]
        : [updatedExpense, ...state];
    await _storage.saveExpense(updatedExpense);

    if (broadcast) {
      try {
        _ref.read(firestoreSyncServiceProvider).pushExpense(updatedExpense);
      } catch (_) {}

      // Note: Audit log is NOT created here to avoid duplication.
      // The screen-level _submit() handler creates a detailed field-diff audit log.

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
  }

  Future<void> deleteExpense(String expenseId, {String? tripId, bool broadcast = true}) async {
    final existing = state.where((e) => e.id == expenseId).firstOrNull;
    final effectiveTripId = tripId ?? existing?.tripId ?? '';
    state = state.where((e) => e.id != expenseId).toList();
    await _storage.saveAllExpenses(state);
    if (existing?.receiptImagePath != null) {
      MediaCacheService.deleteMediaFile(existing!.receiptImagePath);
    }

    if (broadcast && effectiveTripId.isNotEmpty) {
      try {
        _ref.read(firestoreSyncServiceProvider).deleteExpense(effectiveTripId, expenseId);
      } catch (_) {}

      try {
        final currentUser = UserService.getCurrentUser();
        final title = existing?.title ?? 'Expense';
        _ref.read(allAuditLogsProvider.notifier).logAction(TripAuditLog(
          id: 'exp_del_${expenseId}_${DateTime.now().millisecondsSinceEpoch}',
          tripId: effectiveTripId,
          actionType: 'delete_expense',
          itemTitle: 'Deleted: $title',
          performedByMemberId: currentUser.id,
          performedByName: currentUser.displayName,
          timestamp: DateTime.now(),
          changeDetails: 'Expense removed from ledger',
          amount: existing?.totalAmount,
          currency: existing?.currency,
          targetItemId: expenseId,
        ));
      } catch (_) {}

      try {
        final currentUser = UserService.getCurrentUser();
        final title = existing?.title ?? 'Expense';
        _ref.read(proximityAlertServiceProvider).broadcastActivityAlert(
          id: 'alert_del_${expenseId}_${DateTime.now().millisecondsSinceEpoch}',
          tripId: effectiveTripId,
          type: AlertType.billDeleted,
          title: 'Bill Deleted',
          message: '${currentUser.displayName} deleted "$title"',
          senderMemberId: currentUser.id,
          senderName: currentUser.displayName,
          itemId: expenseId,
          itemType: 'bill',
          amount: existing?.totalAmount,
          currency: existing?.currency,
          showLocalBanner: false,
        );
      } catch (_) {}

      try {
        _ref.read(offlineSyncEngineProvider).enqueueMutation(
          action: MutationAction.deleteExpense,
          entityType: 'expense',
          entityId: expenseId,
          tripId: effectiveTripId,
          payload: {'id': expenseId},
        );
      } catch (_) {}
    }
  }
}

final allExpensesProvider = StateNotifierProvider<ExpenseNotifier, List<Expense>>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return ExpenseNotifier(storage, ref);
});

final tripExpensesProvider = Provider.family<List<Expense>, String>((ref, tripId) {
  final allExpenses = ref.watch(allExpensesProvider);
  final expenses = allExpenses.where((e) => e.tripId == tripId).toList();
  expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return expenses;
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
