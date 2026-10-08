import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/realtime_sync_service.dart';
import '../core/services/user_service.dart';
import '../models/trip.dart';
import '../models/trip_invitation.dart';
import '../models/trip_member.dart';
import '../models/proximity_alert.dart';
import '../core/services/proximity_alert_service.dart';
import 'trip_provider.dart';
import '../core/services/firestore_sync_service.dart';

class InvitationNotifier extends StateNotifier<List<TripInvitation>> {
  final LocalStorageService _storage;
  final Ref _ref;
  final List<StreamSubscription> _subscriptions = [];

  InvitationNotifier(this._storage, this._ref) : super([]) {
    loadPendingInvitations();
    fetchPendingInvitationsFromCloud();
    _listenToFirestoreInvitations();
  }

  void loadPendingInvitations() {
    final currentUser = UserService.getCurrentUser();
    final effectiveUid = currentUser.id != 'usr_me' ? currentUser.id : null;
    final pending = _storage.getPendingInvitations(
      currentUserId: effectiveUid,
      currentUserEmail: currentUser.email,
      currentUsername: currentUser.username,
    );
    state = pending;
  }

  /// Actively queries Firestore for invitations addressed to the active user profile
  Future<void> fetchPendingInvitationsFromCloud() async {
    try {
      if (Firebase.apps.isEmpty) return;
      final currentUser = UserService.getCurrentUser();
      String? authUid;
      try {
        authUid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {}
      final effectiveUid = (authUid != null && authUid.isNotEmpty)
          ? authUid
          : (currentUser.id != 'usr_me' ? currentUser.id : null);

      final collection = FirebaseFirestore.instance.collection('invitations');
      bool hasNew = false;

      // 1. Fetch by inviteeId
      if (effectiveUid != null && effectiveUid.isNotEmpty) {
        final query = await collection
            .where('inviteeId', isEqualTo: effectiveUid)
            .where('status', isEqualTo: 'pending')
            .get();
        for (final doc in query.docs) {
          try {
            final inv = TripInvitation.fromJson(doc.data());
            await _storage.saveInvitation(inv);
            _notifyIncomingInvitation(inv);
            hasNew = true;
          } catch (_) {}
        }
      }

      // 2. Fetch by email
      if (currentUser.email != null && currentUser.email!.isNotEmpty) {
        final cleanEmail = currentUser.email!.trim().toLowerCase();
        final query = await collection
            .where('inviteeEmail', isEqualTo: cleanEmail)
            .where('status', isEqualTo: 'pending')
            .get();
        for (final doc in query.docs) {
          try {
            final inv = TripInvitation.fromJson(doc.data());
            await _storage.saveInvitation(inv);
            _notifyIncomingInvitation(inv);
            hasNew = true;
          } catch (_) {}
        }
      }

      // 3. Fetch by username
      if (currentUser.username.isNotEmpty && currentUser.username != 'traveler') {
        final cleanUsername = currentUser.username.trim().toLowerCase();
        final query = await collection
            .where('inviteeUsername', isEqualTo: cleanUsername)
            .where('status', isEqualTo: 'pending')
            .get();
        for (final doc in query.docs) {
          try {
            final inv = TripInvitation.fromJson(doc.data());
            await _storage.saveInvitation(inv);
            _notifyIncomingInvitation(inv);
            hasNew = true;
          } catch (_) {}
        }
      }

      // 4. Fetch outgoing invitations to catch any offline acceptances
      if (effectiveUid != null && effectiveUid.isNotEmpty) {
        final outgoingQuery = await collection
            .where('inviterId', isEqualTo: effectiveUid)
            .get();
        for (final doc in outgoingQuery.docs) {
          try {
            final inv = TripInvitation.fromJson(doc.data());
            await _storage.saveInvitation(inv);
            if (inv.status == InvitationStatus.accepted) {
              final trips = _ref.read(tripListProvider);
              final trip = trips.where((t) => t.id == inv.tripId).firstOrNull;
              if (trip != null) {
                final isAlreadyMember = trip.members.any((m) =>
                  (inv.inviteeId != null && m.id == inv.inviteeId) ||
                  (inv.inviteeEmail != null && m.email != null && m.email!.toLowerCase() == inv.inviteeEmail!.toLowerCase()) ||
                  m.name.toLowerCase() == inv.inviteeUsername.toLowerCase()
                );
                if (!isAlreadyMember) {
                  const colors = ['0xFF10B981', '0xFFEC4899', '0xFF3B82F6', '0xFFF97316', '0xFF8B5CF6', '0xFF14B8A6'];
                  final newColor = colors[trip.members.length % colors.length];
                  final newMember = TripMember(
                    id: inv.inviteeId ?? 'member_${DateTime.now().millisecondsSinceEpoch}',
                    name: inv.inviteeUsername.isNotEmpty ? inv.inviteeUsername : (inv.inviteeEmail?.split('@').first ?? 'Companion'),
                    email: inv.inviteeEmail,
                    isCurrentUser: false,
                    colorHex: newColor,
                  );
                  await _ref.read(tripListProvider.notifier).updateTrip(
                    trip.copyWith(members: [...trip.members, newMember]),
                  );
                }
              }
            }
          } catch (_) {}
        }
      }

      if (hasNew) {
        loadPendingInvitations();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[InvitationNotifier] fetchPendingInvitationsFromCloud error: $e');
      }
    }
  }

  void _listenToFirestoreInvitations() {
    try {
      if (Firebase.apps.isEmpty) return;
      final currentUser = UserService.getCurrentUser();
      String? authUid;
      try {
        authUid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {}
      final effectiveUid = (authUid != null && authUid.isNotEmpty)
          ? authUid
          : (currentUser.id != 'usr_me' ? currentUser.id : null);

      final collection = FirebaseFirestore.instance.collection('invitations');

      // Listen by inviteeId
      if (effectiveUid != null && effectiveUid.isNotEmpty) {
        final sub = collection
            .where('inviteeId', isEqualTo: effectiveUid)
            .where('status', isEqualTo: 'pending')
            .snapshots()
            .listen(_onFirestoreInvitationsReceived, onError: (e) {
          if (kDebugMode) debugPrint('[InvitationNotifier] inviteeId stream error: $e');
        });
        _subscriptions.add(sub);
      }

      // Listen by email
      if (currentUser.email != null && currentUser.email!.isNotEmpty) {
        final cleanEmail = currentUser.email!.trim().toLowerCase();
        final sub = collection
            .where('inviteeEmail', isEqualTo: cleanEmail)
            .where('status', isEqualTo: 'pending')
            .snapshots()
            .listen(_onFirestoreInvitationsReceived, onError: (e) {
          if (kDebugMode) debugPrint('[InvitationNotifier] email stream error: $e');
        });
        _subscriptions.add(sub);
      }

      // Listen by username
      if (currentUser.username.isNotEmpty && currentUser.username != 'traveler') {
        final cleanUsername = currentUser.username.trim().toLowerCase();
        final sub = collection
            .where('inviteeUsername', isEqualTo: cleanUsername)
            .where('status', isEqualTo: 'pending')
            .snapshots()
            .listen(_onFirestoreInvitationsReceived, onError: (e) {
          if (kDebugMode) debugPrint('[InvitationNotifier] username stream error: $e');
        });
        _subscriptions.add(sub);
      }

      // Listen to outgoing invitations sent by this user (to detect when invitee accepts or declines)
      if (effectiveUid != null && effectiveUid.isNotEmpty) {
        final outgoingSub = collection
            .where('inviterId', isEqualTo: effectiveUid)
            .snapshots()
            .listen(_onOutgoingInvitationsReceived, onError: (e) {
          if (kDebugMode) debugPrint('[InvitationNotifier] outgoing invitations stream error: $e');
        });
        _subscriptions.add(outgoingSub);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[InvitationNotifier] _listenToFirestoreInvitations setup error: $e');
      }
    }
  }

  void _onOutgoingInvitationsReceived(QuerySnapshot<Map<String, dynamic>> snapshot) async {
    for (final doc in snapshot.docs) {
      try {
        final data = doc.data();
        final invitation = TripInvitation.fromJson(data);
        await _storage.saveInvitation(invitation);

        if (invitation.status == InvitationStatus.accepted) {
          final trips = _ref.read(tripListProvider);
          final trip = trips.where((t) => t.id == invitation.tripId).firstOrNull;

          if (trip != null) {
            final isAlreadyMember = trip.members.any((m) =>
              (invitation.inviteeId != null && m.id == invitation.inviteeId) ||
              (invitation.inviteeEmail != null && m.email != null && m.email!.toLowerCase() == invitation.inviteeEmail!.toLowerCase()) ||
              m.name.toLowerCase() == invitation.inviteeUsername.toLowerCase()
            );

            if (!isAlreadyMember) {
              const colors = ['0xFF10B981', '0xFFEC4899', '0xFF3B82F6', '0xFFF97316', '0xFF8B5CF6', '0xFF14B8A6'];
              final newColor = colors[trip.members.length % colors.length];

              final newMember = TripMember(
                id: invitation.inviteeId ?? 'member_${DateTime.now().millisecondsSinceEpoch}',
                name: invitation.inviteeUsername.isNotEmpty ? invitation.inviteeUsername : (invitation.inviteeEmail?.split('@').first ?? 'Companion'),
                email: invitation.inviteeEmail,
                isCurrentUser: false,
                colorHex: newColor,
              );

              final updatedTrip = trip.copyWith(
                members: [...trip.members, newMember],
              );

              await _ref.read(tripListProvider.notifier).updateTrip(updatedTrip);
            }
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[InvitationNotifier] _onOutgoingInvitationsReceived error: $e');
      }
    }
    loadPendingInvitations();
  }

  void _onFirestoreInvitationsReceived(QuerySnapshot<Map<String, dynamic>> snapshot) async {
    bool hasNew = false;
    for (final doc in snapshot.docs) {
      try {
        final data = doc.data();
        final invitation = TripInvitation.fromJson(data);
        if (invitation.status == InvitationStatus.pending) {
          await _storage.saveInvitation(invitation);
          _notifyIncomingInvitation(invitation);
          hasNew = true;
        }
      } catch (_) {}
    }
    if (hasNew) {
      loadPendingInvitations();
    }
  }

  void _notifyIncomingInvitation(TripInvitation inv) {
    final alertService = _ref.read(proximityAlertServiceProvider);
    final alertId = 'inv_alert_${inv.id}';
    if (alertService.alerts.any((a) => a.id == alertId)) return;

    final inviterDisplayName = inv.inviterName.isNotEmpty ? inv.inviterName : 'A companion';
    alertService.addLocalAlert(
      ProximityAlert(
        id: alertId,
        tripId: inv.tripId,
        type: AlertType.invitation,
        title: 'Trip Invitation Received',
        message: '$inviterDisplayName has invited you to join "${inv.tripTitle}"',
        senderMemberId: inv.inviterId,
        senderName: inviterDisplayName,
        timestamp: inv.createdAt,
        urgency: AlertUrgency.high,
        isOutgoing: false,
      ),
    );
  }

  /// Sends a new trip invitation to a companion
  Future<void> sendInvitation({
    required String tripId,
    required String tripTitle,
    String? inviteeId,
    required String inviteeUsername,
    String? inviteeEmail,
    String? inviteePhone,
    Map<String, dynamic>? tripJson,
    bool createLocalNotification = true,
  }) async {
    final currentUser = UserService.getCurrentUser();
    String inviterId = currentUser.id;
    try {
      final fbUid = FirebaseAuth.instance.currentUser?.uid;
      if (fbUid != null && fbUid.isNotEmpty) {
        inviterId = fbUid;
      }
    } catch (_) {}

    final cleanInviteeEmail = inviteeEmail?.trim().toLowerCase();
    final cleanInviteeUsername = inviteeUsername.trim().toLowerCase();

    // Guard: Custom/offline placeholder companions cannot receive app invitations
    if (inviteeId != null && (inviteeId.startsWith('custom_') || inviteeId.startsWith('offline_') || inviteeId.startsWith('member_'))) {
      if (kDebugMode) {
        debugPrint('[InvitationNotifier] Suppressed sending invitation to custom/offline companion $inviteeId ($inviteeUsername)');
      }
      return;
    }
    if ((cleanInviteeEmail == null || cleanInviteeEmail.isEmpty) && (inviteeId == null || inviteeId.isEmpty)) {
      if (kDebugMode) {
        debugPrint('[InvitationNotifier] Cannot send invitation without email or registered user ID');
      }
      return;
    }

    // Deduplication guard: Do not send duplicate pending invitation to same companion
    final existingInvitations = _storage.getSentInvitations();
    final alreadyPending = existingInvitations.any((inv) {
      if (inv.tripId != tripId || inv.status != InvitationStatus.pending) return false;
      if (inviteeId != null && inv.inviteeId == inviteeId) return true;
      if (cleanInviteeEmail != null && inv.inviteeEmail != null && inv.inviteeEmail!.trim().toLowerCase() == cleanInviteeEmail) return true;
      if (inv.inviteeUsername.trim().toLowerCase() == cleanInviteeUsername) return true;
      return false;
    });

    if (alreadyPending) {
      if (kDebugMode) {
        debugPrint('[InvitationNotifier] Duplicate invitation suppressed for trip $tripId to $cleanInviteeUsername');
      }
      return;
    }

    final invitation = TripInvitation(
      id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
      tripId: tripId,
      tripTitle: tripTitle,
      inviterId: inviterId,
      inviterName: currentUser.displayName,
      inviteeId: inviteeId,
      inviteeUsername: inviteeUsername,
      inviteeEmail: cleanInviteeEmail,
      inviteePhone: inviteePhone,
      createdAt: DateTime.now(),
      status: InvitationStatus.pending,
      tripJson: tripJson,
    );


    // 1. Save to local SQLite outbox
    await _storage.saveInvitation(invitation);

    // 2. Write to Cloud Firestore for cross-device notification
    try {
      await FirebaseFirestore.instance
          .collection('invitations')
          .doc(invitation.id)
          .set(invitation.toJson(), SetOptions(merge: true));
      if (kDebugMode) {
        debugPrint('[InvitationNotifier] Successfully published invitation ${invitation.id} to Firestore for ${invitation.inviteeEmail ?? invitation.inviteeUsername}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[InvitationNotifier] Firestore set invitation error: $e');
      }
    }

    // 3. Broadcast over WebSocket for fast local peer discovery
    try {
      final syncService = _ref.read(realtimeSyncServiceProvider);
      syncService.broadcastTripInvitation(invitation.toJson());
    } catch (_) {}

    // 4. Create 1 local outgoing notification for the creator (Requirement 2 & 11)
    if (createLocalNotification) {
      final target = cleanInviteeUsername.isNotEmpty ? "@$cleanInviteeUsername" : (cleanInviteeEmail ?? "companion");
      _ref.read(proximityAlertServiceProvider).addLocalAlert(
        ProximityAlert(
          id: 'inv_sent_${invitation.id}',
          tripId: tripId,
          type: AlertType.invitation,
          title: 'Trip Invitation Sent',
          message: 'Invited $target to join "$tripTitle"',
          senderMemberId: currentUser.id,
          senderName: currentUser.displayName,
          timestamp: DateTime.now(),
          urgency: AlertUrgency.normal,
          isOutgoing: true,
        ),
      );
    }

    loadPendingInvitations();
  }

  /// Sends trip invitations in batch to multiple companions, producing only 1 consolidated notification for the creator (Requirement 2 & 11)
  Future<void> sendInvitationsBatch({
    required String tripId,
    required String tripTitle,
    required List<TripMember> invitees,
    Map<String, dynamic>? tripJson,
  }) async {
    if (invitees.isEmpty) return;

    for (final member in invitees) {
      if (member.id.startsWith('custom_') || member.id.startsWith('offline_') || member.id.startsWith('member_')) {
        continue;
      }
      if (member.email != null && member.email!.trim().isNotEmpty) {
        final cleanEmail = member.email!.trim().toLowerCase();
        final username = cleanEmail.split('@').first;
        final inviteeId = member.id;

        await sendInvitation(
          tripId: tripId,
          tripTitle: tripTitle,
          inviteeId: inviteeId,
          inviteeUsername: username,
          inviteeEmail: cleanEmail,
          tripJson: tripJson,
          createLocalNotification: false,
        );
      }
    }

    // Exactly 1 consolidated notification for the creator
    final currentUser = UserService.getCurrentUser();
    String summaryMessage;
    if (invitees.length == 1) {
      summaryMessage = 'Invited ${invitees.first.name} to join "$tripTitle"';
    } else {
      final names = invitees.map((i) => i.name).take(3).join(', ');
      final more = invitees.length > 3 ? ' and ${invitees.length - 3} more' : '';
      summaryMessage = 'Invited ${invitees.length} companions ($names$more) to join "$tripTitle"';
    }

    _ref.read(proximityAlertServiceProvider).addLocalAlert(
      ProximityAlert(
        id: 'inv_batch_${DateTime.now().millisecondsSinceEpoch}',
        tripId: tripId,
        type: AlertType.invitation,
        title: 'Trip Invitations Sent',
        message: summaryMessage,
        senderMemberId: currentUser.id,
        senderName: currentUser.displayName,
        timestamp: DateTime.now(),
        urgency: AlertUrgency.normal,
        isOutgoing: true,
      ),
    );
  }

  void refreshListeners() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    loadPendingInvitations();
    fetchPendingInvitationsFromCloud();
    _listenToFirestoreInvitations();
  }

  void reset() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    state = [];
  }

  /// Invited companion accepts the trip invitation
  Future<void> acceptInvitation(TripInvitation invitation) async {
    final currentUser = UserService.getCurrentUser();

    // 1. Mark invitation accepted locally
    await _storage.updateInvitationStatus(invitation.id, InvitationStatus.accepted);

    // 2. Mark accepted in Cloud Firestore
    try {
      await FirebaseFirestore.instance.collection('invitations').doc(invitation.id).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedBy': currentUser.id,
      });
    } catch (_) {}

    // 3. Append member to Cloud Firestore trip document if accessible or create if missing
    try {
      final tripDocRef = FirebaseFirestore.instance.collection('trips').doc(invitation.tripId);
      final tripDoc = await tripDocRef.get();
      final newMemberJson = TripMember(
        id: currentUser.id,
        name: currentUser.displayName,
        email: currentUser.email,
        isCurrentUser: false,
        role: TripMember.roleMember,
        colorHex: currentUser.colorHex ?? '0xFF0D9488',
      ).toJson();

      final userCleanEmail = currentUser.email?.trim().toLowerCase();

      if (tripDoc.exists && tripDoc.data() != null) {
        final data = tripDoc.data()!;
        final existingMembers = (data['members'] as List<dynamic>?) ?? [];
        final updatedMembers = [
          ...existingMembers.where((m) {
            if (m is Map) {
              if (m['id'] == currentUser.id) return false;
              if (userCleanEmail != null && userCleanEmail.isNotEmpty) {
                final mEmail = m['email']?.toString().trim().toLowerCase();
                if (mEmail == userCleanEmail) return false;
              }
            }
            return true;
          }),
          newMemberJson,
        ];
        final memberIds = (data['memberIds'] as List<dynamic>?)?.map((e) => e.toString()).toSet() ?? {};
        memberIds.add(currentUser.id);
        final memberEmails = (data['memberEmails'] as List<dynamic>?)?.map((e) => e.toString().toLowerCase()).toSet() ?? {};
        if (userCleanEmail != null && userCleanEmail.isNotEmpty) {
          memberEmails.add(userCleanEmail);
        }

        await tripDocRef.update({
          'members': updatedMembers,
          'memberIds': memberIds.toList(),
          'memberEmails': memberEmails.toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (invitation.tripJson != null) {
        final baseTrip = Trip.fromJson(invitation.tripJson!);
        final updatedMembers = [
          ...baseTrip.members.where((m) {
            if (m.id == currentUser.id) return false;
            if (userCleanEmail != null && userCleanEmail.isNotEmpty && m.email != null) {
              if (m.email!.trim().toLowerCase() == userCleanEmail) return false;
            }
            return true;
          }),
          TripMember.fromJson(newMemberJson),
        ];
        final memberIds = updatedMembers.map((m) => m.id).toSet()..add(currentUser.id);
        final memberEmails = updatedMembers.map((m) => m.email).where((e) => e != null && e.isNotEmpty).cast<String>().toSet();
        if (userCleanEmail != null && userCleanEmail.isNotEmpty) {
          memberEmails.add(userCleanEmail);
        }

        await tripDocRef.set({
          ...baseTrip.toJson(),
          'creatorId': invitation.inviterId,
          'createdByMemberId': invitation.inviterId,
          'members': updatedMembers.map((m) => m.toJson()).toList(),
          'memberIds': memberIds.toList(),
          'memberEmails': memberEmails.toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[InvitationNotifier] acceptInvitation firestore trip update error: $e');
    }

    // 4. Import trip package into local storage with deduplication
    if (invitation.tripJson != null) {
      try {
        final incomingTrip = Trip.fromJson(invitation.tripJson!);
        final userCleanEmail = currentUser.email?.trim().toLowerCase();
        final existingMember = incomingTrip.members.where(
          (m) => m.id == currentUser.id ||
              (userCleanEmail != null && userCleanEmail.isNotEmpty && m.email != null && m.email!.trim().toLowerCase() == userCleanEmail) ||
              m.name.toLowerCase() == currentUser.displayName.toLowerCase(),
        ).firstOrNull;

        const colors = ['0xFF10B981', '0xFFEC4899', '0xFF3B82F6', '0xFFF97316', '0xFF8B5CF6', '0xFF14B8A6'];
        final newColor = colors[incomingTrip.members.length % colors.length];
        final newMember = TripMember(
          id: currentUser.id,
          name: currentUser.displayName,
          email: currentUser.email,
          isCurrentUser: true,
          role: TripMember.roleMember,
          colorHex: currentUser.colorHex ?? existingMember?.colorHex ?? newColor,
        );

        final updatedMembers = [
          ...incomingTrip.members.where((m) =>
              m.id != currentUser.id &&
              (userCleanEmail == null || userCleanEmail.isEmpty || m.email == null || m.email!.trim().toLowerCase() != userCleanEmail) &&
              m.name.toLowerCase() != currentUser.displayName.toLowerCase()),
          newMember,
        ];

        final updatedTrip = incomingTrip.copyWith(members: updatedMembers);
        await _storage.saveTrip(updatedTrip);
      } catch (e) {
        if (kDebugMode) debugPrint('[InvitationNotifier] acceptInvitation local trip save error: $e');
      }
    }

    // Try fetching full trip package from cloud if possible
    try {
      final syncService = _ref.read(firestoreSyncServiceProvider);
      final fullPkg = await syncService.fetchTripById(invitation.tripId);
      if (fullPkg != null) {
        await _storage.importTripPackage(fullPkg, activeMemberId: currentUser.id);
      }
    } catch (_) {}

    _ref.read(tripListProvider.notifier).reload();

    // 5. Broadcast acceptance
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

    try {
      _ref.read(proximityAlertServiceProvider).broadcastActivityAlert(
        id: 'inv_acc_${invitation.id}',
        tripId: invitation.tripId,
        type: AlertType.invitationAccepted,
        title: 'Invitation Accepted',
        message: '${currentUser.displayName} joined "${invitation.tripTitle}"',
        showLocalBanner: false,
      );
    } catch (_) {}

    // Update existing invitation alert so it is shown as Accepted and never as Received again
    try {
      final alertService = _ref.read(proximityAlertServiceProvider);
      final existingAlerts = alertService.alerts.where((a) =>
        a.id == 'inv_alert_${invitation.id}' ||
        (a.tripId == invitation.tripId && a.type == AlertType.invitation && !a.isOutgoing)
      ).toList();

      for (final alert in existingAlerts) {
        final updatedAlert = alert.copyWith(
          type: AlertType.invitationAccepted,
          title: 'Invitation Accepted',
          message: 'You accepted the invitation to join "${invitation.tripTitle}"',
          isRead: true,
        );
        await alertService.updateAlert(updatedAlert);
      }
      // Eliminate duplicate local alert if we already mutated the original invitation alert
      if (existingAlerts.isNotEmpty) {
        await alertService.deleteAlert('inv_acc_${invitation.id}');
      }
    } catch (_) {}

    loadPendingInvitations();
  }

  /// Invited companion declines the trip invitation
  Future<void> declineInvitation(TripInvitation invitation) async {
    final currentUser = UserService.getCurrentUser();

    // 1. Mark invitation rejected locally
    await _storage.updateInvitationStatus(invitation.id, InvitationStatus.rejected);

    // 2. Mark rejected in Cloud Firestore
    try {
      await FirebaseFirestore.instance.collection('invitations').doc(invitation.id).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    // 3. Broadcast rejection
    try {
      final syncService = _ref.read(realtimeSyncServiceProvider);
      syncService.broadcastInvitationResponse({
        'invitationId': invitation.id,
        'tripId': invitation.tripId,
        'status': 'rejected',
        'responderId': currentUser.id,
        'responderName': currentUser.displayName,
      });
    } catch (_) {}

    try {
      _ref.read(proximityAlertServiceProvider).broadcastActivityAlert(
        tripId: invitation.tripId,
        type: AlertType.invitationRejected,
        title: 'Invitation Declined',
        message: '${currentUser.displayName} declined the invite for "${invitation.tripTitle}"',
      );
    } catch (_) {}

    // Update existing invitation alert to Declined
    try {
      final alertService = _ref.read(proximityAlertServiceProvider);
      final existingAlerts = alertService.alerts.where((a) =>
        a.id == 'inv_alert_${invitation.id}' ||
        (a.tripId == invitation.tripId && a.type == AlertType.invitation && !a.isOutgoing)
      ).toList();

      for (final alert in existingAlerts) {
        final updatedAlert = alert.copyWith(
          type: AlertType.invitationRejected,
          title: 'Invitation Declined',
          message: 'You declined the invite for "${invitation.tripTitle}"',
          isRead: true,
        );
        await alertService.updateAlert(updatedAlert);
      }
    } catch (_) {}

    loadPendingInvitations();
  }

  /// Cancels an existing invitation
  Future<void> cancelInvitation(String invitationId) async {
    await _storage.deleteInvitation(invitationId);
    try {
      await FirebaseFirestore.instance.collection('invitations').doc(invitationId).delete();
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

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}

final invitationProvider = StateNotifierProvider<InvitationNotifier, List<TripInvitation>>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return InvitationNotifier(storage, ref);
});

final sentInvitationsProvider = Provider<List<TripInvitation>>((ref) {
  ref.watch(invitationProvider);
  final storage = ref.watch(localStorageServiceProvider);
  final currentUser = UserService.getCurrentUser();
  String? authUid;
  try {
    authUid = FirebaseAuth.instance.currentUser?.uid;
  } catch (_) {}
  final effectiveUid = (authUid != null && authUid.isNotEmpty)
      ? authUid
      : (currentUser.id != 'usr_me' ? currentUser.id : null);
  return storage.getSentInvitations(currentUserId: effectiveUid);
});
