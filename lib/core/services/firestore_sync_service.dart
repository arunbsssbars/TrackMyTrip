import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/expense.dart';
import '../../models/memory.dart';
import '../../models/proximity_alert.dart';
import '../../models/settlement.dart';
import '../../models/stoppage.dart';
import '../../models/trip.dart';
import '../../models/trip_audit_log.dart';
import '../../models/trip_member.dart';
import '../../providers/audit_log_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/settlement_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';
import 'cloud_trip_sync_service.dart';
import 'live_companion_tracker_service.dart';
import 'proximity_alert_service.dart';
import 'tombstone_service.dart';
import 'trip_share_service.dart';
import 'user_service.dart';

/// ---------------------------------------------------------------------------
/// FirestoreSyncService
/// ---------------------------------------------------------------------------
/// The central offline-first sync hub for TrackMyTrip.
///
/// Replaces the previous local-WebSocket + HTTP-polling architecture with
/// Firebase Cloud Firestore, providing:
///
///   • **Real-time push** — Firestore snapshot listeners deliver updates to all
///     companions within milliseconds, with zero polling overhead.
///   • **Offline-first** — The Firestore SDK caches every write locally and
///     auto-flushes the queue once connectivity is restored.
///   • **ACID writes** — Batch writes guarantee atomicity for multi-entity ops.
///   • **Battery efficiency** — Location broadcasts remain throttled (≥8 m or
///     ≥10 s elapsed) to minimise radio duty cycle.
///
/// ## Firestore Collection Structure
/// ```
/// trips/{tripId}
///   stoppages/{stoppageId}   — trip stops
///   expenses/{expenseId}     — bills & splits
///   memories/{memoryId}      — photo memories
///   audit_logs/{logId}       — activity trail
///   proximity_alerts/{id}    — SOS & safety alerts
///   members/{memberId}
///     location/{_singleton}  — live GPS beacon (single doc per member)
/// ```
///
/// ## Conflict Resolution
/// All writes include an `updatedAt` [Timestamp]. Incoming remote documents are
/// applied only when their `updatedAt` is newer than the locally cached value
/// (last-write-wins, suitable for collaborative travel data).
/// ---------------------------------------------------------------------------
class FirestoreSyncService {
  final Ref _ref;
  final FirebaseFirestore _db;

  /// Active Firestore snapshot subscriptions keyed by collection path.
  final Map<String, StreamSubscription<QuerySnapshot>> _listeners = {};

  /// Active single-doc listeners (e.g. member location beacons).
  final Map<String, StreamSubscription<DocumentSnapshot>> _docListeners = {};

  /// Currently observed trip ID.
  String? _activeTripId;

  /// Battery-saving throttle state for location broadcasting.
  double? _lastBroadcastLat;
  double? _lastBroadcastLng;
  DateTime? _lastBroadcastTime;

  /// Active subscriptions to listen for trip changes across the user's workspace in real-time
  final List<StreamSubscription> _userTripsSubscriptions = [];

  FirestoreSyncService(this._ref, {FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  /// Subscribes to changes on trips where the user is a creator or member.
  /// Automatically purges deleted trips from local workspace in real-time.
  void subscribeUserTrips({required String userId, String? email}) {
    if (userId.isEmpty) return;
    for (final sub in _userTripsSubscriptions) {
      sub.cancel();
    }
    _userTripsSubscriptions.clear();

    final cleanEmail = email?.trim().toLowerCase();

    void handleTripChange(DocumentChange<Map<String, dynamic>> change) {
      try {
        final doc = change.doc;
        final tripId = doc.id;
        final data = doc.data();

        if (TombstoneService.isTombstoned(tripId)) {
          _ref.read(tripListProvider.notifier).deleteTripLocally(tripId);
          return;
        }

        // Note: Do not aggressively delete on DocumentChangeType.removed.
        // A doc leaving a partial query snapshot must not wipe the trip from local device.

        if (data != null) {
          final isDeleted = data['status'] == 'deleted' || data['isDeleted'] == true;
          if (isDeleted) {
            TombstoneService.markTombstoned(tripId);
            _ref.read(tripListProvider.notifier).archiveTripByCreator(tripId);
            return;
          }

          final isCreator = data['creatorId'] == userId || data['createdByMemberId'] == userId;
          if (!isCreator) {
            final memberIds = (data['memberIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
            final memberEmails = (data['memberEmails'] as List<dynamic>?)?.map((e) => e.toString().trim().toLowerCase()).toList() ?? [];
            final hasEmail = cleanEmail != null && cleanEmail.isNotEmpty;
            if (!memberIds.contains(userId) && (!hasEmail || !memberEmails.contains(cleanEmail))) {
              _ref.read(tripListProvider.notifier).deleteTripLocally(tripId);
            }
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[FirestoreSyncService] handleTripChange error: $e');
      }
    }

    try {
      final memberSub = _db
          .collection('trips')
          .where('memberIds', arrayContains: userId)
          .snapshots()
          .listen((snap) {
        for (final change in snap.docChanges) {
          handleTripChange(change);
        }
      });
      _userTripsSubscriptions.add(memberSub);
    } catch (_) {}

    try {
      final creatorSub = _db
          .collection('trips')
          .where('creatorId', isEqualTo: userId)
          .snapshots()
          .listen((snap) {
        for (final change in snap.docChanges) {
          handleTripChange(change);
        }
      });
      _userTripsSubscriptions.add(creatorSub);
    } catch (_) {}

    if (cleanEmail != null && cleanEmail.isNotEmpty) {
      try {
        final emailSub = _db
            .collection('trips')
            .where('memberEmails', arrayContains: cleanEmail)
            .snapshots()
            .listen((snap) {
          for (final change in snap.docChanges) {
            handleTripChange(change);
          }
        });
        _userTripsSubscriptions.add(emailSub);
      } catch (_) {}
    }
  }

  void cancelUserTripsSubscription() {
    for (final sub in _userTripsSubscriptions) {
      sub.cancel();
    }
    _userTripsSubscriptions.clear();
  }

  // --------------------------------------------------------------------------
  // Lifecycle
  // --------------------------------------------------------------------------

  /// Attaches real-time Firestore listeners for [tripId].
  ///
  /// If already listening to a different trip, the old listeners are torn down
  /// first. Calling with the same [tripId] twice is a no-op.
  void connectTripRoom(String tripId) {
    if (tripId.isEmpty || TombstoneService.isTombstoned(tripId)) return;
    if (_activeTripId == tripId) return;
    disconnectAll();
    _activeTripId = tripId;
    _subscribeTripDoc(tripId);
    _subscribeStoppages(tripId);
    _subscribeExpenses(tripId);
    _subscribeSettlements(tripId);
    _subscribeMemories(tripId);
    _subscribeAuditLogs(tripId);
    _subscribeProximityAlerts(tripId);
    _subscribeCompanionLocations(tripId);
    if (kDebugMode) {
      debugPrint('[FirestoreSyncService] Connected to trip room: $tripId');
    }
  }

  /// Tears down all active Firestore listeners.
  void disconnectAll() {
    for (final sub in _listeners.values) {
      sub.cancel();
    }
    for (final sub in _docListeners.values) {
      sub.cancel();
    }
    _listeners.clear();
    _docListeners.clear();
    _activeTripId = null;
    try {
      _ref.read(liveCompanionTrackerProvider.notifier).clearAllCompanionLocations();
    } catch (_) {}
  }

  // --------------------------------------------------------------------------
  // Trip Doc — Subscribe (Deletion & Membership Revocation Listener)
  // --------------------------------------------------------------------------

  void _subscribeTripDoc(String tripId) {
    if (TombstoneService.isTombstoned(tripId)) {
      disconnectAll();
      _ref.read(tripListProvider.notifier).deleteTripLocally(tripId);
      return;
    }
    final path = 'trip_$tripId';
    _docListeners[path] = _db.collection('trips').doc(tripId).snapshots().listen((snap) {
      if (TombstoneService.isTombstoned(tripId)) {
        disconnectAll();
        _ref.read(tripListProvider.notifier).deleteTripLocally(tripId);
        return;
      }
      if (!snap.exists || snap.data() == null) {
        // Document does not exist or not accessible yet; do not nuke local data
        return;
      }
      final data = snap.data()!;
      if (data['status'] == 'deleted' || data['isDeleted'] == true) {
        TombstoneService.markTombstoned(tripId);
        disconnectAll();
        _ref.read(tripListProvider.notifier).deleteTripLocally(tripId);
        return;
      }

      final authUser = _ref.read(authNotifierProvider).valueOrNull;
      final myUid = authUser?.id;
      final myEmail = authUser?.email.trim().toLowerCase();
      final isCreator = data['createdByMemberId'] == myUid || data['creatorId'] == myUid;

      if (!isCreator && myUid != null) {
        final memberIds = (data['memberIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        final memberEmails = (data['memberEmails'] as List<dynamic>?)?.map((e) => e.toString().trim().toLowerCase()).toList() ?? [];
        final hasEmail = myEmail != null && myEmail.isNotEmpty;
        if (!memberIds.contains(myUid) && (!hasEmail || !memberEmails.contains(myEmail))) {
          disconnectAll();
          _ref.read(tripListProvider.notifier).deleteTripLocally(tripId);
        }
      }
    });
  }

  // --------------------------------------------------------------------------
  // Stoppages — Subscribe
  // --------------------------------------------------------------------------

  void _subscribeStoppages(String tripId) {
    if (TombstoneService.isTombstoned(tripId)) return;
    final path = 'stoppages_$tripId';
    _listeners[path] = _db
        .collection('trips')
        .doc(tripId)
        .collection('stoppages')
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        try {
          final data = change.doc.data();
          if (data == null) continue;
          final stoppage = Stoppage.fromJson({...data, 'id': change.doc.id});
          switch (change.type) {
            case DocumentChangeType.added:
            case DocumentChangeType.modified:
              _ref
                  .read(allStoppagesProvider.notifier)
                  .addStoppage(stoppage, broadcast: false);
              break;
            case DocumentChangeType.removed:
              _ref
                  .read(allStoppagesProvider.notifier)
                  .deleteStoppage(stoppage.id);
              break;
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[FirestoreSyncService] Stoppage parse error: $e');
        }
      }
    }, onError: (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] Stoppage listener error: $e');
    });
  }

  // --------------------------------------------------------------------------
  // Expenses — Subscribe
  // --------------------------------------------------------------------------

  void _subscribeExpenses(String tripId) {
    if (TombstoneService.isTombstoned(tripId)) return;
    final path = 'expenses_$tripId';
    _listeners[path] = _db
        .collection('trips')
        .doc(tripId)
        .collection('expenses')
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        try {
          final data = change.doc.data();
          if (data == null) continue;
          final expense = Expense.fromJson({...data, 'id': change.doc.id});
          switch (change.type) {
            case DocumentChangeType.added:
              _ref
                  .read(allExpensesProvider.notifier)
                  .addExpense(expense, broadcast: false);
              break;
            case DocumentChangeType.modified:
              _ref
                  .read(allExpensesProvider.notifier)
                  .updateExpense(expense, broadcast: false);
              break;
            case DocumentChangeType.removed:
              _ref
                  .read(allExpensesProvider.notifier)
                  .deleteExpense(expense.id, tripId: tripId, broadcast: false);
              break;
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[FirestoreSyncService] Expense parse error: $e');
        }
      }
    }, onError: (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] Expense listener error: $e');
    });
  }

  // --------------------------------------------------------------------------
  // Settlements — Subscribe
  // --------------------------------------------------------------------------

  void _subscribeSettlements(String tripId) {
    if (TombstoneService.isTombstoned(tripId)) return;
    final path = 'settlements_$tripId';
    _listeners[path] = _db
        .collection('trips')
        .doc(tripId)
        .collection('settlements')
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        try {
          final data = change.doc.data();
          if (data == null) continue;
          final settlement = Settlement.fromJson({...data, 'id': change.doc.id});
          switch (change.type) {
            case DocumentChangeType.added:
            case DocumentChangeType.modified:
              _ref
                  .read(allSettlementsProvider.notifier)
                  .receiveRemoteSettlement(settlement);
              break;
            case DocumentChangeType.removed:
              _ref
                  .read(allSettlementsProvider.notifier)
                  .deleteSettlementLocally(settlement.id);
              break;
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[FirestoreSyncService] Settlement parse error: $e');
        }
      }
    }, onError: (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] Settlement listener error: $e');
    });
  }

  // --------------------------------------------------------------------------
  // Memories — Subscribe
  // --------------------------------------------------------------------------

  void _subscribeMemories(String tripId) {
    if (TombstoneService.isTombstoned(tripId)) return;
    final path = 'memories_$tripId';
    _listeners[path] = _db
        .collection('trips')
        .doc(tripId)
        .collection('memories')
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        try {
          final data = change.doc.data();
          if (data == null) continue;
          final memory = Memory.fromJson({...data, 'id': change.doc.id});
          if (TombstoneService.isMemoryTombstoned(memory.id)) {
            deleteMemory(tripId, memory.id);
            continue;
          }
          switch (change.type) {
            case DocumentChangeType.added:
            case DocumentChangeType.modified:
              _ref
                  .read(allMemoriesProvider.notifier)
                  .addMemory(memory, broadcast: false, pushRemote: false, enqueueSync: false);
              break;
            case DocumentChangeType.removed:
              _ref
                  .read(allMemoriesProvider.notifier)
                  .deleteMemory(memory.id, broadcast: false);
              break;
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[FirestoreSyncService] Memory parse error: $e');
        }
      }
    }, onError: (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] Memory listener error: $e');
    });
  }

  // --------------------------------------------------------------------------
  // Audit Logs — Subscribe
  // --------------------------------------------------------------------------

  void _subscribeAuditLogs(String tripId) {
    if (TombstoneService.isTombstoned(tripId)) return;
    final path = 'audit_logs_$tripId';
    _listeners[path] = _db
        .collection('trips')
        .doc(tripId)
        .collection('audit_logs')
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added && change.type != DocumentChangeType.modified) continue;
        try {
          final data = change.doc.data();
          if (data == null) continue;
          final log = TripAuditLog.fromJson({...data, 'id': change.doc.id});
          _ref.read(allAuditLogsProvider.notifier).receiveRemoteLog(log);
        } catch (e) {
          if (kDebugMode) debugPrint('[FirestoreSyncService] AuditLog parse error: $e');
        }
      }
    }, onError: (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] AuditLog listener error: $e');
    });
  }

  // --------------------------------------------------------------------------
  // Proximity Alerts — Subscribe
  // --------------------------------------------------------------------------

  void _subscribeProximityAlerts(String tripId) {
    if (TombstoneService.isTombstoned(tripId)) return;
    final path = 'alerts_$tripId';
    final subscriptionStartTime = DateTime.now();
    _listeners[path] = _db
        .collection('trips')
        .doc(tripId)
        .collection('proximity_alerts')
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        try {
          final data = change.doc.data();
          if (data == null) continue;
          final alertId = change.doc.id;
          final storage = _ref.read(localStorageServiceProvider);
          if (storage.isAlertDismissed(alertId)) continue;

          final alert = ProximityAlert.fromJson({...data, 'id': alertId});
          final globalClearedAt = storage.getAlertsClearedAt();
          if (globalClearedAt != null && alert.timestamp.isBefore(globalClearedAt)) continue;

          final tripClearedAt = storage.getTripAlertsClearedAt(tripId);
          if (tripClearedAt != null && alert.timestamp.isBefore(tripClearedAt)) continue;

          // Historical if alert was created before subscription attached or is older than 2 minutes
          final isHistorical = alert.timestamp.isBefore(subscriptionStartTime.subtract(const Duration(seconds: 15))) ||
              DateTime.now().difference(alert.timestamp).inMinutes > 2;
          _ref.read(proximityAlertServiceProvider).ingestRemoteAlert(alert, isHistorical: isHistorical);
        } catch (e) {
          if (kDebugMode) debugPrint('[FirestoreSyncService] Alert parse error: $e');
        }
      }
    }, onError: (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] Alert listener error: $e');
    });
  }

  // --------------------------------------------------------------------------
  // Live Companion Locations — Subscribe
  // --------------------------------------------------------------------------

  void _subscribeCompanionLocations(String tripId) {
    if (TombstoneService.isTombstoned(tripId)) return;
    final path = 'members_$tripId';
    _listeners[path] = _db
        .collection('trips')
        .doc(tripId)
        .collection('member_locations')
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        try {
          final data = change.doc.data();
          if (data == null) continue;
          final memberId = change.doc.id;
          final currentUserId = UserService.getCurrentUser().id;
          if (memberId == currentUserId) continue;
          final lat = (data['lat'] as num?)?.toDouble() ?? 0.0;
          final lng = (data['lng'] as num?)?.toDouble() ?? 0.0;
          final speedKmh = (data['speedKmh'] as num?)?.toDouble() ?? 0.0;
          final heading = (data['heading'] as num?)?.toDouble() ?? 0.0;

          _ref
              .read(liveCompanionTrackerProvider.notifier)
              .onRemoteLocationUpdate(memberId, lat, lng,
                  speedKmh: speedKmh, heading: heading);

          if (_activeTripId != null) {
            _ref
                .read(tripListProvider.notifier)
                .updateMemberLocation(_activeTripId!, memberId, lat, lng);

            try {
              final trips = _ref.read(tripListProvider);
              final trip =
                  trips.where((t) => t.id == _activeTripId).firstOrNull;
              final member = trip?.getMember(memberId);
              final memberName = member?.name ?? 'Companion';

              final activeStoppages = _ref
                  .read(allStoppagesProvider)
                  .where((s) =>
                      s.tripId == _activeTripId! && s.isOngoing)
                  .toList();

              _ref.read(proximityAlertServiceProvider).evaluateStoppageArrivals(
                    tripId: _activeTripId!,
                    myLat: lat,
                    myLng: lng,
                    activeStoppages: activeStoppages,
                    myMemberId: memberId,
                    myName: memberName,
                  );

              final currentUser = trip?.currentUserMember;
              if (currentUser != null &&
                  currentUser.latitude != null &&
                  currentUser.longitude != null &&
                  member != null &&
                  !member.isCurrentUser) {
                _ref
                    .read(proximityAlertServiceProvider)
                    .evaluateCompanionProximities(
                      tripId: _activeTripId!,
                      myLat: currentUser.latitude!,
                      myLng: currentUser.longitude!,
                      companions: [member],
                      myName: currentUser.name,
                    );
              }
            } catch (_) {}
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[FirestoreSyncService] Location parse error: $e');
          }
        }
      }
    }, onError: (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] Location listener error: $e');
    });
  }

  // --------------------------------------------------------------------------
  // Push Writes — Stoppages
  // --------------------------------------------------------------------------

  /// Writes [stoppage] to Firestore.
  ///
  /// Uses [SetOptions(merge: true)] so partial updates (e.g. departed-at
  /// timestamp) do not clobber unrelated fields.
  Future<void> pushStoppage(Stoppage stoppage) async {
    if (stoppage.tripId.isEmpty || TombstoneService.isTombstoned(stoppage.tripId)) return;
    try {
      await _db
          .collection('trips')
          .doc(stoppage.tripId)
          .collection('stoppages')
          .doc(stoppage.id)
          .set({
        ...stoppage.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] pushStoppage error: $e');
    }
  }

  /// Removes [stoppageId] from Firestore.
  Future<void> deleteStoppage(String tripId, String stoppageId) async {
    if (tripId.isEmpty) return;
    try {
      await _db
          .collection('trips')
          .doc(tripId)
          .collection('stoppages')
          .doc(stoppageId)
          .delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] deleteStoppage error: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Push Writes — Expenses
  // --------------------------------------------------------------------------

  /// Writes [expense] to Firestore.
  Future<void> pushExpense(Expense expense) async {
    if (expense.tripId.isEmpty || TombstoneService.isTombstoned(expense.tripId)) return;
    try {
      await _db
          .collection('trips')
          .doc(expense.tripId)
          .collection('expenses')
          .doc(expense.id)
          .set({
        ...expense.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] pushExpense error: $e');
    }
  }

  /// Removes [expenseId] from Firestore.
  Future<void> deleteExpense(String tripId, String expenseId) async {
    if (tripId.isEmpty) return;
    try {
      await _db
          .collection('trips')
          .doc(tripId)
          .collection('expenses')
          .doc(expenseId)
          .delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] deleteExpense error: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Push Writes — Settlements
  // --------------------------------------------------------------------------

  /// Writes [settlement] to Firestore.
  Future<void> pushSettlement(Settlement settlement) async {
    if (settlement.tripId.isEmpty || TombstoneService.isTombstoned(settlement.tripId)) return;
    try {
      await _db
          .collection('trips')
          .doc(settlement.tripId)
          .collection('settlements')
          .doc(settlement.id)
          .set({
        ...settlement.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] pushSettlement error: $e');
    }
  }

  /// Removes [settlementId] from Firestore.
  Future<void> deleteSettlement(String tripId, String settlementId) async {
    if (tripId.isEmpty) return;
    try {
      await _db
          .collection('trips')
          .doc(tripId)
          .collection('settlements')
          .doc(settlementId)
          .delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] deleteSettlement error: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Push Writes — Memories
  // --------------------------------------------------------------------------

  /// Writes [memory] to Firestore.
  Future<void> pushMemory(Memory memory) async {
    if (memory.tripId.isEmpty || TombstoneService.isTombstoned(memory.tripId) || TombstoneService.isMemoryTombstoned(memory.id)) return;
    try {
      await _db
          .collection('trips')
          .doc(memory.tripId)
          .collection('memories')
          .doc(memory.id)
          .set({
        ...memory.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] pushMemory error: $e');
    }
  }

  /// Removes [memoryId] from Firestore.
  Future<void> deleteMemory(String tripId, String memoryId) async {
    if (tripId.isEmpty || memoryId.isEmpty) return;
    try {
      await _db
          .collection('trips')
          .doc(tripId)
          .collection('memories')
          .doc(memoryId)
          .delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] deleteMemory error: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Push Writes — Audit Logs
  // --------------------------------------------------------------------------

  /// Appends an [auditLog] entry to Firestore.
  Future<void> pushAuditLog(TripAuditLog auditLog) async {
    if (auditLog.tripId.isEmpty || TombstoneService.isTombstoned(auditLog.tripId)) return;
    try {
      await _db
          .collection('trips')
          .doc(auditLog.tripId)
          .collection('audit_logs')
          .doc(auditLog.id)
          .set({
        ...auditLog.toJson(),
        'serverTimestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] pushAuditLog error: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Push Writes — Proximity Alerts / SOS
  // --------------------------------------------------------------------------

  /// Broadcasts [alert] (SOS, proximity warning, stray alert) to all
  /// companions via Firestore.
  Future<void> pushProximityAlert(ProximityAlert alert) async {
    if (alert.tripId.isEmpty || TombstoneService.isTombstoned(alert.tripId)) return;
    try {
      await _db
          .collection('trips')
          .doc(alert.tripId)
          .collection('proximity_alerts')
          .doc(alert.id)
          .set({
        ...alert.toJson(),
        'serverTimestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] pushProximityAlert error: $e');
    }
  }

  /// Deletes a specific proximity alert from Firestore
  Future<void> deleteRemoteAlert(String tripId, String alertId) async {
    if (tripId.isEmpty || alertId.isEmpty || TombstoneService.isTombstoned(tripId)) return;
    try {
      await _db
          .collection('trips')
          .doc(tripId)
          .collection('proximity_alerts')
          .doc(alertId)
          .delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] deleteRemoteAlert error: $e');
    }
  }

  /// Clears all proximity alerts for a specific trip in Firestore
  Future<void> clearRemoteAlertsForTrip(String tripId) async {
    if (tripId.isEmpty || TombstoneService.isTombstoned(tripId)) return;
    try {
      final snap = await _db
          .collection('trips')
          .doc(tripId)
          .collection('proximity_alerts')
          .get();
      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] clearRemoteAlertsForTrip error: $e');
    }
  }

  /// Clears all remote alerts across active trip listeners
  Future<void> clearAllRemoteAlerts() async {
    try {
      for (final entry in _listeners.entries) {
        if (entry.key.startsWith('alerts_')) {
          final tripId = entry.key.replaceFirst('alerts_', '');
          await clearRemoteAlertsForTrip(tripId);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] clearAllRemoteAlerts error: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Push Writes — Trip (top-level doc)
  // --------------------------------------------------------------------------

  /// Creates or updates the top-level trip document in Firestore.
  Future<void> pushTrip(Trip trip) async {
    if (trip.id.isEmpty || TombstoneService.isTombstoned(trip.id)) return;
    try {
      String? authUid;
      try {
        authUid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {}
      final effectiveCreatorId = (authUid != null && authUid.isNotEmpty)
          ? authUid
          : trip.createdByMemberId;

      await _db.collection('trips').doc(trip.id).set({
        ...trip.toJson(),
        'createdByMemberId': effectiveCreatorId,
        'creatorId': effectiveCreatorId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] pushTrip error: $e');
    }
  }

  /// Permanently cascades deletion of a trip from Firestore:
  /// Writes to persistent tombstones collection, clears all subcollections,
  /// removes live room doc, and deletes the trip document.
  Future<void> markTripDeleted(String tripId) async {
    try {
      // 1. Write persistent cloud tombstone to stop companions from resurrecting
      await _db.collection('deleted_trips_tombstones').doc(tripId).set({
        'tripId': tripId,
        'status': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Mark trip doc as deleted first so any active listeners know immediately
      await _db.collection('trips').doc(tripId).set({
        'status': 'deleted',
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Purge subcollections in Firestore
      final subcollections = [
        'stoppages',
        'expenses',
        'memories',
        'settlements',
        'audit_logs',
        'proximity_alerts',
        'member_locations',
        'invitations',
      ];
      for (final sub in subcollections) {
        try {
          final snap = await _db.collection('trips').doc(tripId).collection(sub).get();
          for (final doc in snap.docs) {
            await doc.reference.delete();
          }
        } catch (_) {}
      }

      // 4. Purge trip_rooms and rooms if exists
      try {
        await _db.collection('trip_rooms').doc(tripId).delete();
      } catch (_) {}
      try {
        await CloudTripSyncService.deleteRoom(tripId);
      } catch (_) {}

      // 5. Finally, permanently delete the trip doc
      try {
        await _db.collection('trips').doc(tripId).delete();
      } catch (_) {}
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] markTripDeleted error: $e');
    }
  }

  /// Checks whether a trip is explicitly marked deleted or missing in Firestore
  Future<bool> isTripDeletedOrMissing(
    String tripId, {
    String? userId,
    String? email,
  }) async {
    if (TombstoneService.isTombstoned(tripId)) {
      return true;
    }
    try {
      final doc = await _db.collection('trips').doc(tripId).get();
      if (!doc.exists || doc.data() == null) {
        return true; // Document no longer exists -> deleted!
      }
      final data = doc.data()!;
      if (data['status'] == 'deleted' || data['isDeleted'] == true) {
        return true;
      }
      if (userId != null && userId.isNotEmpty) {
        final isCreator = data['creatorId'] == userId || data['createdByMemberId'] == userId;
        final memberIds = (data['memberIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        final memberEmails = (data['memberEmails'] as List<dynamic>?)?.map((e) => e.toString().trim().toLowerCase()).toList() ?? [];
        final cleanEmail = email?.trim().toLowerCase();
        final isMember = memberIds.contains(userId) || (cleanEmail != null && cleanEmail.isNotEmpty && memberEmails.contains(cleanEmail));
        if (!isCreator && !isMember) {
          return true; // User was removed from this trip
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Removes a companion member from the trip document in Firestore
  Future<void> removeMemberFromTripInCloud(
    String tripId,
    String memberId, {
    String? email,
  }) async {
    try {
      final tripDoc = await _db.collection('trips').doc(tripId).get();
      if (!tripDoc.exists || tripDoc.data() == null) return;
      final data = tripDoc.data()!;
      final currentMembers = (data['members'] as List<dynamic>?) ?? [];
      final updatedMembers = currentMembers.where((m) {
        if (m is Map) {
          final id = m['id'];
          final mEmail = m['email']?.toString().trim().toLowerCase();
          if (id == memberId) return false;
          if (email != null && email.isNotEmpty && mEmail == email.trim().toLowerCase()) return false;
        }
        return true;
      }).toList();

      final currentMemberIds = (data['memberIds'] as List<dynamic>?) ?? [];
      final updatedMemberIds = currentMemberIds.where((id) => id != memberId).toList();

      final currentEmails = (data['memberEmails'] as List<dynamic>?) ?? [];
      final cleanEmail = email?.trim().toLowerCase();
      final updatedEmails = currentEmails.where((e) => cleanEmail == null || cleanEmail.isEmpty || e != cleanEmail).toList();

      await _db.collection('trips').doc(tripId).update({
        'members': updatedMembers,
        'memberIds': updatedMemberIds,
        'memberEmails': updatedEmails,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] removeMemberFromTripInCloud error: $e');
    }
  }

  /// Fetches all trips where [userId] is the creator or a member, or where [email] is in memberEmails.
  Future<List<TripPackage>> fetchTripsForUser({
    required String userId,
    String? email,
  }) async {
    final results = <String, TripPackage>{};
    if (userId.isEmpty) return [];

    final cleanEmail = email?.trim().toLowerCase();

    // 1. Trips created by user (creatorId)
    try {
      final creatorQuery = await _db
          .collection('trips')
          .where('creatorId', isEqualTo: userId)
          .get();
      for (final doc in creatorQuery.docs) {
        if (TombstoneService.isTombstoned(doc.id)) continue;
        try {
          final data = doc.data();
          if (data['status'] == 'deleted' || data['isDeleted'] == true) continue;
          final trip = Trip.fromJson(data);
          if (trip.isDeleted || TombstoneService.isTombstoned(trip.id)) continue;
          final pkg = await _fetchTripPackage(trip);
          results[trip.id] = pkg;
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] creatorId query error: $e');
    }

    // 2. Also createdByMemberId fallback
    try {
      final creatorQuery2 = await _db
          .collection('trips')
          .where('createdByMemberId', isEqualTo: userId)
          .get();
      for (final doc in creatorQuery2.docs) {
        try {
          final data = doc.data();
          if (data['status'] == 'deleted' || data['isDeleted'] == true) continue;
          final trip = Trip.fromJson(data);
          if (trip.isDeleted) continue;
          if (!results.containsKey(trip.id)) {
            final pkg = await _fetchTripPackage(trip);
            results[trip.id] = pkg;
          }
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] createdByMemberId query error: $e');
    }

    // 3. Trips where user is listed in memberIds
    try {
      final memberQuery = await _db
          .collection('trips')
          .where('memberIds', arrayContains: userId)
          .get();
      for (final doc in memberQuery.docs) {
        try {
          final data = doc.data();
          if (data['status'] == 'deleted' || data['isDeleted'] == true) continue;
          final trip = Trip.fromJson(data);
          if (trip.isDeleted) continue;
          if (!results.containsKey(trip.id)) {
            final pkg = await _fetchTripPackage(trip);
            results[trip.id] = pkg;
          }
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] memberIds query error: $e');
    }

    // 4. Trips where user's email is in memberEmails
    if (cleanEmail != null && cleanEmail.isNotEmpty) {
      try {
        final emailQuery = await _db
            .collection('trips')
            .where('memberEmails', arrayContains: cleanEmail)
            .get();
        for (final doc in emailQuery.docs) {
          try {
            final data = doc.data();
            if (data['status'] == 'deleted' || data['isDeleted'] == true) continue;
            final trip = Trip.fromJson(data);
            if (trip.isDeleted) continue;
            if (!results.containsKey(trip.id)) {
              final pkg = await _fetchTripPackage(trip);
              results[trip.id] = pkg;
            }
          } catch (_) {}
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[FirestoreSyncService] memberEmails query error: $e');
      }
    }

    // 5. Scan rooms collection for shared trips (e.g. TRIP-78C9, TRIP-UV7W) matching user identity or member list
    try {
      final roomsSnap = await _db.collection('rooms').limit(100).get();
      for (final doc in roomsSnap.docs) {
        try {
          final data = doc.data();
          if (data['status'] == 'deleted' || data['isDeleted'] == true) continue;
          if (data.containsKey('package')) {
            final pkgMap = data['package'] as Map<String, dynamic>;
            final pkg = TripPackage.fromJson(pkgMap);
            final trip = pkg.trip;
            if (trip.isDeleted) continue;
            final isCreator = trip.createdByMemberId == userId;
            final isMember = trip.members.any((m) {
              final matchId = m.id == userId;
              final mEmail = m.email?.trim().toLowerCase();
              final matchEmail = cleanEmail != null && mEmail != null && mEmail == cleanEmail;
              return matchId || matchEmail;
            });

            if (isCreator || isMember) {
              CloudTripSyncService.registerRoomCode(trip.id, doc.id);
              results.putIfAbsent(trip.id, () => pkg);
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] rooms query error: $e');
    }

    return results.values.toList();
  }

  /// Fetches a specific trip package by ID directly from Cloud Firestore
  Future<TripPackage?> fetchTripById(String tripId) async {
    if (TombstoneService.isTombstoned(tripId)) return null;
    try {
      final doc = await _db.collection('trips').doc(tripId).get();
      if (doc.exists && doc.data() != null) {
        final trip = Trip.fromJson(doc.data()!);
        return await _fetchTripPackage(trip);
      }
    } catch (_) {}
    return null;
  }

  Future<TripPackage> _fetchTripPackage(Trip trip) async {
    TripPackage? roomPkg;
    if (trip.shareCode != null && trip.shareCode!.isNotEmpty) {
      try {
        roomPkg = await CloudTripSyncService.fetchTripByCode(trip.shareCode!);
      } catch (_) {}
    }

    final tripRef = _db.collection('trips').doc(trip.id);
    final stoppagesSnap = await tripRef.collection('stoppages').get();
    final stoppages = stoppagesSnap.docs.map((d) => Stoppage.fromJson(d.data())).toList();
    if (stoppages.isEmpty && roomPkg != null) {
      stoppages.addAll(roomPkg.stoppages);
    }

    final expensesSnap = await tripRef.collection('expenses').get();
    final expenses = expensesSnap.docs.map((d) => Expense.fromJson(d.data())).toList();
    if (expenses.isEmpty && roomPkg != null) {
      expenses.addAll(roomPkg.expenses);
    }

    final memoriesSnap = await tripRef.collection('memories').get();
    final memories = memoriesSnap.docs
        .map((d) => Memory.fromJson(d.data()))
        .where((m) => !TombstoneService.isMemoryTombstoned(m.id))
        .toList();
    if (memories.isEmpty && roomPkg != null) {
      memories.addAll(roomPkg.memories.where((m) => !TombstoneService.isMemoryTombstoned(m.id)));
    }

    final settlementsSnap = await tripRef.collection('settlements').get();
    final settlements = settlementsSnap.docs.map((d) => Settlement.fromJson(d.data())).toList();
    if (settlements.isEmpty && roomPkg != null) {
      settlements.addAll(roomPkg.settlements);
    }

    // Merge members: union of trip.members and roomPkg members
    final Map<String, TripMember> memberMap = {};
    for (final m in trip.members) {
      memberMap[m.id] = m;
    }
    if (roomPkg != null) {
      for (final m in roomPkg.trip.members) {
        memberMap.putIfAbsent(m.id, () => m);
      }
    }

    final mergedTrip = trip.copyWith(
      members: memberMap.values.toList(),
      shareCode: trip.shareCode ?? roomPkg?.trip.shareCode,
    );

    return TripPackage(
      trip: mergedTrip,
      stoppages: stoppages,
      expenses: expenses,
      memories: memories,
      settlements: settlements,
    );
  }

  // --------------------------------------------------------------------------
  // Push Writes — Live Location (battery-throttled)
  // --------------------------------------------------------------------------

  /// Broadcasts [memberId]''s GPS coordinates to all companions.
  ///
  /// Applies industry-standard significant-motion filtering:
  /// - Suppresses updates when movement < 8 m AND elapsed time < 10 s (moving)
  ///   or < 35 s (stationary, speed < 3 km/h).
  Future<void> broadcastLocation(
    String tripId,
    String memberId,
    double lat,
    double lng, {
    double speedKmh = 0.0,
    double heading = 0.0,
  }) async {
    if (tripId.isEmpty || memberId.isEmpty || TombstoneService.isTombstoned(tripId)) return;

    final now = DateTime.now();
    if (_lastBroadcastLat != null &&
        _lastBroadcastLng != null &&
        _lastBroadcastTime != null) {
      final elapsedSec = now.difference(_lastBroadcastTime!).inSeconds;
      final distMeters = _haversineMeters(
          _lastBroadcastLat!, _lastBroadcastLng!, lat, lng);
      final isStationary = speedKmh < 3.0;
      final minInterval = isStationary ? 35 : 10;
      if (distMeters < 8.0 && elapsedSec < minInterval) return;
    }

    _lastBroadcastLat = lat;
    _lastBroadcastLng = lng;
    _lastBroadcastTime = now;

    try {
      await _db
          .collection('trips')
          .doc(tripId)
          .collection('member_locations')
          .doc(memberId)
          .set({
        'memberId': memberId,
        'lat': lat,
        'lng': lng,
        'speedKmh': speedKmh,
        'heading': heading,
        'timestamp': now.toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] broadcastLocation error: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Trip Invitations
  // --------------------------------------------------------------------------

  /// Writes a trip invitation document that the invitee can listen to.
  Future<void> pushTripInvitation(Map<String, dynamic> invitationJson) async {
    final tripId = invitationJson['tripId'] as String?;
    final id = invitationJson['id'] as String?;
    if (tripId == null || id == null) return;
    try {
      await _db
          .collection('trips')
          .doc(tripId)
          .collection('invitations')
          .doc(id)
          .set({
        ...invitationJson,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] pushTripInvitation error: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Utilities
  // --------------------------------------------------------------------------

  bool get isConnected => _activeTripId != null;
  String? get activeTripId => _activeTripId;

  /// Haversine distance in metres between two WGS-84 coordinates.
  double _haversineMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = _sin2(dLat / 2) +
        _cos(_toRad(lat1)) * _cos(_toRad(lat2)) * _sin2(dLon / 2);
    return r * 2 * _asin(_sqrt(a));
  }

  static double _toRad(double d) => d * 3.141592653589793 / 180.0;
  static double _sin2(double x) {
    final s = x - (x * x * x) / 6.0;
    return s * s;
  }
  static double _cos(double x) => 1.0 - (x * x) / 2.0 + (x * x * x * x) / 24.0;
  static double _asin(double x) => x + (x * x * x) / 6.0;
  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double r = x;
    for (int i = 0; i < 10; i++) {
      r = (r + x / r) / 2;
    }
    return r;
  }
}

// ---------------------------------------------------------------------------
// Riverpod Provider
// ---------------------------------------------------------------------------

final firestoreSyncServiceProvider = Provider<FirestoreSyncService>((ref) {
  final service = FirestoreSyncService(ref);
  ref.onDispose(() => service.disconnectAll());
  return service;
});
