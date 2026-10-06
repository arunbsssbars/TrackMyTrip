import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/cloud_trip_sync_service.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/trip_share_service.dart';
import '../models/memory.dart';
import '../core/services/media_cache_service.dart';
import 'trip_provider.dart';

import 'package:uuid/uuid.dart';
import '../models/trip_audit_log.dart';
import '../models/sync_mutation.dart';
import '../models/proximity_alert.dart';
import '../core/services/offline_sync_engine.dart';
import '../core/services/realtime_sync_service.dart';
import '../core/services/proximity_alert_service.dart';
import '../core/services/firestore_sync_service.dart';
import '../core/services/tombstone_service.dart';
import 'audit_log_provider.dart';

class MemoryNotifier extends StateNotifier<List<Memory>> {
  final LocalStorageService _storage;
  final Ref _ref;

  MemoryNotifier(this._storage, this._ref) : super([]) {
    _loadAllMemories();
  }

  void _loadAllMemories() {
    final trips = _storage.getTrips();
    final userTripIds = trips.map((t) => t.id).toSet();
    final loaded = _storage.getAllMemories().where((m) => userTripIds.contains(m.tripId) && !TombstoneService.isMemoryTombstoned(m.id)).map((m) {
      if (m.uploadStatus == MediaUploadStatus.uploading) {
        return m.copyWith(uploadStatus: MediaUploadStatus.local);
      }
      return m;
    }).toList();
    state = loaded;
  }

  void reload() {
    _loadAllMemories();
  }

  void reset() {
    state = [];
  }

  Future<void> addMemory(Memory memory, {bool broadcast = true}) async {
    if (TombstoneService.isMemoryTombstoned(memory.id)) return;
    state = [memory, ...state.where((m) => m.id != memory.id)];
    await _storage.saveAllMemories(state);
    _syncToCloud(memory.tripId);
    try {
      _ref.read(firestoreSyncServiceProvider).pushMemory(memory);
    } catch (_) {}

    if (broadcast) {
      try {
        _ref.read(realtimeSyncServiceProvider).broadcastNewMemory(memory);
      } catch (_) {}
      try {
        final currentTrip = _ref.read(tripListProvider).where((t) => t.id == memory.tripId).firstOrNull;
        final uploaderName = currentTrip?.getMemberName(memory.uploadedByMemberId) ?? 'Companion';
        _ref.read(proximityAlertServiceProvider).broadcastActivityAlert(
          id: 'act_mem_${memory.id}',
          tripId: memory.tripId,
          type: AlertType.memoryAdded,
          title: 'Memory Added',
          message: '$uploaderName shared a memory: "${memory.caption?.isNotEmpty == true ? memory.caption! : "Trip photo"}"',
          senderMemberId: memory.uploadedByMemberId,
          senderName: uploaderName,
          itemId: memory.id,
          itemType: 'memory',
          urgency: AlertUrgency.low,
          showLocalBanner: false,
        );
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

  Future<void> updateMemoryMediaUrl(String memoryId, String remoteUrl) async {
    final index = state.indexWhere((m) => m.id == memoryId);
    if (index == -1) return;
    final updated = state[index].copyWith(
      mediaPath: remoteUrl,
      remoteUrl: remoteUrl,
      uploadStatus: MediaUploadStatus.uploaded,
    );
    state = [
      for (final m in state)
        if (m.id == memoryId) updated else m
    ];
    await _storage.saveAllMemories(state);
    _syncToCloud(updated.tripId);
    try {
      _ref.read(firestoreSyncServiceProvider).pushMemory(updated);
    } catch (_) {}
  }

  Future<void> updateMemoryUploadStatus(String memoryId, MediaUploadStatus status) async {
    final index = state.indexWhere((m) => m.id == memoryId);
    if (index == -1) return;
    final updated = state[index].copyWith(uploadStatus: status);
    state = [
      for (final m in state)
        if (m.id == memoryId) updated else m
    ];
    await _storage.saveAllMemories(state);
  }

  Future<void> toggleLike(String memoryId, String memberId, {bool broadcast = true}) async {
    final index = state.indexWhere((m) => m.id == memoryId);
    if (index == -1) return;

    final memory = state[index];
    final likedList = List<String>.from(memory.likedByMemberIds);
    final wasLiked = likedList.contains(memberId);
    if (wasLiked) {
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

    if (broadcast) {
      try {
        _ref.read(realtimeSyncServiceProvider).broadcastMemoryLike(
          memoryId,
          memberId,
          !wasLiked,
          updated.tripId,
        );
      } catch (_) {}
    }
  }

  void receiveRemoteLike(String memoryId, String memberId, bool isLiked) {
    final index = state.indexWhere((m) => m.id == memoryId);
    if (index == -1) return;

    final memory = state[index];
    final likedList = List<String>.from(memory.likedByMemberIds);
    if (isLiked && !likedList.contains(memberId)) {
      likedList.add(memberId);
    } else if (!isLiked && likedList.contains(memberId)) {
      likedList.remove(memberId);
    } else {
      return; // No change
    }

    final updated = memory.copyWith(likedByMemberIds: likedList);
    state = [
      for (final m in state)
        if (m.id == memoryId) updated else m
    ];
    _storage.saveAllMemories(state);
  }

  Future<void> updateCaption(String memoryId, String newCaption, {bool broadcast = true}) async {
    final index = state.indexWhere((m) => m.id == memoryId);
    if (index == -1) return;

    final trimmed = newCaption.trim();
    final updated = state[index].copyWith(caption: trimmed.isNotEmpty ? trimmed : null);
    state = [
      for (final m in state)
        if (m.id == memoryId) updated else m
    ];
    await _storage.saveAllMemories(state);
    _syncToCloud(updated.tripId);

    try {
      _ref.read(firestoreSyncServiceProvider).pushMemory(updated);
    } catch (_) {}

    if (broadcast) {
      try {
        _ref.read(realtimeSyncServiceProvider).broadcastNewMemory(updated);
      } catch (_) {}
    }

    try {
      _ref.read(allAuditLogsProvider.notifier).logAction(
        TripAuditLog(
          id: const Uuid().v4(),
          tripId: updated.tripId,
          actionType: 'update_memory',
          itemTitle: updated.caption ?? 'Photo Memory',
          performedByMemberId: 'me',
          performedByName: 'Companion',
          timestamp: DateTime.now(),
          changeDetails: 'Updated caption to: "${updated.caption ?? ""}"',
        ),
      );
    } catch (_) {}

    try {
      _ref.read(offlineSyncEngineProvider).enqueueMutation(
        action: MutationAction.updateMemory,
        entityType: 'memory',
        entityId: memoryId,
        tripId: updated.tripId,
        payload: updated.toJson(),
      );
    } catch (_) {}
  }

  Future<void> deleteMemory(String memoryId, {bool broadcast = true}) async {
    final existing = state.where((m) => m.id == memoryId).firstOrNull;
    if (existing == null) return;

    await TombstoneService.markMemoryTombstoned(memoryId, tripId: existing.tripId);
    state = state.where((m) => m.id != memoryId).toList();
    await _storage.deleteMemory(memoryId);
    await _storage.saveAllMemories(state);
    _syncToCloud(existing.tripId);
    await MediaCacheService.deleteMediaFile(existing.mediaPath);
    if (existing.localPath != null && existing.localPath != existing.mediaPath) {
      await MediaCacheService.deleteMediaFile(existing.localPath);
    }
    try {
      _ref.read(mediaCacheServiceProvider).deleteForEntity(memoryId);
    } catch (_) {}
    try {
      _ref.read(firestoreSyncServiceProvider).deleteMemory(existing.tripId, memoryId);
    } catch (_) {}

    if (broadcast) {
      try {
        _ref.read(realtimeSyncServiceProvider).broadcastDeleteMemory(memoryId, existing.tripId);
      } catch (_) {}
    }

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

final tripMemoriesProvider = Provider.family<List<Memory>, String>((ref, tripId) {
  final allMemories = ref.watch(allMemoriesProvider);
  final memories = allMemories.where((m) => m.tripId == tripId).toList();
  memories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return memories;
});

final stoppageMemoriesProvider = Provider.family<List<Memory>, String>((ref, stoppageId) {
  final tripMemories = ref.watch(currentTripMemoriesProvider);
  return tripMemories.where((m) => m.stoppageId == stoppageId).toList();
});
