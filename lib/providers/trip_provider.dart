import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/cloud_trip_sync_service.dart';
import '../core/services/firestore_sync_service.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/location_service.dart';
import '../core/services/offline_sync_engine.dart';
import '../core/services/realtime_sync_service.dart';
import '../core/services/tombstone_service.dart';
import '../core/services/media_cache_service.dart';
import '../core/services/trip_share_service.dart';
import '../models/auth_user.dart';
import '../models/trip.dart';
import '../models/trip_member.dart';
import '../models/proximity_alert.dart';
import '../core/services/proximity_alert_service.dart';
import 'auth_provider.dart';
import 'expense_provider.dart';
import 'memory_provider.dart';
import 'settlement_provider.dart';
import 'stoppage_provider.dart';
import 'audit_log_provider.dart';
import '../models/trip_audit_log.dart';
import '../core/services/user_service.dart';
import 'package:uuid/uuid.dart';

final currencyNotifierProvider = ChangeNotifierProvider<ValueNotifier<String>>((ref) {
  final notifier = ValueNotifier<String>(LocationService.currencyNotifier.value);
  void listener() {
    notifier.value = LocationService.currencyNotifier.value;
  }
  LocationService.currencyNotifier.addListener(listener);
  ref.onDispose(() {
    LocationService.currencyNotifier.removeListener(listener);
  });
  return notifier;
});

final isSyncingTripsProvider = StateProvider<bool>((ref) => false);

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  throw UnimplementedError('Initialize localStorageServiceProvider in main');
});

class TripNotifier extends StateNotifier<List<Trip>> {
  final LocalStorageService _storage;
  final Ref _ref;

  TripNotifier(this._storage, this._ref) : super([]) {
    _loadTrips();
    Future.microtask(() => syncUserTripsFromCloud());
  }

  void _loadTrips() {
    final authUser = _ref.read(authNotifierProvider).valueOrNull;
    final allTrips = _storage.getTrips();
    if (authUser == null) {
      state = [];
      return;
    }

    final userEmail = authUser.email.trim().toLowerCase();
    final userId = authUser.id;

    final filtered = <Trip>[];
    final seenIds = <String>{};
    for (final t in allTrips) {
      if (TombstoneService.isTombstoned(t.id)) continue;
      if (seenIds.contains(t.id)) continue;
      final isCreator = t.createdByMemberId == userId;
      final isMember = t.members.any((m) =>
          m.id == userId ||
          (userEmail.isNotEmpty && m.email != null && m.email!.trim().toLowerCase() == userEmail));

      if (isCreator || isMember) {
        seenIds.add(t.id);
        // Dynamically align isCurrentUser strictly to the active authenticated session
        final remappedMembers = t.members.map((m) {
          final isMe = m.id == userId ||
              (userEmail.isNotEmpty && m.email != null && m.email!.trim().toLowerCase() == userEmail);
          return m.copyWith(isCurrentUser: isMe);
        }).toList();

        // If user created the trip but isn't explicitly in the member list, add them as current user
        if (isCreator && !remappedMembers.any((m) => m.isCurrentUser)) {
          remappedMembers.insert(
            0,
            TripMember(
              id: userId,
              name: authUser.displayName.isNotEmpty ? authUser.displayName : 'Trip Lead',
              email: authUser.email.isNotEmpty ? authUser.email : null,
              isCurrentUser: true,
              role: 'creator',
              colorHex: '0xFF0D9488',
            ),
          );
        }

        filtered.add(t.copyWith(members: remappedMembers));
      }
    }

    filtered.sort((a, b) => b.startDate.compareTo(a.startDate));
    state = filtered;
  }

  void reload() {
    _loadTrips();
    syncUserTripsFromCloud();
  }

  void reset() {
    state = [];
    try {
      _ref.read(firestoreSyncServiceProvider).cancelUserTripsSubscription();
    } catch (_) {}
  }

  Future<void> syncUserTripsFromCloud() async {
    final authUser = _ref.read(authNotifierProvider).valueOrNull;
    if (authUser == null || authUser.id.isEmpty) return;

    _ref.read(isSyncingTripsProvider.notifier).state = true;
    try {
      final syncService = _ref.read(firestoreSyncServiceProvider);

      // Attach continuous real-time listener for companion's workspace
      syncService.subscribeUserTrips(
        userId: authUser.id,
        email: authUser.email,
      );

      final packages = await syncService.fetchTripsForUser(
        userId: authUser.id,
        email: authUser.email,
      );

      for (final pkg in packages) {
        await _storage.importTripPackage(pkg);
      }

      // Reconcile local storage against cloud:
      // If a local trip was deleted or missing from the cloud, purge it from local storage
      final cloudTripIds = packages.map((p) => p.trip.id).toSet();
      final localTrips = List<Trip>.from(state);

      for (final localTrip in localTrips) {
        if (!cloudTripIds.contains(localTrip.id)) {
          final isDeleted = await syncService.isTripDeletedOrMissing(
            localTrip.id,
            userId: authUser.id,
            email: authUser.email,
          );
          if (isDeleted) {
            await _storage.deleteTrip(localTrip.id);
          }
        }
      }

      _loadTrips();
      _reloadDependentProviders();

      // Ensure any pending mutations are cleanly reconciled with cloud
      try {
        final engine = _ref.read(offlineSyncEngineProvider);
        if (engine.pendingCount > 0) {
          await engine.syncPendingMutationsNow();
        }
      } catch (_) {}
    } catch (_) {
    } finally {
      _ref.read(isSyncingTripsProvider.notifier).state = false;
    }
  }

  void _reloadDependentProviders() {
    try {
      _ref.read(allExpensesProvider.notifier).reload();
    } catch (_) {}
    try {
      _ref.read(allStoppagesProvider.notifier).reload();
    } catch (_) {}
    try {
      _ref.read(allMemoriesProvider.notifier).reload();
    } catch (_) {}
    try {
      _ref.read(allSettlementsProvider.notifier).reload();
    } catch (_) {}
    try {
      _ref.read(allAuditLogsProvider.notifier).reload();
    } catch (_) {}
    try {
      _ref.read(proximityAlertServiceProvider).reload();
    } catch (_) {}
  }

  Future<void> addTrip(Trip trip) async {
    final resolvedCode = (trip.shareCode != null && trip.shareCode!.isNotEmpty)
        ? trip.shareCode!
        : CloudTripSyncService.getRoomCode(trip.id, trip: trip);
    final effectiveTrip = (trip.shareCode == resolvedCode)
        ? trip
        : trip.copyWith(shareCode: resolvedCode);
    if (TombstoneService.isTombstoned(effectiveTrip.id)) return;
    CloudTripSyncService.registerRoomCode(effectiveTrip.id, resolvedCode);

    // Prevent duplicate trip addition within rapid succession (e.g. double-tap)
    final isDuplicate = state.any((existing) =>
        existing.id == effectiveTrip.id ||
        (existing.title.trim().toLowerCase() == effectiveTrip.title.trim().toLowerCase() &&
            existing.createdByMemberId == effectiveTrip.createdByMemberId &&
            existing.createdAt.difference(effectiveTrip.createdAt).abs().inSeconds < 5));
    if (isDuplicate) return;

    final list = [effectiveTrip, ...state.where((t) => t.id != effectiveTrip.id)];
    list.sort((a, b) => b.startDate.compareTo(a.startDate));
    state = list;
    await _storage.saveTrip(effectiveTrip);

    // Auto-publish to cloud room & Firestore trips collection
    final package = TripPackage(
      trip: effectiveTrip,
      stoppages: _storage.getAllStoppages().where((s) => s.tripId == effectiveTrip.id).toList(),
      expenses: _storage.getAllExpenses().where((e) => e.tripId == effectiveTrip.id).toList(),
      memories: _storage.getAllMemories().where((m) => m.tripId == effectiveTrip.id).toList(),
      settlements: _storage.getAllSettlements().where((s) => s.tripId == effectiveTrip.id).toList(),
    );
    CloudTripSyncService.publishTrip(package);
    try {
      _ref.read(firestoreSyncServiceProvider).pushTrip(effectiveTrip);
    } catch (_) {}
  }

  Future<void> updateTrip(Trip updatedTrip) async {
    if (TombstoneService.isTombstoned(updatedTrip.id)) return;
    state = [
      for (final trip in state)
        if (trip.id == updatedTrip.id) updatedTrip else trip
    ];
    await _storage.saveTrip(updatedTrip);

    // Synchronize updated trip package to cloud room
    try {
      final package = TripPackage(
        trip: updatedTrip,
        stoppages: _storage.getAllStoppages().where((s) => s.tripId == updatedTrip.id).toList(),
        expenses: _storage.getAllExpenses().where((e) => e.tripId == updatedTrip.id).toList(),
        memories: _storage.getAllMemories().where((m) => m.tripId == updatedTrip.id).toList(),
        settlements: _storage.getAllSettlements().where((s) => s.tripId == updatedTrip.id).toList(),
      );
      CloudTripSyncService.publishTrip(package);
    } catch (_) {}

    try {
      _ref.read(firestoreSyncServiceProvider).pushTrip(updatedTrip);
    } catch (_) {}
  }

  /// Canonically reopens a concluded journey, logging to Trust History and notifying companions
  Future<void> reopenTrip(String tripId) async {
    final tripIndex = state.indexWhere((t) => t.id == tripId);
    if (tripIndex == -1) return;

    final trip = state[tripIndex];
    final updatedTrip = trip.copyWith(
      isCompleted: false,
      status: 'active',
    );
    await updateTrip(updatedTrip);

    final currentUser = UserService.getCurrentUser();
    // 1. Audit log
    try {
      final auditLog = TripAuditLog(
        id: const Uuid().v4(),
        tripId: tripId,
        actionType: 'trip_reopened',
        itemTitle: trip.title,
        performedByMemberId: currentUser.id,
        performedByName: currentUser.displayName,
        timestamp: DateTime.now(),
        changeDetails: '${currentUser.displayName} reopened "${trip.title}". Edits and live tracking re-enabled.',
      );
      await _ref.read(allAuditLogsProvider.notifier).logAction(auditLog);
    } catch (_) {}

    // 2. Broadcast Alert to companions and workspace
    try {
      await _ref.read(proximityAlertServiceProvider).broadcastTripReopened(
        tripId: trip.id,
        tripTitle: trip.title,
        reopenerName: currentUser.displayName,
      );
    } catch (_) {}
  }

  Future<void> deleteTrip(String tripId) async {
    // 0. Mark tombstone FIRST in dual-layer persistent cache
    await TombstoneService.markTombstoned(tripId);

    final trip = state.where((t) => t.id == tripId).firstOrNull;
    final authUser = _ref.read(authNotifierProvider).valueOrNull;
    final currentUid = authUser?.id;

    final isLead = trip != null && (trip.isCreator(currentUid) || trip.isCreator(trip.currentUserMember?.id));

    if (isLead) {
      // 1. Broadcast deletion to connected companions FIRST while still connected
      try {
        _ref.read(realtimeSyncServiceProvider).broadcastTripDeleted(tripId);
      } catch (_) {}

      // 2. Mark deleted in Firestore & delete live room doc
      try {
        await _ref.read(firestoreSyncServiceProvider).markTripDeleted(tripId);
        await CloudTripSyncService.deleteRoom(tripId);
      } catch (_) {}
    } else {
      // Non-creator leaving trip
      await leaveTrip(tripId);
      return;
    }

    // 3. Stop live sync & disconnect after broadcasting
    CloudTripSyncService.stopLiveSync(tripId);
    try {
      _ref.read(realtimeSyncServiceProvider).disconnect();
    } catch (_) {}

    // 4. Purge locally
    // Clean up local media files on disk for this trip
    try {
      final tripMemories = _storage.getMemories(tripId);
      for (final m in tripMemories) {
        MediaCacheService.deleteMediaFile(m.mediaPath);
      }
      final tripExpenses = _storage.getExpenses(tripId);
      for (final e in tripExpenses) {
        if (e.receiptImagePath != null) {
          MediaCacheService.deleteMediaFile(e.receiptImagePath);
        }
      }
    } catch (_) {}

    state = state.where((t) => t.id != tripId).toList();
    await _storage.deleteTrip(tripId);
    try {
      await _ref.read(proximityAlertServiceProvider).clearAlertsForTrip(tripId);
    } catch (_) {}
    if (_ref.read(selectedTripIdProvider) == tripId) {
      _ref.read(selectedTripIdProvider.notifier).state = null;
    }
    _reloadDependentProviders();
  }

  Future<void> leaveTrip(String tripId) async {
    final trip = state.where((t) => t.id == tripId).firstOrNull;
    final authUser = _ref.read(authNotifierProvider).valueOrNull;
    final currentUid = authUser?.id;
    final currentEmail = authUser?.email.trim().toLowerCase();

    final activeMember = trip?.currentUserMember ??
        trip?.members.where((m) =>
            (currentUid != null && m.id == currentUid) ||
            (currentEmail != null && currentEmail.isNotEmpty && m.email != null && m.email!.trim().toLowerCase() == currentEmail)
        ).firstOrNull;

    final memberId = activeMember?.id ?? currentUid;
    final memberName = activeMember?.name ?? authUser?.displayName ?? 'Companion';

    // 1. Stop live sync
    CloudTripSyncService.stopLiveSync(tripId);
    try {
      _ref.read(realtimeSyncServiceProvider).disconnect();
    } catch (_) {}

    // 2. Broadcast departure to other members
    if (memberId != null) {
      try {
        _ref.read(realtimeSyncServiceProvider).broadcastMemberLeft(tripId, memberId, memberName);
      } catch (_) {}
      try {
        _ref.read(proximityAlertServiceProvider).broadcastActivityAlert(
          tripId: tripId,
          type: AlertType.memberLeft,
          title: 'Member Left Trip',
          message: '$memberName has left the trip "${trip?.title ?? ""}"',
          senderMemberId: memberId,
          senderName: memberName,
        );
      } catch (_) {}
    }

    // 3. Remove membership from Firestore & room package
    if (memberId != null) {
      try {
        await _ref.read(firestoreSyncServiceProvider).removeMemberFromTripInCloud(
          tripId,
          memberId,
          email: currentEmail,
        );
        await CloudTripSyncService.removeMemberFromRoom(tripId, memberId);
      } catch (_) {}
    }

    // 4. Purge locally for this user
    state = state.where((t) => t.id != tripId).toList();
    await _storage.deleteTrip(tripId);
    try {
      await _ref.read(proximityAlertServiceProvider).clearAlertsForTrip(tripId);
    } catch (_) {}
    if (_ref.read(selectedTripIdProvider) == tripId) {
      _ref.read(selectedTripIdProvider.notifier).state = null;
    }
    _reloadDependentProviders();
  }

  Future<void> deleteTripLocally(String tripId) async {
    await TombstoneService.markTombstoned(tripId);
    CloudTripSyncService.stopLiveSync(tripId);
    try {
      _ref.read(realtimeSyncServiceProvider).disconnect();
    } catch (_) {}
    state = state.where((t) => t.id != tripId).toList();
    await _storage.deleteTrip(tripId);
    try {
      await _ref.read(proximityAlertServiceProvider).clearAlertsForTrip(tripId);
    } catch (_) {}
    if (_ref.read(selectedTripIdProvider) == tripId) {
      _ref.read(selectedTripIdProvider.notifier).state = null;
    }
    _reloadDependentProviders();
  }

  /// When a creator deletes a shared journey, industry standard (Splitwise/Tricount)
  /// dictates preserving companions' personal ledgers & global accounting rather than
  /// destroying their financial trail. This transitions the trip into a preserved archive.
  Future<void> archiveTripByCreator(String tripId) async {
    final tripIndex = state.indexWhere((t) => t.id == tripId);
    if (tripIndex == -1) return;

    final trip = state[tripIndex];
    final currentUser = UserService.getCurrentUser();
    if (trip.isCreator(currentUser.id) || trip.isCreator(trip.currentUserMember?.id)) {
      await deleteTripLocally(tripId);
      return;
    }

    CloudTripSyncService.stopLiveSync(tripId);
    final updatedTrip = trip.copyWith(
      status: 'archived_by_creator',
      isCompleted: true,
    );
    await _storage.saveTrip(updatedTrip);
    state = [
      for (final t in state)
        if (t.id == tripId) updatedTrip else t
    ];
    _reloadDependentProviders();
  }

  Future<void> removeMemberFromTrip(String tripId, String memberId) async {
    final tripIndex = state.indexWhere((t) => t.id == tripId);
    if (tripIndex == -1) return;

    final trip = state[tripIndex];
    final updatedMembers = trip.members.where((m) => m.id != memberId).toList();
    final updatedTrip = trip.copyWith(members: updatedMembers);

    await updateTrip(updatedTrip);
  }


  Future<void> addMemberToTrip(String tripId, TripMember member) async {
    final tripIndex = state.indexWhere((t) => t.id == tripId);
    if (tripIndex == -1) return;

    final trip = state[tripIndex];
    final memberEmail = member.email?.trim().toLowerCase();
    final updatedMembers = [
      ...trip.members.where((m) {
        if (m.id == member.id) return false;
        if (memberEmail != null && memberEmail.isNotEmpty && m.email != null) {
          if (m.email!.trim().toLowerCase() == memberEmail) return false;
        }
        return true;
      }),
      member,
    ];
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
    _reloadDependentProviders();
    if (!state.any((t) => t.id == importedTrip.id)) {
      state = [importedTrip, ...state];
    }
    try {
      _ref.read(firestoreSyncServiceProvider).pushTrip(importedTrip);
    } catch (_) {}
    return importedTrip;
  }

  Future<void> syncRemotePackage(TripPackage package) async {
    final authUser = _ref.read(authNotifierProvider).valueOrNull;
    final currentUid = authUser?.id;
    final currentEmail = authUser?.email.trim().toLowerCase() ?? '';

    // Check if current user is a member of the existing trip
    final existingTrip = state.where((t) => t.id == package.trip.id).firstOrNull;
    final activeMember = existingTrip?.currentUserMember ??
        existingTrip?.members.where((m) =>
            (currentUid != null && m.id == currentUid) ||
            (currentEmail.isNotEmpty && m.email != null && m.email!.trim().toLowerCase() == currentEmail)
        ).firstOrNull;

    TripPackage safePackage = package;
    // If incoming cloud package doesn't contain the local traveler, preserve them!
    if (activeMember != null && !package.trip.members.any((m) => m.id == activeMember.id)) {
      final preservedMembers = [
        ...package.trip.members.map((m) => m.copyWith(isCurrentUser: false)),
        activeMember.copyWith(isCurrentUser: true),
      ];
      safePackage = TripPackage(
        trip: package.trip.copyWith(members: preservedMembers),
        stoppages: package.stoppages,
        expenses: package.expenses,
        memories: package.memories,
        settlements: package.settlements,
        auditLogs: package.auditLogs,
      );
    }

    await _storage.importTripPackage(safePackage, activeMemberId: activeMember?.id);
    _loadTrips();
    _reloadDependentProviders();
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
  final notifier = TripNotifier(storage, ref);
  ref.listen<AsyncValue<AuthUser?>>(authNotifierProvider, (_, __) {
    notifier.reload();
  });
  return notifier;
});

final selectedTripIdProvider = StateProvider<String?>((ref) => null);

final currentTripProvider = Provider<Trip?>((ref) {
  final trips = ref.watch(tripListProvider);
  final selectedId = ref.watch(selectedTripIdProvider);
  if (selectedId == null && trips.isNotEmpty) {
    // Prioritize active, ongoing (non-concluded) journeys
    final activeTrip = trips.where((t) => !t.isCompleted && t.status != 'completed' && t.status != 'concluded' && t.status != 'ended').firstOrNull;
    return activeTrip ?? trips.first;
  }
  try {
    return trips.firstWhere((t) => t.id == selectedId);
  } catch (_) {
    final activeTrip = trips.where((t) => !t.isCompleted && t.status != 'completed' && t.status != 'concluded' && t.status != 'ended').firstOrNull;
    return activeTrip ?? (trips.isNotEmpty ? trips.first : null);
  }
});
