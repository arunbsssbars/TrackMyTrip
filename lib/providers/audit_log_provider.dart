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
    state = _storage.getAllAuditLogs();
  }

  void reload() {
    _loadAll();
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

final currentTripAuditLogsProvider = Provider<List<TripAuditLog>>((ref) {
  final tripId = ref.watch(selectedTripIdProvider);
  if (tripId == null) return [];
  final allLogs = ref.watch(allAuditLogsProvider);
  final filtered = allLogs.where((l) => l.tripId == tripId).toList();
  filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return filtered;
});
