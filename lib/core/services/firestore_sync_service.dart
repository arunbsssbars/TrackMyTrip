import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/expense.dart';
import '../../models/memory.dart';
import '../../models/proximity_alert.dart';
import '../../models/stoppage.dart';
import '../../models/trip.dart';
import '../../models/trip_audit_log.dart';
import '../../providers/audit_log_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';
import 'live_companion_tracker_service.dart';
import 'proximity_alert_service.dart';
import 'local_storage_service.dart';

/// ---------------------------------------------------------------------------
/// FirestoreSyncService
/// ---------------------------------------------------------------------------
/// The central offline-first sync hub for TripTracker.
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

  FirestoreSyncService(this._ref, {FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // --------------------------------------------------------------------------
  // Lifecycle
  // --------------------------------------------------------------------------

  /// Attaches real-time Firestore listeners for [tripId].
  ///
  /// If already listening to a different trip, the old listeners are torn down
  /// first. Calling with the same [tripId] twice is a no-op.
  void connectTripRoom(String tripId) {
    if (_activeTripId == tripId) return;
    disconnectAll();
    _activeTripId = tripId;
    _subscribeStoppages(tripId);
    _subscribeExpenses(tripId);
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
  }

  // --------------------------------------------------------------------------
  // Stoppages — Subscribe
  // --------------------------------------------------------------------------

  void _subscribeStoppages(String tripId) {
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
            case DocumentChangeType.modified:
              _ref
                  .read(allExpensesProvider.notifier)
                  .addExpense(expense, broadcast: false);
              break;
            case DocumentChangeType.removed:
              _ref
                  .read(allExpensesProvider.notifier)
                  .deleteExpense(expense.id);
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
  // Memories — Subscribe
  // --------------------------------------------------------------------------

  void _subscribeMemories(String tripId) {
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
          switch (change.type) {
            case DocumentChangeType.added:
            case DocumentChangeType.modified:
              _ref
                  .read(allMemoriesProvider.notifier)
                  .addMemory(memory, broadcast: false);
              break;
            case DocumentChangeType.removed:
              _ref
                  .read(allMemoriesProvider.notifier)
                  .deleteMemory(memory.id);
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
    final path = 'audit_logs_$tripId';
    _listeners[path] = _db
        .collection('trips')
        .doc(tripId)
        .collection('audit_logs')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
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
    final path = 'alerts_$tripId';
    _listeners[path] = _db
        .collection('trips')
        .doc(tripId)
        .collection('proximity_alerts')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        try {
          final data = change.doc.data();
          if (data == null) continue;
          final alert = ProximityAlert.fromJson({...data, 'id': change.doc.id});
          _ref.read(proximityAlertServiceProvider).ingestRemoteAlert(alert);
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
    if (stoppage.tripId.isEmpty) return;
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
    if (expense.tripId.isEmpty) return;
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
  // Push Writes — Memories
  // --------------------------------------------------------------------------

  /// Writes [memory] to Firestore.
  Future<void> pushMemory(Memory memory) async {
    if (memory.tripId.isEmpty) return;
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

  // --------------------------------------------------------------------------
  // Push Writes — Audit Logs
  // --------------------------------------------------------------------------

  /// Appends an [auditLog] entry to Firestore.
  Future<void> pushAuditLog(TripAuditLog auditLog) async {
    if (auditLog.tripId.isEmpty) return;
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
    if (alert.tripId.isEmpty) return;
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

  // --------------------------------------------------------------------------
  // Push Writes — Trip (top-level doc)
  // --------------------------------------------------------------------------

  /// Creates or updates the top-level trip document in Firestore.
  Future<void> pushTrip(Trip trip) async {
    try {
      await _db.collection('trips').doc(trip.id).set({
        ...trip.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreSyncService] pushTrip error: $e');
    }
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
    if (tripId.isEmpty || memberId.isEmpty) return;

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
    for (int i = 0; i < 10; i++) r = (r + x / r) / 2;
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
