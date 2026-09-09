import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/cloud_trip_sync_service.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/trip_share_service.dart';
import '../models/trip.dart';
import '../models/trip_member.dart';

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  throw UnimplementedError('Initialize localStorageServiceProvider in main');
});

class TripNotifier extends StateNotifier<List<Trip>> {
  final LocalStorageService _storage;

  TripNotifier(this._storage) : super([]) {
    _loadTrips();
  }

  void _loadTrips() {
    final list = _storage.getTrips();
    list.sort((a, b) => b.startDate.compareTo(a.startDate));
    state = list;
  }

  void reload() {
    _loadTrips();
  }

  Future<void> addTrip(Trip trip) async {
    final list = [trip, ...state.where((t) => t.id != trip.id)];
    list.sort((a, b) => b.startDate.compareTo(a.startDate));
    state = list;
    await _storage.saveTrips(state);

    // Auto-publish to cloud room
    final package = TripPackage(
      trip: trip,
      stoppages: _storage.getAllStoppages().where((s) => s.tripId == trip.id).toList(),
      expenses: _storage.getAllExpenses().where((e) => e.tripId == trip.id).toList(),
      memories: _storage.getAllMemories().where((m) => m.tripId == trip.id).toList(),
      settlements: _storage.getAllSettlements().where((s) => s.tripId == trip.id).toList(),
    );
    CloudTripSyncService.publishTrip(package);
  }

  Future<void> updateTrip(Trip updatedTrip) async {
    state = [
      for (final trip in state)
        if (trip.id == updatedTrip.id) updatedTrip else trip
    ];
    await _storage.saveTrips(state);
  }

  Future<void> deleteTrip(String tripId) async {
    CloudTripSyncService.stopLiveSync(tripId);
    state = state.where((trip) => trip.id != tripId).toList();
    await _storage.saveTrips(state);
  }

  Future<void> addMemberToTrip(String tripId, TripMember member) async {
    final tripIndex = state.indexWhere((t) => t.id == tripId);
    if (tripIndex == -1) return;

    final trip = state[tripIndex];
    final updatedMembers = [...trip.members, member];
    final updatedTrip = trip.copyWith(members: updatedMembers);

    await updateTrip(updatedTrip);

    // Publish update
    final package = TripPackage(
      trip: updatedTrip,
      stoppages: _storage.getAllStoppages().where((s) => s.tripId == tripId).toList(),
      expenses: _storage.getAllExpenses().where((e) => e.tripId == tripId).toList(),
      memories: _storage.getAllMemories().where((m) => m.tripId == tripId).toList(),
      settlements: _storage.getAllSettlements().where((s) => s.tripId == tripId).toList(),
    );
    CloudTripSyncService.publishTrip(package);
  }

  Future<Trip> importTrip(TripPackage package, {String? activeMemberId}) async {
    final importedTrip = await _storage.importTripPackage(package, activeMemberId: activeMemberId);
    _loadTrips();
    return importedTrip;
  }

  Future<void> syncRemotePackage(TripPackage package) async {
    // Preserve local user identity when syncing remote package
    final existingTrip = state.firstWhere(
      (t) => t.id == package.trip.id,
      orElse: () => package.trip,
    );
    final activeMember = existingTrip.currentUserMember;

    await _storage.importTripPackage(package, activeMemberId: activeMember?.id);
    _loadTrips();
  }

  Future<void> updateMemberLocation(String tripId, String memberId, double lat, double lng) async {
    final tripIndex = state.indexWhere((t) => t.id == tripId);
    if (tripIndex == -1) return;

    final trip = state[tripIndex];
    final updatedMembers = trip.members.map((m) {
      if (m.id == memberId) {
        return m.copyWith(
          latitude: lat,
          longitude: lng,
          lastSeen: DateTime.now(),
        );
      }
      return m;
    }).toList();

    final updatedTrip = trip.copyWith(members: updatedMembers);
    await updateTrip(updatedTrip);
  }

  Future<void> switchActiveMember(String tripId, String memberId) async {
    await _storage.setActiveMember(tripId, memberId);
    _loadTrips();
  }
}

final tripListProvider = StateNotifierProvider<TripNotifier, List<Trip>>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return TripNotifier(storage);
});

final selectedTripIdProvider = StateProvider<String?>((ref) => null);

final currentTripProvider = Provider<Trip?>((ref) {
  final trips = ref.watch(tripListProvider);
  final selectedId = ref.watch(selectedTripIdProvider);
  if (selectedId == null && trips.isNotEmpty) return trips.first;
  try {
    return trips.firstWhere((t) => t.id == selectedId);
  } catch (_) {
    return trips.isNotEmpty ? trips.first : null;
  }
});
