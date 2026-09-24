import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/cloud_trip_sync_service.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/trip_share_service.dart';
import '../models/stoppage.dart';
import 'trip_provider.dart';

import '../models/sync_mutation.dart';
import '../core/services/offline_sync_engine.dart';
import '../core/services/realtime_sync_service.dart';

class StoppageNotifier extends StateNotifier<List<Stoppage>> {
  final LocalStorageService _storage;
  final Ref _ref;

  StoppageNotifier(this._storage, this._ref) : super([]) {
    _loadAllStoppages();
  }

  void _loadAllStoppages() {
    state = _storage.getAllStoppages();
  }

  void reload() {
    _loadAllStoppages();
  }

  void reset() {
    state = [];
  }

  Future<void> addStoppage(Stoppage stoppage, {bool broadcast = true}) async {
    state = [...state, stoppage];
    await _storage.saveAllStoppages(state);
    _syncToCloud(stoppage.tripId);

    if (broadcast) {
      try {
        _ref.read(realtimeSyncServiceProvider).broadcastNewStoppage(stoppage);
      } catch (_) {}
    }



    try {
      _ref.read(offlineSyncEngineProvider).enqueueMutation(
        action: MutationAction.addStoppage,
        entityType: 'stoppage',
        entityId: stoppage.id,
        tripId: stoppage.tripId,
        payload: stoppage.toJson(),
      );
    } catch (_) {}
  }

  Future<void> updateStoppage(Stoppage updatedStoppage) async {
    state = [
      for (final s in state)
        if (s.id == updatedStoppage.id) updatedStoppage else s
    ];
    await _storage.saveAllStoppages(state);
    _syncToCloud(updatedStoppage.tripId);

    try {
      _ref.read(offlineSyncEngineProvider).enqueueMutation(
        action: MutationAction.updateStoppage,
        entityType: 'stoppage',
        entityId: updatedStoppage.id,
        tripId: updatedStoppage.tripId,
        payload: updatedStoppage.toJson(),
      );
    } catch (_) {}
  }

  Future<void> departStoppage(String stoppageId) async {
    final stoppageIndex = state.indexWhere((s) => s.id == stoppageId);
    if (stoppageIndex == -1) return;

    final stoppage = state[stoppageIndex];
    final updated = stoppage.copyWith(departedAt: DateTime.now());
    await updateStoppage(updated);


  }

  Future<void> deleteStoppage(String stoppageId) async {
    final existing = state.firstWhere((s) => s.id == stoppageId, orElse: () => state.first);
    state = state.where((s) => s.id != stoppageId).toList();
    await _storage.saveAllStoppages(state);
    _syncToCloud(existing.tripId);



    try {
      _ref.read(offlineSyncEngineProvider).enqueueMutation(
        action: MutationAction.deleteStoppage,
        entityType: 'stoppage',
        entityId: stoppageId,
        tripId: existing.tripId,
        payload: {'id': stoppageId},
      );
    } catch (_) {}
  }

  void _syncToCloud(String tripId) {
    try {
      final trips = _storage.getTrips();
      final trip = trips.firstWhere((t) => t.id == tripId);
      final package = TripPackage(
        trip: trip,
        stoppages: state.where((s) => s.tripId == tripId).toList(),
        expenses: _storage.getAllExpenses().where((e) => e.tripId == tripId).toList(),
        memories: _storage.getAllMemories().where((m) => m.tripId == tripId).toList(),
        settlements: _storage.getAllSettlements().where((s) => s.tripId == tripId).toList(),
      );
      CloudTripSyncService.publishTrip(package);
    } catch (_) {}
  }
}

final allStoppagesProvider = StateNotifierProvider<StoppageNotifier, List<Stoppage>>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return StoppageNotifier(storage, ref);
});

final currentTripStoppagesProvider = Provider<List<Stoppage>>((ref) {
  final currentTrip = ref.watch(currentTripProvider);
  if (currentTrip == null) return [];

  final allStoppages = ref.watch(allStoppagesProvider);
  final tripStoppages = allStoppages.where((s) => s.tripId == currentTrip.id).toList();
  tripStoppages.sort((a, b) => a.arrivedAt.compareTo(b.arrivedAt));
  return tripStoppages;
});

final selectedStoppageIdProvider = StateProvider<String?>((ref) => null);

final selectedStoppageProvider = Provider<Stoppage?>((ref) {
  final stoppageId = ref.watch(selectedStoppageIdProvider);
  if (stoppageId == null) return null;
  final stoppages = ref.watch(currentTripStoppagesProvider);
  try {
    return stoppages.firstWhere((s) => s.id == stoppageId);
  } catch (_) {
    return null;
  }
});
