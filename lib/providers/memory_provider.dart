import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/cloud_trip_sync_service.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/trip_share_service.dart';
import '../models/memory.dart';
import 'trip_provider.dart';

import 'package:uuid/uuid.dart';
import '../models/trip_audit_log.dart';
import '../models/sync_mutation.dart';
import '../core/services/offline_sync_engine.dart';
import '../core/services/realtime_sync_service.dart';
import 'audit_log_provider.dart';

class MemoryNotifier extends StateNotifier<List<Memory>> {
  final LocalStorageService _storage;
  final Ref _ref;

  MemoryNotifier(this._storage, this._ref) : super([]) {
    _loadAllMemories();
  }

  void _loadAllMemories() {
    state = _storage.getAllMemories();
  }

  void reload() {
    _loadAllMemories();
  }

  Future<void> addMemory(Memory memory, {bool broadcast = true}) async {
    state = [memory, ...state];
    await _storage.saveAllMemories(state);
    _syncToCloud(memory.tripId);

    if (broadcast) {
      try {
        _ref.read(realtimeSyncServiceProvider).broadcastNewMemory(memory);
      } catch (_) {}
    }

    try {
      final currentTrip = _ref.read(tripListProvider).where((t) => t.id == memory.tripId).firstOrNull;
      final uploaderName = currentTrip?.getMemberName(memory.uploadedByMemberId) ?? 'Companion';
      _ref.read(allAuditLogsProvider.notifier).logAction(
        TripAuditLog(
          id: const Uuid().v4(),
          tripId: memory.tripId,
          actionType: 'add_memory',
          itemTitle: memory.caption?.isNotEmpty == true ? memory.caption! : 'Photo Memory',
          performedByMemberId: memory.uploadedByMemberId,
          performedByName: uploaderName,
          timestamp: DateTime.now(),
          changeDetails: 'Uploaded a new photo memory',
        ),
      );
    } catch (_) {}

    try {
      _ref.read(offlineSyncEngineProvider).enqueueMutation(
        action: MutationAction.addMemory,
        entityType: 'memory',
        entityId: memory.id,
        tripId: memory.tripId,
        payload: memory.toJson(),
      );
    } catch (_) {}
  }

  Future<void> toggleLike(String memoryId, String memberId) async {
    final index = state.indexWhere((m) => m.id == memoryId);
    if (index == -1) return;

    final memory = state[index];
    final likedList = List<String>.from(memory.likedByMemberIds);
    if (likedList.contains(memberId)) {
      likedList.remove(memberId);
    } else {
      likedList.add(memberId);
    }

    final updated = memory.copyWith(likedByMemberIds: likedList);
    state = [
      for (final m in state)
        if (m.id == memoryId) updated else m
    ];
    await _storage.saveAllMemories(state);
    _syncToCloud(updated.tripId);
  }

  Future<void> deleteMemory(String memoryId) async {
    final existing = state.firstWhere((m) => m.id == memoryId, orElse: () => state.first);
    state = state.where((m) => m.id != memoryId).toList();
    await _storage.saveAllMemories(state);
    _syncToCloud(existing.tripId);

    try {
      _ref.read(allAuditLogsProvider.notifier).logAction(
        TripAuditLog(
          id: const Uuid().v4(),
          tripId: existing.tripId,
          actionType: 'delete_memory',
          itemTitle: existing.caption ?? 'Photo Memory',
          performedByMemberId: 'me',
          performedByName: 'Companion',
          timestamp: DateTime.now(),
          changeDetails: 'Removed photo memory',
        ),
      );
    } catch (_) {}

    try {
      _ref.read(offlineSyncEngineProvider).enqueueMutation(
        action: MutationAction.deleteMemory,
        entityType: 'memory',
        entityId: memoryId,
        tripId: existing.tripId,
        payload: {'id': memoryId},
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
        expenses: _storage.getAllExpenses().where((e) => e.tripId == tripId).toList(),
        memories: state.where((m) => m.tripId == tripId).toList(),
        settlements: _storage.getAllSettlements().where((s) => s.tripId == tripId).toList(),
      );
      CloudTripSyncService.publishTrip(package);
    } catch (_) {}
  }
}

final allMemoriesProvider = StateNotifierProvider<MemoryNotifier, List<Memory>>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return MemoryNotifier(storage, ref);
});

final currentTripMemoriesProvider = Provider<List<Memory>>((ref) {
  final currentTrip = ref.watch(currentTripProvider);
  if (currentTrip == null) return [];

  final allMemories = ref.watch(allMemoriesProvider);
  final memories = allMemories.where((m) => m.tripId == currentTrip.id).toList();
  memories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return memories;
});

final stoppageMemoriesProvider = Provider.family<List<Memory>, String>((ref, stoppageId) {
  final tripMemories = ref.watch(currentTripMemoriesProvider);
  return tripMemories.where((m) => m.stoppageId == stoppageId).toList();
});
