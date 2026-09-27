import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/firestore_sync_service.dart';
import '../core/services/local_storage_service.dart';
import '../models/stoppage.dart';
import '../models/trip_audit_log.dart';
import '../models/proximity_alert.dart';
import '../core/services/proximity_alert_service.dart';
import '../core/services/user_service.dart';
import 'audit_log_provider.dart';
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
    state = [stoppage, ...state.where((s) => s.id != stoppage.id)];
    await _storage.saveAllStoppages(state);

    if (broadcast) {
      try {
        _ref.read(firestoreSyncServiceProvider).pushStoppage(stoppage);
      } catch (_) {}

      try {
        final trip = _storage.getTrips().where((t) => t.id == stoppage.tripId).firstOrNull;
        final creator = trip?.currentUserMember ?? (trip?.members.isNotEmpty == true ? trip!.members.first : null);
        final authorName = creator?.name ?? 'Companion';

        _ref.read(allAuditLogsProvider.notifier).logAction(TripAuditLog(
          id: 'stop_${stoppage.id}',
          tripId: stoppage.tripId,
          actionType: 'add_stoppage',
          itemTitle: stoppage.name,
          performedByMemberId: stoppage.createdBy.isNotEmpty ? stoppage.createdBy : (creator?.id ?? 'usr_me'),
          performedByName: authorName,
          timestamp: stoppage.arrivedAt,
          changeDetails: 'Waypoint stop marked on itinerary',
        ));

        _ref.read(proximityAlertServiceProvider).broadcastActivityAlert(
          tripId: stoppage.tripId,
          type: AlertType.stoppageArrival,
          title: 'New Waypoint Added',
          message: '$authorName added stop "${stoppage.name}"',
        );
      } catch (_) {}

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

  Future<void> updateStoppage(Stoppage updatedStoppage) async {
    state = [
      for (final s in state)
        if (s.id == updatedStoppage.id) updatedStoppage else s
    ];
    await _storage.saveAllStoppages(state);

    try {
      _ref.read(firestoreSyncServiceProvider).pushStoppage(updatedStoppage);
    } catch (_) {}

    try {
      final currentUser = UserService.getCurrentUser();
      _ref.read(allAuditLogsProvider.notifier).logAction(TripAuditLog(
        id: 'stop_edit_${updatedStoppage.id}_${DateTime.now().millisecondsSinceEpoch}',
        tripId: updatedStoppage.tripId,
        actionType: 'edit_stoppage',
        itemTitle: 'Updated: ${updatedStoppage.name}',
        performedByMemberId: currentUser.id,
        performedByName: currentUser.displayName,
        timestamp: DateTime.now(),
        changeDetails: 'Waypoint updated',
      ));
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

  Future<void> deleteStoppage(String stoppageId) async {
    final existing = state.firstWhere((s) => s.id == stoppageId, orElse: () => state.first);
    state = state.where((s) => s.id != stoppageId).toList();
    await _storage.saveAllStoppages(state);

    try {
      _ref.read(firestoreSyncServiceProvider).deleteStoppage(existing.tripId, stoppageId);
    } catch (_) {}

    try {
      final currentUser = UserService.getCurrentUser();
      _ref.read(allAuditLogsProvider.notifier).logAction(TripAuditLog(
        id: 'stop_del_${stoppageId}_${DateTime.now().millisecondsSinceEpoch}',
        tripId: existing.tripId,
        actionType: 'delete_stoppage',
        itemTitle: 'Deleted: ${existing.name}',
        performedByMemberId: currentUser.id,
        performedByName: currentUser.displayName,
        timestamp: DateTime.now(),
        changeDetails: 'Waypoint stop removed from itinerary',
      ));
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

final tripStoppagesProvider = Provider.family<List<Stoppage>, String?>((ref, tripId) {
  if (tripId == null) return [];
  final allStoppages = ref.watch(allStoppagesProvider);
  final tripStoppages = allStoppages.where((s) => s.tripId == tripId).toList();
  tripStoppages.sort((a, b) => a.arrivedAt.compareTo(b.arrivedAt));
  return tripStoppages;
});

