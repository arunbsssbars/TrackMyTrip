import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/realtime_sync_service.dart';
import '../core/services/user_service.dart';
import '../models/trip.dart';
import '../models/trip_invitation.dart';
import '../models/trip_member.dart';
import 'trip_provider.dart';

class InvitationNotifier extends StateNotifier<List<TripInvitation>> {
  final LocalStorageService _storage;
  final Ref _ref;

  InvitationNotifier(this._storage, this._ref) : super([]) {
    loadPendingInvitations();
  }

  void loadPendingInvitations() {
    final pending = _storage.getPendingInvitations();
    state = pending;
  }

  /// Sends a new trip invitation to a companion
  Future<void> sendInvitation({
    required String tripId,
    required String tripTitle,
    required String inviteeUsername,
    String? inviteePhone,
    Map<String, dynamic>? tripJson,
  }) async {
    final currentUser = UserService.getCurrentUser();
    final invitation = TripInvitation(
      id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
      tripId: tripId,
      tripTitle: tripTitle,
      inviterId: currentUser.id,
      inviterName: currentUser.displayName,
      inviteeUsername: inviteeUsername,
      inviteePhone: inviteePhone,
      createdAt: DateTime.now(),
      status: InvitationStatus.pending,
      tripJson: tripJson,
    );

    // Save locally
    await _storage.saveInvitation(invitation);

    // Broadcast over WebSocket
    try {
      final syncService = _ref.read(realtimeSyncServiceProvider);
      syncService.broadcastTripInvitation(invitation.toJson());
    } catch (_) {}

    loadPendingInvitations();
  }

  /// Invited companion accepts the trip invitation
  Future<void> acceptInvitation(TripInvitation invitation) async {
    final currentUser = UserService.getCurrentUser();

    // 1. Mark invitation accepted
    await _storage.updateInvitationStatus(invitation.id, InvitationStatus.accepted);

    // 2. If trip data is included, add trip to current user's trips
    if (invitation.tripJson != null) {
      try {
        final incomingTrip = Trip.fromJson(invitation.tripJson!);
        final isAlreadyMember = incomingTrip.members.any((m) => m.name.toLowerCase() == currentUser.displayName.toLowerCase());

        Trip finalTrip = incomingTrip;
        if (!isAlreadyMember) {
          final newMember = TripMember(
            id: currentUser.id,
            name: currentUser.displayName,
            isCurrentUser: true,
            colorHex: currentUser.colorHex ?? '0xFF0D9488',
          );
          finalTrip = incomingTrip.copyWith(
            members: [...incomingTrip.members, newMember],
          );
        }

        await _storage.saveTrip(finalTrip);
        _ref.read(tripListProvider.notifier).reload();
      } catch (_) {}
    }

    // 3. Broadcast acceptance
    try {
      final syncService = _ref.read(realtimeSyncServiceProvider);
      syncService.broadcastInvitationResponse({
        'invitationId': invitation.id,
        'tripId': invitation.tripId,
        'status': 'accepted',
        'responderId': currentUser.id,
        'responderName': currentUser.displayName,
      });
    } catch (_) {}

    loadPendingInvitations();
  }

  /// Invited companion declines the trip invitation
  Future<void> declineInvitation(TripInvitation invitation) async {
    final currentUser = UserService.getCurrentUser();

    // 1. Mark invitation declined
    await _storage.updateInvitationStatus(invitation.id, InvitationStatus.declined);

    // 2. Broadcast decline
    try {
      final syncService = _ref.read(realtimeSyncServiceProvider);
      syncService.broadcastInvitationResponse({
        'invitationId': invitation.id,
        'tripId': invitation.tripId,
        'status': 'declined',
        'responderId': currentUser.id,
        'responderName': currentUser.displayName,
      });
    } catch (_) {}

    loadPendingInvitations();
  }

  /// Receives an incoming invitation payload from WebSocket or push notification
  Future<void> receiveIncomingInvitation(Map<String, dynamic> data) async {
    try {
      final invitation = TripInvitation.fromJson(data);
      await _storage.saveInvitation(invitation);
      loadPendingInvitations();
    } catch (_) {}
  }
}

final invitationProvider = StateNotifierProvider<InvitationNotifier, List<TripInvitation>>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return InvitationNotifier(storage, ref);
});
