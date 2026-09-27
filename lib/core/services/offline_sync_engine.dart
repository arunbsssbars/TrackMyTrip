import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/sync_mutation.dart';
import '../../providers/trip_provider.dart';
import '../../providers/auth_provider.dart';
import 'local_storage_service.dart';
import 'trip_share_service.dart';
import 'cloud_trip_sync_service.dart';

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
  int get pendingCount => _storage.getPendingMutations().where((m) => m.status == SyncStatus.pending).length;
  List<SyncMutation> get pendingMutations => _storage.getPendingMutations();

  Timer? _autoSyncTimer;

  void _initAutoSync() {
    // Periodically check if there are pending offline mutations to flush
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (pendingCount > 0 && !_isSyncing) {
        syncPendingMutationsNow();
      }
    });
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

    final pending = _storage.getPendingMutations().where((m) => m.status == SyncStatus.pending).toList();
    if (pending.isEmpty) {
      _lastSyncError = null;
      return true;
    }

    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();

    bool allSuccess = true;
    final tripIdsToSync = pending.map((m) => m.tripId).toSet();

    for (final tripId in tripIdsToSync) {
      try {
        final trips = await _storage.db.getTrips();
        final tripIndex = trips.indexWhere((t) => t.id == tripId);
        if (tripIndex != -1) {
          final trip = trips[tripIndex];
          if (trip.isDeleted) {
            // Drop mutations for deleted trip
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
            memories: _storage.getAllMemories().where((m) => m.tripId == tripId).toList(),
            settlements: _storage.getAllSettlements().where((s) => s.tripId == tripId).toList(),
          );
          final success = await CloudTripSyncService.publishTrip(package);
          if (!success) {
            allSuccess = false;
          }
        }
      } catch (e) {
        allSuccess = false;
        if (kDebugMode) {
          print('Failed to sync trip $tripId: $e');
        }
      }
    }

    if (allSuccess) {
      for (final mutation in pending) {
        try {
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
            await docRef.set(mutation.payload);
          }
        } catch (_) {}
        await _storage.removeMutation(mutation.id);
      }
      _lastSyncedTime = DateTime.now();
      _lastSyncError = null;
    } else {
      _lastSyncError = 'Firebase unreachable. All records remain 100% saved on this device.';
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
