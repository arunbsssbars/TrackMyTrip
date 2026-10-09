import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/firestore_sync_service.dart';
import '../core/services/local_storage_service.dart';
import '../models/stoppage.dart';
import '../models/proximity_alert.dart';
import '../core/services/proximity_alert_service.dart';
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

  Future<void> addStoppage(Stoppage stoppage, {bool broadcast = true, bool broadcastActivity = true}) async {
    state = [stoppage, ...state.where((s) => s.id != stoppage.id)];
    await _storage.saveAllStoppages(state);

    if (broadcast) {
      try {
        _ref.read(firestoreSyncServiceProvider).pushStoppage(stoppage);
      } catch (_) {}

      // Stoppages are itinerary navigation waypoints and are NOT recorded in the financial audit log (Point 4)
      if (broadcastActivity) {
        try {
          final trip = _storage.getTrips().where((t) => t.id == stoppage.tripId).firstOrNull;
          final creator = trip?.currentUserMember ?? (trip?.members.isNotEmpty == true ? trip!.members.first : null);
          final authorName = stoppage.createdByName ?? creator?.name ?? 'Companion';

          final isSos = stoppage.category == 'sos' || stoppage.id.startsWith('sos_') || stoppage.name.contains('Emergency SOS');
          _ref.read(proximityAlertServiceProvider).broadcastActivityAlert(
            id: 'act_stop_${stoppage.id}',
            tripId: stoppage.tripId,
            type: isSos ? AlertType.sosEmergency : AlertType.stoppageAdded,
            title: isSos ? 'SOS Sent' : 'Stop Added',
            message: isSos ? '$authorName sent SOS broadcast' : '$authorName added stop "${stoppage.name}"',
            itemId: stoppage.id,
            itemType: isSos ? 'sos' : 'stop',
            showLocalBanner: true,
          );

          _ref.read(proximityAlertServiceProvider).seedStoppageArrivalDebounce(
            tripId: stoppage.tripId,
            stoppageId: stoppage.id,
          );
        } catch (_) {}
      }

      try {
        _ref.read(realtimeSyncServiceProvider).broadcastNewStoppage(stoppage);
      } catch (_) {}

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
  }

  Future<void> updateStoppage(Stoppage updatedStoppage, {bool broadcast = true}) async {
    state = [
      for (final s in state)
        if (s.id == updatedStoppage.id) updatedStoppage else s
    ];
    await _storage.saveAllStoppages(state);

    if (broadcast) {
      try {
        _ref.read(realtimeSyncServiceProvider).broadcastUpdateStoppage(updatedStoppage);
      } catch (_) {}
    }

    try {
      _ref.read(firestoreSyncServiceProvider).pushStoppage(updatedStoppage);
    } catch (_) {}

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

  Future<void> deleteStoppage(String stoppageId, {bool broadcast = true}) async {
    final existing = state.where((s) => s.id == stoppageId).firstOrNull;
    if (existing == null) return;
    state = state.where((s) => s.id != stoppageId).toList();
    await _storage.saveAllStoppages(state);

    if (broadcast) {
      try {
        _ref.read(realtimeSyncServiceProvider).broadcastDeleteStoppage(existing.tripId, stoppageId);
      } catch (_) {}
    }

    try {
      _ref.read(firestoreSyncServiceProvider).deleteStoppage(existing.tripId, stoppageId);
    } catch (_) {}

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

  Future<void> reorderStoppages(List<Stoppage> reorderedList) async {
    final updatedStops = <Stoppage>[];
    for (int i = 0; i < reorderedList.length; i++) {
      updatedStops.add(reorderedList[i].copyWith(orderIndex: i));
    }
    final existingIds = updatedStops.map((s) => s.id).toSet();
    state = [
      ...updatedStops,
      ...state.where((s) => !existingIds.contains(s.id)),
    ];
    await _storage.saveAllStoppages(state);

    for (final stop in updatedStops) {
      try {
        _ref.read(firestoreSyncServiceProvider).pushStoppage(stop);
      } catch (_) {}
      try {
        _ref.read(offlineSyncEngineProvider).enqueueMutation(
          action: MutationAction.updateStoppage,
          entityType: 'stoppage',
          entityId: stop.id,
          tripId: stop.tripId,
          payload: stop.toJson(),
        );
      } catch (_) {}
    }
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
  tripStoppages.sort((a, b) {
    final cmp = a.arrivedAt.compareTo(b.arrivedAt);
    if (cmp != 0) return cmp;
    final orderCmp = a.orderIndex.compareTo(b.orderIndex);
    if (orderCmp != 0) return orderCmp;
    return a.id.compareTo(b.id);
  });
  return tripStoppages;
});

final selectedStoppageIdProvider = StateProvider<String?>((ref) => null);

/// Programmatic focus target for MapTab (e.g. when jumping from TimelineTab)
final focusedStoppageProvider = StateProvider<Stoppage?>((ref) => null);

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

final tripStoppagesProvider = Provider.family<List<Stoppage>, String?>((ref, tripId) {
  if (tripId == null) return [];
  final allStoppages = ref.watch(allStoppagesProvider);
  final tripStoppages = allStoppages.where((s) => s.tripId == tripId).toList();
  tripStoppages.sort((a, b) {
    final cmp = a.arrivedAt.compareTo(b.arrivedAt);
    if (cmp != 0) return cmp;
    final orderCmp = a.orderIndex.compareTo(b.orderIndex);
    if (orderCmp != 0) return orderCmp;
    return a.id.compareTo(b.id);
  });
  return tripStoppages;
});

