import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/cloud_trip_sync_service.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/trip_share_service.dart';
import '../models/memory.dart';
import '../core/services/media_cache_service.dart';
import 'trip_provider.dart';

import '../models/sync_mutation.dart';
import '../models/proximity_alert.dart';
import '../core/services/offline_sync_engine.dart';
import '../core/services/realtime_sync_service.dart';
import '../core/services/proximity_alert_service.dart';
import '../core/services/firestore_sync_service.dart';
import '../core/services/tombstone_service.dart';
import '../core/services/cloudinary_service.dart';
import '../core/services/user_service.dart';

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

  Future<void> addMemory(
    Memory memory, {
    bool broadcast = true,
    bool pushRemote = true,
    bool enqueueSync = true,
  }) async {
    if (TombstoneService.isMemoryTombstoned(memory.id)) return;

    // Guard against remote status overwriting local cached photo status
    final existingIndex = state.indexWhere((m) => m.id == memory.id);
    Memory finalMemory = memory;
    if (existingIndex != -1) {
      final existing = state[existingIndex];
      // If already uploaded, preserve uploaded status and remoteUrl
      if (existing.uploadStatus == MediaUploadStatus.uploaded ||
          (existing.remoteUrl != null && existing.remoteUrl!.isNotEmpty)) {
        finalMemory = memory.copyWith(
          uploadStatus: MediaUploadStatus.uploaded,
          remoteUrl: existing.remoteUrl,
          mediaPath: existing.remoteUrl ?? memory.mediaPath,
          localPath: existing.localPath ?? memory.localPath,
        );
      } else if (existing.uploadStatus == MediaUploadStatus.local &&
          memory.uploadStatus == MediaUploadStatus.uploading &&
          (memory.remoteUrl == null || memory.remoteUrl!.isEmpty)) {
        finalMemory = memory.copyWith(
          uploadStatus: existing.uploadStatus,
          localPath: existing.localPath ?? memory.localPath,
          mediaPath: existing.mediaPath,
          remoteUrl: existing.remoteUrl,
        );
      }
    }

    // Also check if media cache service already completed upload for this memory
    try {
      final cachedItem = _ref.read(mediaCacheServiceProvider).itemForEntity(memory.id);
      if (cachedItem != null && cachedItem.remoteUrl != null && cachedItem.remoteUrl!.isNotEmpty) {
        finalMemory = finalMemory.copyWith(
          uploadStatus: MediaUploadStatus.uploaded,
          remoteUrl: cachedItem.remoteUrl,
          mediaPath: cachedItem.remoteUrl ?? finalMemory.mediaPath,
        );
      }
    } catch (_) {}

    state = [finalMemory, ...state.where((m) => m.id != finalMemory.id)];
    await _storage.saveAllMemories(state);

    if (pushRemote) {
      _syncToCloud(finalMemory.tripId);
      try {
        _ref.read(firestoreSyncServiceProvider).pushMemory(finalMemory);
      } catch (_) {}
    }

    if (broadcast) {
      try {
        _ref.read(realtimeSyncServiceProvider).broadcastNewMemory(finalMemory);
      } catch (_) {}
      try {
        final currentTrip = _ref.read(tripListProvider).where((t) => t.id == finalMemory.tripId).firstOrNull;
        final uploaderName = currentTrip?.getMemberName(finalMemory.uploadedByMemberId) ?? 'Companion';
        _ref.read(proximityAlertServiceProvider).broadcastActivityAlert(
          id: 'act_mem_${finalMemory.id}',
          tripId: finalMemory.tripId,
          type: AlertType.memoryAdded,
          title: 'Memory Added',
          message: '$uploaderName shared a memory: "${finalMemory.caption?.isNotEmpty == true ? finalMemory.caption! : "Trip photo"}"',
          senderMemberId: finalMemory.uploadedByMemberId,
          senderName: uploaderName,
          itemId: finalMemory.id,
          itemType: 'memory',
          urgency: AlertUrgency.low,
          showLocalBanner: false,
        );
      } catch (_) {}
    }

    if (enqueueSync) {


      try {
        _ref.read(offlineSyncEngineProvider).enqueueMutation(
          action: MutationAction.addMemory,
          entityType: 'memory',
          entityId: finalMemory.id,
          tripId: finalMemory.tripId,
          payload: finalMemory.toJson(),
        );
      } catch (_) {}
    }
  }

  Future<void> updateMemoryMediaUrl(String memoryId, String remoteUrl, {String? deleteToken}) async {
    final index = state.indexWhere((m) => m.id == memoryId);
    if (index == -1) {
      // Defensive fallback: check persistent storage in case memory was written or rehydrated
      final all = _storage.getAllMemories();
      final storageIdx = all.indexWhere((m) => m.id == memoryId);
      if (storageIdx != -1) {
        final updated = all[storageIdx].copyWith(
          mediaPath: remoteUrl,
          remoteUrl: remoteUrl,
          deleteToken: deleteToken ?? all[storageIdx].deleteToken,
          uploadStatus: MediaUploadStatus.uploaded,
        );
        all[storageIdx] = updated;
        await _storage.saveAllMemories(all);
        state = all;
        _syncToCloud(updated.tripId);
        try {
          _ref.read(firestoreSyncServiceProvider).pushMemory(updated);
        } catch (_) {}
      }
      return;
    }
    final updated = state[index].copyWith(
      mediaPath: remoteUrl,
      remoteUrl: remoteUrl,
      deleteToken: deleteToken ?? state[index].deleteToken,
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

    // Keep pending mutation payloads in sync with upload status
    try {
      final pending = _storage.getPendingMutations();
      for (final m in pending) {
        if (m.entityId == memoryId && (m.action == MutationAction.addMemory || m.action == MutationAction.updateMemory)) {
          final updatedPayload = Map<String, dynamic>.from(m.payload);
          updatedPayload['uploadStatus'] = status.name;
          if (updated.remoteUrl != null) {
            updatedPayload['remoteUrl'] = updated.remoteUrl;
            updatedPayload['mediaPath'] = updated.mediaPath;
          }
          await _storage.enqueueMutation(m.copyWith(payload: updatedPayload));
        }
      }
    } catch (_) {}
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

    // Cancel all pending mutations for this memory immediately to prevent resurrection upon reconnect/flush
    final pendingMutations = _storage.getPendingMutations();
    for (final m in pendingMutations) {
      if (m.entityId == memoryId) {
        await _storage.removeMutation(m.id);
      }
    }

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

    // Delete remote Cloudinary media asset
    try {
      final cloudinary = _ref.read(cloudinaryServiceProvider);
      String? publicId;
      if (existing.remoteUrl != null && existing.remoteUrl!.contains('cloudinary.com')) {
        publicId = CloudinaryService.extractPublicId(existing.remoteUrl!);
      } else if (existing.mediaPath.contains('cloudinary.com')) {
        publicId = CloudinaryService.extractPublicId(existing.mediaPath);
      }
      publicId ??= 'trackmytrip/trips/${existing.tripId}/memories/mem_$memoryId';
      await cloudinary.deleteAsset(
        publicId: publicId,
        deleteToken: existing.deleteToken,
      );
    } catch (_) {}

    if (broadcast) {
      try {
        _ref.read(realtimeSyncServiceProvider).broadcastDeleteMemory(memoryId, existing.tripId);
      } catch (_) {}

      // Activity notification broadcast for memory deletion
      try {
        final currentUser = UserService.getCurrentUser();
        final currentTrip = _ref.read(tripListProvider).where((t) => t.id == existing.tripId).firstOrNull;
        final senderName = currentTrip?.getMemberName(currentUser.id) ?? currentUser.displayName;
        final caption = existing.caption?.isNotEmpty == true ? existing.caption! : 'Trip photo';
        _ref.read(proximityAlertServiceProvider).broadcastActivityAlert(
          id: 'act_mem_del_${memoryId}_${DateTime.now().millisecondsSinceEpoch}',
          tripId: existing.tripId,
          type: AlertType.memoryDeleted,
          title: 'Memory Removed',
          message: '$senderName removed memory "$caption"',
          senderMemberId: currentUser.id,
          senderName: senderName,
          itemId: memoryId,
          itemType: 'memory',
          urgency: AlertUrgency.low,
          showLocalBanner: false,
        );
      } catch (_) {}
    }



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
        memories: state.where((m) => m.tripId == tripId && !TombstoneService.isMemoryTombstoned(m.id)).toList(),
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
