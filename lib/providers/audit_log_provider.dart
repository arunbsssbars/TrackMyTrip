import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/cloud_trip_sync_service.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/trip_share_service.dart';
import '../models/trip_audit_log.dart';
import 'expense_provider.dart';
import 'memory_provider.dart';
import 'settlement_provider.dart';
import 'stoppage_provider.dart';
import 'trip_provider.dart';

import '../core/services/realtime_sync_service.dart';

class AuditLogNotifier extends StateNotifier<List<TripAuditLog>> {
  final LocalStorageService _storage;
  final Ref _ref;

  AuditLogNotifier(this._storage, this._ref) : super([]) {
    _loadAll();
  }

  void _loadAll() {
    final rawLogs = _storage.getAllAuditLogs();
    // Enforce strict financial scope: only retain monetary/budget/expense/settlement events
    final logs = rawLogs.where((l) =>
      l.actionType.contains('expense') ||
      l.actionType.contains('budget') ||
      l.actionType.contains('bill') ||
      l.actionType.contains('settle')
    ).toList();

    final trips = _storage.getTrips();
    final allExpenses = _storage.getAllExpenses();
    final allSettlements = _storage.getAllSettlements();

    final existingLogIds = logs.map((l) => l.id).toSet();
    final missingLogs = <TripAuditLog>[];

    for (final trip in trips) {
      final creator = trip.currentUserMember ?? (trip.members.isNotEmpty ? trip.members.first : null);
      final creatorId = creator?.id ?? 'usr_me';
      final creatorName = creator?.name ?? 'Trip Leader';

      // 1. Budget Allocation
      if (trip.budget != null && trip.budget! > 0) {
        if (!existingLogIds.contains('budget_${trip.id}') &&
            !logs.any((l) => l.tripId == trip.id && (l.actionType == 'set_budget' || l.actionType == 'update_budget'))) {
          missingLogs.add(TripAuditLog(
            id: 'budget_${trip.id}',
            tripId: trip.id,
            actionType: 'set_budget',
            itemTitle: 'Trip Budget: ${trip.defaultCurrency} ${trip.budget!.toStringAsFixed(0)}',
            performedByMemberId: creatorId,
            performedByName: creatorName,
            timestamp: trip.startDate,
            changeDetails: 'Allocated travel expenditure limit',
          ));
        }
      }

      // 2. Expenses & Bills
      final tripExpenses = allExpenses.where((e) => e.tripId == trip.id);
      for (final e in tripExpenses) {
        if (!existingLogIds.contains('exp_${e.id}') && !existingLogIds.contains(e.id)) {
          final payerName = trip.getMemberName(e.paidByMemberId);
          missingLogs.add(TripAuditLog(
            id: 'exp_${e.id}',
            tripId: trip.id,
            actionType: 'add_expense',
            itemTitle: '${e.title} (${e.currency} ${e.totalAmount.toStringAsFixed(0)})',
            performedByMemberId: e.paidByMemberId,
            performedByName: payerName.isNotEmpty && payerName != 'Unknown Member' ? payerName : creatorName,
            timestamp: e.createdAt,
            changeDetails: 'Expense registered in category ${e.category}',
          ));
        }
      }

      // 3. Settlements
      final tripSettlements = allSettlements.where((s) => s.tripId == trip.id);
      for (final s in tripSettlements) {
        if (!existingLogIds.contains('settle_${s.id}') && !existingLogIds.contains(s.id)) {
          final payerName = trip.getMemberName(s.payerMemberId);
          final payeeName = trip.getMemberName(s.receiverMemberId);
          missingLogs.add(TripAuditLog(
            id: 'settle_${s.id}',
            tripId: trip.id,
            actionType: 'settlement',
            itemTitle: 'Settlement: $payerName → $payeeName (${s.currency} ${s.amount.toStringAsFixed(0)})',
            performedByMemberId: s.payerMemberId,
            performedByName: payerName,
            timestamp: s.settledAt,
            changeDetails: 'Payment recorded via ${s.paymentMethod}',
          ));
        }
      }
    }

    if (missingLogs.isNotEmpty) {
      final combined = [...logs, ...missingLogs];
      combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      state = combined;
      _storage.saveAllAuditLogs(combined);
    } else {
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      state = logs;
    }
  }

  void reload() {
    _loadAll();
  }

  void reset() {
    state = [];
  }

  Future<void> logAction(TripAuditLog log, {bool broadcast = true}) async {
    final updated = [log, ...state];
    state = updated;
    await _storage.saveAllAuditLogs(updated);
    _triggerCloudSync(log.tripId);
    if (broadcast) {
      try {
        _ref.read(realtimeSyncServiceProvider).broadcastAuditLog(log);
      } catch (_) {}
    }
  }

  /// Ingests an activity log received from a companion over WebSocket
  Future<void> receiveRemoteLog(TripAuditLog log) async {
    if (state.any((l) => l.id == log.id)) return; // Avoid duplicates
    final updated = [log, ...state];
    state = updated;
    await _storage.saveAllAuditLogs(updated);
  }

  void _triggerCloudSync(String tripId) {
    try {
      final trip = _ref.read(tripListProvider).firstWhere((t) => t.id == tripId);
      final stoppages = _ref.read(allStoppagesProvider).where((s) => s.tripId == tripId).toList();
      final expenses = _ref.read(allExpensesProvider).where((e) => e.tripId == tripId).toList();
      final memories = _ref.read(allMemoriesProvider).where((m) => m.tripId == tripId).toList();
      final settlements = _ref.read(allSettlementsProvider).where((s) => s.tripId == tripId).toList();
      final auditLogs = state.where((a) => a.tripId == tripId).toList();

      final pkg = TripPackage(
        trip: trip,
        stoppages: stoppages,
        expenses: expenses,
        memories: memories,
        settlements: settlements,
        auditLogs: auditLogs,
      );
      CloudTripSyncService.publishTrip(pkg);
    } catch (_) {}
  }
}

final allAuditLogsProvider = StateNotifierProvider<AuditLogNotifier, List<TripAuditLog>>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return AuditLogNotifier(storage, ref);
});

final tripAuditLogsProvider = Provider.family<List<TripAuditLog>, String>((ref, tripId) {
  final allLogs = ref.watch(allAuditLogsProvider);
  final filtered = allLogs.where((l) => l.tripId == tripId).toList();
  filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return filtered;
});

final currentTripAuditLogsProvider = Provider<List<TripAuditLog>>((ref) {
  final tripId = ref.watch(selectedTripIdProvider);
  if (tripId == null) return [];
  return ref.watch(tripAuditLogsProvider(tripId));
});

