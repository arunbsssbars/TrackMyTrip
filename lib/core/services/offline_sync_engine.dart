import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/sync_mutation.dart';
import '../../providers/trip_provider.dart';
import '../../providers/auth_provider.dart';
import 'local_storage_service.dart';
import 'trip_share_service.dart';
import 'cloud_trip_sync_service.dart';
import 'tombstone_service.dart';

class OfflineSyncEngine extends ChangeNotifier {
  final LocalStorageService _storage;
  final Ref? _ref;
  bool _isSyncing = false;
  DateTime? _lastSyncedTime;
  String? _lastSyncError;

  OfflineSyncEngine(this._storage, [this._ref]) {
    _initAutoSync();
  }

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncedTime => _lastSyncedTime;
  String? get lastSyncError => _lastSyncError;
  // Loop 44: allow UI to dismiss the sync error banner
  void clearLastSyncError() {
    _lastSyncError = null;
    notifyListeners();
  }
  int get pendingCount => _storage.getPendingMutations().where((m) => m.status == SyncStatus.pending || m.status == SyncStatus.failed).length;
  List<SyncMutation> get pendingMutations => _storage.getPendingMutations();

  Timer? _autoSyncTimer;

  void _initAutoSync() {
    // One-time pruning of duplicate/stale mutations on startup to prevent queue bloating (Point 14)
    _cleanupPendingQueue();

    // Periodically check if there are pending offline mutations to flush
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (pendingCount > 0 && !_isSyncing) {
        syncPendingMutationsNow();
      }
    });
  }

  /// Consolidates and deduplicates mutations for the same entity:
  /// 1. If an entity has an 'add' followed by a 'delete', both cancel out (no remote write needed).
  /// 2. If an entity has multiple 'update' mutations, merge their payloads into the latest one.
  /// 3. If an entity has an 'add' followed by 'update', merge payload into the 'add' mutation.
  /// 4. If an entity has 'update' followed by 'delete', discard the update and keep only the delete.
  List<SyncMutation> consolidateMutations(List<SyncMutation> mutations) {
    final Map<String, List<SyncMutation>> grouped = {};
    final List<SyncMutation> order = [];

    for (final m in mutations) {
      final key = '${m.entityType}_${m.entityId}';
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
        order.add(m);
      }
      grouped[key]!.add(m);
    }

    final List<SyncMutation> consolidated = [];

    for (final placeholder in order) {
      final key = '${placeholder.entityType}_${placeholder.entityId}';
      final list = grouped[key]!;
      if (list.isEmpty) continue;
      if (list.length == 1) {
        consolidated.add(list.first);
        continue;
      }

      // Sort chronological
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final first = list.first;
      final last = list.last;

      final isAdd = first.action == MutationAction.addExpense ||
          first.action == MutationAction.addStoppage ||
          first.action == MutationAction.addMemory ||
          first.action == MutationAction.addSettlement ||
          first.action == MutationAction.createTrip;

      final isLastDelete = last.action == MutationAction.deleteExpense ||
          last.action == MutationAction.deleteStoppage ||
          last.action == MutationAction.deleteMemory ||
          last.action == MutationAction.deleteSettlement ||
          last.action == MutationAction.deleteTrip;

      // Case 1: Added and then Deleted while offline -> completely canceled out locally!
      if (isAdd && isLastDelete) {
        continue;
      }

      // Case 2: Last action is Delete -> only need the delete mutation
      if (isLastDelete) {
        consolidated.add(last);
        continue;
      }

      // Case 3: Merge multiple updates or add + updates into one consolidated payload
      final mergedPayload = <String, dynamic>{};
      for (final m in list) {
        mergedPayload.addAll(m.payload);
      }

      consolidated.add(last.copyWith(
        action: isAdd ? first.action : last.action,
        payload: mergedPayload,
      ));
    }

    return consolidated;
  }

  Future<void> _cleanupPendingQueue() async {
    try {
      final all = _storage.getPendingMutations();
      final pending = all.where((m) => m.status == SyncStatus.pending || m.status == SyncStatus.failed).toList();
      final other = all.where((m) => m.status != SyncStatus.pending && m.status != SyncStatus.failed).toList();

      final consolidated = consolidateMutations(pending);
      if (consolidated.length < pending.length) {
        await _storage.saveAllMutations([...other, ...consolidated]);
        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  /// Queues a local offline action and immediately attempts to sync if online
  Future<void> enqueueMutation({
    required MutationAction action,
    required String entityType,
    required String entityId,
    required String tripId,
    required Map<String, dynamic> payload,
    bool syncImmediately = true,
  }) async {
    const uuid = Uuid();
    final mutation = SyncMutation(
      id: 'mut_${uuid.v4().substring(0, 8)}',
      action: action,
      entityType: entityType,
      entityId: entityId,
      tripId: tripId,
      payload: payload,
      createdAt: DateTime.now(),
      status: SyncStatus.pending,
    );

    await _storage.enqueueMutation(mutation);
    notifyListeners();

    // Trigger immediate sync attempt in background
    if (syncImmediately) {
      syncPendingMutationsNow();
    }
  }

  /// Remove single mutation by ID
  Future<void> removeMutation(String id) async {
    await _storage.removeMutation(id);
    if (pendingCount == 0) {
      _lastSyncError = null;
    }
    notifyListeners();
  }

  /// Mark all pending items as synced and clear the local outbox
  Future<void> resolveAllLocally() async {
    await _storage.saveAllMutations([]);
    _lastSyncedTime = DateTime.now();
    _lastSyncError = null;
    notifyListeners();
  }

  /// Clear all offline mutations
  Future<void> clearAll() async {
    await resolveAllLocally();
  }

  /// Manually or automatically flushes all pending mutations to the sync server (Firebase)
  Future<bool> syncPendingMutationsNow() async {
    if (_isSyncing) return false;

    // Guard: Only sync if an authenticated user session is active
    final authUser = _ref?.read(authNotifierProvider).valueOrNull ?? _storage.getAuthSession();
    if (authUser == null) {
      _isSyncing = false;
      return false;
    }

    final rawPending = _storage.getPendingMutations().where((m) => m.status == SyncStatus.pending || m.status == SyncStatus.failed).toList();
    if (rawPending.isEmpty) {
      _lastSyncError = null;
      return true;
    }

    // Deduplicate and consolidate mutations for idempotency and bandwidth efficiency
    final pending = consolidateMutations(rawPending);
    if (pending.length < rawPending.length) {
      final activeIds = pending.map((m) => m.id).toSet();
      final obsoleteMutations = rawPending.where((m) => !activeIds.contains(m.id));
      for (final m in obsoleteMutations) {
        await _storage.removeMutation(m.id);
      }
    }

    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();

    bool allSuccess = true;
    final tripIdsToSync = pending.map((m) => m.tripId).toSet();

    for (final tripId in tripIdsToSync) {
      try {
        if (TombstoneService.isTombstoned(tripId)) {
          // Trip was tombstoned: delete remote room and cloud documents, then drop mutations
          try {
            await CloudTripSyncService.deleteRoom(tripId);
            await CloudTripSyncService.firestore.collection('trips').doc(tripId).delete();
          } catch (_) {}
          for (final m in pending.where((p) => p.tripId == tripId)) {
            await _storage.removeMutation(m.id);
          }
          continue;
        }

        final trips = await _storage.db.getTrips();
        final tripIndex = trips.indexWhere((t) => t.id == tripId);
        if (tripIndex != -1) {
          final trip = trips[tripIndex];
          if (trip.isDeleted) {
            try {
              await CloudTripSyncService.deleteRoom(tripId);
              await CloudTripSyncService.firestore.collection('trips').doc(tripId).delete();
            } catch (_) {}
            for (final m in pending.where((p) => p.tripId == tripId)) {
              await _storage.removeMutation(m.id);
            }
            continue;
          }

          // Security guard: Ensure this trip actually belongs to the authenticated user
          final isOwnerOrMember = trip.createdByMemberId == authUser.id ||
              trip.members.any((m) =>
                  m.id == authUser.id ||
                  (authUser.email.isNotEmpty && m.email != null && m.email!.toLowerCase().trim() == authUser.email.toLowerCase().trim()));

          if (!isOwnerOrMember) {
            // Drop unauthenticated or foreign mutations
            for (final m in pending.where((p) => p.tripId == tripId)) {
              await _storage.removeMutation(m.id);
            }
            continue;
          }

          final package = TripPackage(
            trip: trip,
            stoppages: _storage.getAllStoppages().where((s) => s.tripId == tripId).toList(),
            expenses: _storage.getAllExpenses().where((e) => e.tripId == tripId).toList(),
            memories: _storage.getAllMemories().where((m) => m.tripId == tripId && !TombstoneService.isMemoryTombstoned(m.id)).toList(),
            settlements: _storage.getAllSettlements().where((s) => s.tripId == tripId).toList(),
          );
          final success = await CloudTripSyncService.publishTrip(package);
          if (!success) {
            allSuccess = false;
          }
        } else {
          // Trip not found in active trips: check if it was deleted or purged
          final tombstoneIds = await _storage.db.getTombstonedTripIds();
          if (tombstoneIds.contains(tripId)) {
            try {
              await CloudTripSyncService.deleteRoom(tripId);
              await CloudTripSyncService.firestore.collection('trips').doc(tripId).delete();
            } catch (_) {}
            for (final m in pending.where((p) => p.tripId == tripId)) {
              await _storage.removeMutation(m.id);
            }
          }
        }
      } catch (e) {
        allSuccess = false;
        if (kDebugMode) {
          debugPrint('[OfflineSyncEngine] Failed to sync trip $tripId: $e');
        }
      }
    }

    // Process individual pending mutations with per-item resilience
    for (final mutation in pending) {
      if (mutation.retryCount >= 8) {
        // Skip mutations that repeatedly failed to prevent hammering network
        continue;
      }
      try {
        final isTripEntity = mutation.entityType.toLowerCase() == 'trip';
        if (isTripEntity) {
          final tripDocRef = CloudTripSyncService.firestore.collection('trips').doc(mutation.tripId);
          if (mutation.action == MutationAction.deleteTrip) {
            await CloudTripSyncService.firestore.collection('deleted_trips_tombstones').doc(mutation.tripId).set({
              'tripId': mutation.tripId,
              'status': 'deleted',
              'deletedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)).catchError((_) {});
            await tripDocRef.delete();
            await CloudTripSyncService.deleteRoom(mutation.tripId);
          } else {
            await tripDocRef.set(mutation.payload, SetOptions(merge: true));
          }
        } else {
          final coll = _resolveCollection(mutation.entityType);
          final docRef = CloudTripSyncService.firestore
              .collection('trips')
              .doc(mutation.tripId)
              .collection(coll)
              .doc(mutation.entityId);

          if (mutation.action == MutationAction.deleteStoppage ||
              mutation.action == MutationAction.deleteExpense ||
              mutation.action == MutationAction.deleteMemory ||
              mutation.action == MutationAction.deleteSettlement) {
            await docRef.delete();
          } else {
            if ((mutation.action == MutationAction.addMemory || mutation.action == MutationAction.updateMemory) &&
                TombstoneService.isMemoryTombstoned(mutation.entityId)) {
              await _storage.removeMutation(mutation.id);
              continue;
            }
            await docRef.set(mutation.payload, SetOptions(merge: true));
          }
        }
        // Mutation applied successfully to Firestore: remove from local outbox
        await _storage.removeMutation(mutation.id);
      } catch (err) {
        allSuccess = false;
        if (kDebugMode) {
          debugPrint('[OfflineSyncEngine] Mutation sync failed for ${mutation.id}: $err');
        }
        // Guard: Do NOT remove mutation on failure! Update status and increment retry count
        final failedMutation = mutation.copyWith(
          status: SyncStatus.failed,
          retryCount: mutation.retryCount + 1,
          errorMessage: err.toString(),
        );
        await _storage.enqueueMutation(failedMutation);
      }
    }

    if (allSuccess) {
      _lastSyncedTime = DateTime.now();
      _lastSyncError = null;
    } else {
      _lastSyncError = 'Sync partial or offline. Unsynced changes remain safely queued on this device.';
    }
    
    _isSyncing = false;
    notifyListeners();
    return allSuccess;
  }

  String _resolveCollection(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'stoppage':
      case 'stoppages':
        return 'stoppages';
      case 'expense':
      case 'expenses':
        return 'expenses';
      case 'memory':
      case 'memories':
        return 'memories';
      case 'settlement':
      case 'settlements':
        return 'settlements';
      default:
        return entityType.endsWith('s') ? entityType : '${entityType}s';
    }
  }
}

final offlineSyncEngineProvider = ChangeNotifierProvider<OfflineSyncEngine>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return OfflineSyncEngine(storage, ref);
});

final pendingMutationsCountProvider = Provider<int>((ref) {
  final engine = ref.watch(offlineSyncEngineProvider);
  return engine.pendingCount;
});
