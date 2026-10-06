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
import '../core/services/firestore_sync_service.dart';

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
      l.actionType.contains('settle') ||
      l.actionType.contains('advance')
    ).toList();

    // Deduplicate existing stored logs (pruning any historical dual-entry settlement logs)
    final seenIds = <String>{};
    final seenSemantic = <String>{};
    final dedupedLogs = <TripAuditLog>[];
    for (final l in logs) {
      if (!seenIds.add(l.id)) continue;
      if (l.actionType.contains('settle') || l.actionType.contains('advance')) {
        final semanticKey = '${l.tripId}_${l.performedByMemberId}_${l.itemTitle}';
        if (!seenSemantic.add(semanticKey)) continue;
      }
      dedupedLogs.add(l);
    }

    final trips = _storage.getTrips();
    final allExpenses = _storage.getAllExpenses();
    final allSettlements = _storage.getAllSettlements();

    final existingLogIds = dedupedLogs.map((l) => l.id).toSet();
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
            itemTitle: 'Trip Budget',
            performedByMemberId: creatorId,
            performedByName: creatorName,
            timestamp: trip.startDate,
            changeDetails: 'Allocated travel expenditure limit',
            amount: trip.budget,
            currency: trip.defaultCurrency,
            targetItemId: trip.id,
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
            itemTitle: e.title,
            performedByMemberId: e.paidByMemberId,
            performedByName: payerName.isNotEmpty && payerName != 'Unknown Member' ? payerName : creatorName,
            timestamp: e.createdAt,
            changeDetails: 'Expense registered in category ${e.category}',
            amount: e.totalAmount,
            currency: e.currency,
            targetItemId: e.id,
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
            itemTitle: 'Settlement: $payerName → $payeeName',
            performedByMemberId: s.payerMemberId,
            performedByName: payerName,
            timestamp: s.settledAt,
            changeDetails: 'Payment recorded via ${s.paymentMethod}',
            amount: s.amount,
            currency: s.currency,
            targetItemId: s.id,
          ));
        }
      }
    }

    if (missingLogs.isNotEmpty) {
      final combined = [...dedupedLogs, ...missingLogs];
      combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      state = combined;
      _storage.saveAllAuditLogs(combined);
    } else {
      dedupedLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      state = dedupedLogs;
    }
  }

  void reload() {
    _loadAll();
  }

  void reset() {
    state = [];
  }

  Future<void> logAction(TripAuditLog log, {bool broadcast = true}) async {
    // Stoppages are navigation waypoints, not financial audit records (User point 4)
    if (log.actionType.contains('stop')) return;
    if (state.any((l) => l.id == log.id)) return;
    if (log.actionType.contains('settle') || log.actionType.contains('advance')) {
      if (state.any((l) =>
          l.tripId == log.tripId &&
          l.performedByMemberId == log.performedByMemberId &&
          l.itemTitle == log.itemTitle &&
          l.timestamp.difference(log.timestamp).abs().inSeconds < 5)) {
        return; // Suppress duplicate settlement/advance log
      }
    }
    if (log.actionType.contains('expense') || log.actionType.contains('bill')) {
      if (state.any((l) =>
          l.tripId == log.tripId &&
          l.itemTitle == log.itemTitle &&
          l.amount == log.amount &&
          log.amount != null &&
          l.timestamp.difference(log.timestamp).abs().inSeconds < 5)) {
        return; // Suppress duplicate expense log within 5 seconds
      }
    }
    final updated = [log, ...state];
    updated.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    state = updated;
    await _storage.saveAllAuditLogs(updated);
    _triggerCloudSync(log.tripId);
    if (broadcast) {
      try {
        _ref.read(realtimeSyncServiceProvider).broadcastAuditLog(log);
      } catch (_) {}
      try {
        _ref.read(firestoreSyncServiceProvider).pushAuditLog(log);
      } catch (_) {}
    }
  }

  /// Ingests an activity log received from a companion over WebSocket or Firestore
  Future<void> receiveRemoteLog(TripAuditLog log) async {
    if (state.any((l) => l.id == log.id)) return; // Avoid duplicates
    final updated = [log, ...state];
    updated.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    state = updated;
    await _storage.saveAllAuditLogs(updated);
  }

  void _triggerCloudSync(String tripId) {
    try {
      final trip = _ref.read(tripListProvider).where((t) => t.id == tripId).firstOrNull;
      if (trip == null) return;
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

