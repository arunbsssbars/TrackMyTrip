import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/expense.dart';
import '../../models/memory.dart';
import '../../models/proximity_alert.dart';
import '../../models/stoppage.dart';
import '../../models/trip_audit_log.dart';
import '../../models/trip_invitation.dart';
import '../../providers/audit_log_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';
import 'live_companion_tracker_service.dart';
import 'proximity_alert_service.dart';

/// FirestoreSyncService — Cloud-backed real-time sync replacing the local WebSocket server.
///
/// Architecture:
///   Write path: Local SQLite (instant) → Firestore (async, retried by OfflineSyncEngine)
///   Read path:  Firestore snapshot listener → Riverpod provider update → UI rebuild
///
/// All Firestore paths follow:
///   trips/{tripId}/stoppages/{stoppageId}
///   trips/{tripId}/expenses/{expenseId}
///   trips/{tripId}/memories/{memoryId}
///   trips/{tripId}/audit_logs/{logId}
///   trips/{tripId}/proximity_alerts/{alertId}
///   trips/{tripId}/member_locations/{memberId}
class FirestoreSyncService {
  final Ref _ref;
  final FirebaseFirestore _db;

  /// Active snapshot listeners keyed by tripId
  final Map<String, List<StreamSubscription>> _tripListeners = {};

  /// Track last broadcast position for significant-motion battery throttle
  double? _lastBroadcastLat;
  double? _lastBroadcastLng;
  DateTime? _lastBroadcastTime;

  /// Track currently listened trip to avoid duplicate subscriptions
  String? _connectedTripId;

  FirestoreSyncService(this._ref) : _db = FirebaseFirestore.instance {
    // Enable Firestore offline persistence (default on mobile, explicit for clarity)
    _db.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
  }

  bool get isConnectedToTrip => _connectedTripId != null;
  String? get connectedTripId => _connectedTripId;

  // ─────────────────────────────────────────────────────────────────────────────
  // Collection References
  // ─────────────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _stoppages(String tripId) =>
      _db.collection('trips').doc(tripId).collection('stoppages');

  CollectionReference<Map<String, dynamic>> _expenses(String tripId) =>
      _db.collection('trips').doc(tripId).collection('expenses');

  CollectionReference<Map<String, dynamic>> _memories(String tripId) =>
      _db.collection('trips').doc(tripId).collection('memories');

  CollectionReference<Map<String, dynamic>> _auditLogs(String tripId) =>
      _db.collection('trips').doc(tripId).collection('audit_logs');

  CollectionReference<Map<String, dynamic>> _proximityAlerts(String tripId) =>
      _db.collection('trips').doc(tripId).collection('proximity_alerts');

  CollectionReference<Map<String, dynamic>> _memberLocations(String tripId) =>
      _db.collection('trips').doc(tripId).collection('member_locations');

  DocumentReference<Map<String, dynamic>> _tripDoc(String tripId) =>
      _db.collection('trips').doc(tripId);

  // ─────────────────────────────────────────────────────────────────────────────
  // Connect / Disconnect Trip Room
  // ─────────────────────────────────────────────────────────────────────────────

  /// Connects real-time listeners for all collections of the given trip.
  /// Safe to call multiple times — re-connects only if tripId differs.
  void connectTripRoom(String tripId) {
    if (_connectedTripId == tripId && _tripListeners.containsKey(tripId)) return;
    disconnectCurrentRoom();
    _connectedTripId = tripId;
    _attachListeners(tripId);
    if (kDebugMode) print('[FirestoreSyncService] Connected to trip room: $tripId');
  }

  /// Disconnects all active Firestore listeners.
  void disconnectCurrentRoom() {
    if (_connectedTripId != null) {
      final subs = _tripListeners.remove(_connectedTripId);
      if (subs != null) {
        for (final sub in subs) {
          sub.cancel();
        }
      }
      _connectedTripId = null;
    }
  }

  void _attachListeners(String tripId) {
    final subs = <StreamSubscription>[];

    // ── Stoppages ──────────────────────────────────────────────────────────────
    subs.add(
      _stoppages(tripId)
          .orderBy('arrivedAt', descending: false)
          .snapshots()
          .listen((snapshot) {
        for (final change in snapshot.docChanges) {
          try {
            final data = change.doc.data()!;
            final stoppage = Stoppage.fromJson(data);
            if (change.type == DocumentChangeType.added) {
              _ref.read(allStoppagesProvider.notifier).addStoppage(stoppage, broadcast: false);
            } else if (change.type == DocumentChangeType.modified) {
              _ref.read(allStoppagesProvider.notifier).updateStoppage(stoppage, broadcast: false);
            } else if (change.type == DocumentChangeType.removed) {
              _ref.read(allStoppagesProvider.notifier).deleteStoppage(stoppage.id, broadcast: false);
            }
          } catch (e) {
            if (kDebugMode) print('[FirestoreSyncService] Stoppage parse error: $e');
          }
        }
      }, onError: (e) => _onListenerError('stoppages', e)),
    );

    // ── Expenses ───────────────────────────────────────────────────────────────
    subs.add(
      _expenses(tripId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        for (final change in snapshot.docChanges) {
          try {
            final data = change.doc.data()!;
            final expense = Expense.fromJson(data);
            if (change.type == DocumentChangeType.added) {
              _ref.read(allExpensesProvider.notifier).addExpense(expense, broadcast: false);
            } else if (change.type == DocumentChangeType.modified) {
              _ref.read(allExpensesProvider.notifier).updateExpense(expense, broadcast: false);
            } else if (change.type == DocumentChangeType.removed) {
              _ref.read(allExpensesProvider.notifier).deleteExpense(expense.id, broadcast: false);
            }
          } catch (e) {
            if (kDebugMode) print('[FirestoreSyncService] Expense parse error: $e');
          }
        }
      }, onError: (e) => _onListenerError('expenses', e)),
    );

    // ── Memories ───────────────────────────────────────────────────────────────
    subs.add(
      _memories(tripId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        for (final change in snapshot.docChanges) {
          try {
            final data = change.doc.data()!;
            final memory = Memory.fromJson(data);
            if (change.type == DocumentChangeType.added) {
              _ref.read(allMemoriesProvider.notifier).addMemory(memory, broadcast: false);
            } else if (change.type == DocumentChangeType.modified) {
              _ref.read(allMemoriesProvider.notifier).updateMemory(memory, broadcast: false);
            }
          } catch (e) {
            if (kDebugMode) print('[FirestoreSyncService] Memory parse error: $e');
          }
        }
      }, onError: (e) => _onListenerError('memories', e)),
    );

    // ── Audit Logs ─────────────────────────────────────────────────────────────
    subs.add(
      _auditLogs(tripId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots()
          .listen((snapshot) {
        for (final change in snapshot.docChanges) {
          try {
            if (change.type == DocumentChangeType.added) {
              final log = TripAuditLog.fromJson(change.doc.data()!);
              _ref.read(allAuditLogsProvider.notifier).receiveRemoteLog(log);
            }
          } catch (e) {
            if (kDebugMode) print('[FirestoreSyncService] AuditLog parse error: $e');
          }
        }
      }, onError: (e) => _onListenerError('audit_logs', e)),
    );

    // ── Proximity Alerts ───────────────────────────────────────────────────────
    subs.add(
      _proximityAlerts(tripId)
          .where('isRead', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots()
          .listen((snapshot) {
        for (final change in snapshot.docChanges) {
          try {
            if (change.type == DocumentChangeType.added) {
              final alert = ProximityAlert.fromJson(change.doc.data()!);
              _ref.read(proximityAlertServiceProvider).ingestRemoteAlert(alert);
            }
          } catch (e) {
            if (kDebugMode) print('[FirestoreSyncService] ProximityAlert parse error: $e');
          }
        }
      }, onError: (e) => _onListenerError('proximity_alerts', e)),
    );

    // ── Member Locations ───────────────────────────────────────────────────────
    subs.add(
      _memberLocations(tripId).snapshots().listen((snapshot) {
        for (final change in snapshot.docChanges) {
          try {
            final data = change.doc.data()!;
            final memberId = change.doc.id;
            final lat = (data['lat'] as num).toDouble();
            final lng = (data['lng'] as num).toDouble();
            final speedKmh = (data['speedKmh'] as num?)?.toDouble() ?? 0.0;
            final heading = (data['heading'] as num?)?.toDouble() ?? 0.0;

            _ref.read(liveCompanionTrackerProvider.notifier).onRemoteLocationUpdate(
              memberId, lat, lng, speedKmh: speedKmh, heading: heading,
            );
            _ref.read(tripListProvider.notifier).updateMemberLocation(tripId, memberId, lat, lng);

            // Evaluate proximity safety alerts
            try {
              final trips = _ref.read(tripListProvider);
              final trip = trips.where((t) => t.id == tripId).firstOrNull;
              final member = trip?.getMember(memberId);
              final memberName = member?.name ?? 'Companion';

              final activeStoppages = _ref.read(allStoppagesProvider)
                  .where((s) => s.tripId == tripId && s.isOngoing)
                  .toList();
              _ref.read(proximityAlertServiceProvider).evaluateStoppageArrivals(
                tripId: tripId, myLat: lat, myLng: lng,
                activeStoppages: activeStoppages,
                myMemberId: memberId, myName: memberName,
              );

              final currentUser = trip?.currentUserMember;
              if (currentUser != null && currentUser.latitude != null &&
                  currentUser.longitude != null && member != null && !member.isCurrentUser) {
                _ref.read(proximityAlertServiceProvider).evaluateCompanionProximities(
                  tripId: tripId, myLat: currentUser.latitude!,
                  myLng: currentUser.longitude!, companions: [member],
                  myName: currentUser.name,
                );
              }
            } catch (_) {}
          } catch (e) {
            if (kDebugMode) print('[FirestoreSyncService] MemberLocation parse error: $e');
          }
        }
      }, onError: (e) => _onListenerError('member_locations', e)),
    );

    _tripListeners[tripId] = subs;
  }

  void _onListenerError(String collection, dynamic error) {
    if (kDebugMode) print('[FirestoreSyncService] $collection listener error: $error');
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Write Methods — Called after local SQLite write for cloud propagation
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> publishStoppage(Stoppage stoppage) async {
    try {
      await _stoppages(stoppage.tripId).doc(stoppage.id).set(
        _withServerTimestamp(stoppage.toJson()),
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) print('[FirestoreSyncService] publishStoppage error: $e');
    }
  }

  Future<void> deleteStoppage(String tripId, String stoppageId) async {
    try {
      await _stoppages(tripId).doc(stoppageId).delete();
    } catch (e) {
      if (kDebugMode) print('[FirestoreSyncService] deleteStoppage error: $e');
    }
  }

  Future<void> publishExpense(Expense expense) async {
    try {
      await _expenses(expense.tripId).doc(expense.id).set(
        _withServerTimestamp(expense.toJson()),
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) print('[FirestoreSyncService] publishExpense error: $e');
    }
  }

  Future<void> deleteExpense(String tripId, String expenseId) async {
    try {
      await _expenses(tripId).doc(expenseId).delete();
    } catch (e) {
      if (kDebugMode) print('[FirestoreSyncService] deleteExpense error: $e');
    }
  }

  Future<void> publishMemory(Memory memory) async {
    try {
      await _memories(memory.tripId).doc(memory.id).set(
        _withServerTimestamp(memory.toJson()),
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) print('[FirestoreSyncService] publishMemory error: $e');
    }
  }

  Future<void> publishAuditLog(TripAuditLog log) async {
    try {
      await _auditLogs(log.tripId).doc(log.id).set(log.toJson());
    } catch (e) {
      if (kDebugMode) print('[FirestoreSyncService] publishAuditLog error: $e');
    }
  }

  Future<void> publishProximityAlert(ProximityAlert alert) async {
    try {
      await _proximityAlerts(alert.tripId).doc(alert.id).set(alert.toJson());
    } catch (e) {
      if (kDebugMode) print('[FirestoreSyncService] publishProximityAlert error: $e');
    }
  }

  Future<void> publishTripInvitation(TripInvitation invitation) async {
    try {
      await _db
          .collection('invitations')
          .doc(invitation.id)
          .set(invitation.toJson(), SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print('[FirestoreSyncService] publishInvitation error: $e');
    }
  }

  /// Publishes a trip metadata document to Firestore.
  Future<void> publishTripMeta({
    required String tripId,
    required String title,
    required String shareCode,
    required List<String> memberIds,
  }) async {
    try {
      await _tripDoc(tripId).set({
        'id': tripId,
        'title': title,
        'shareCode': shareCode,
        'memberIds': memberIds,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print('[FirestoreSyncService] publishTripMeta error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Live Location Broadcast (throttled for battery savings)
  // ─────────────────────────────────────────────────────────────────────────────

  /// Broadcasts member location to Firestore with significant-motion throttle.
  /// Only transmits if user moved >= 8m OR >= 10s (35s if stationary).
  Future<void> broadcastLocation(
    String tripId,
    String memberId,
    double lat,
    double lng, {
    double speedKmh = 0.0,
    double heading = 0.0,
  }) async {
    final now = DateTime.now();

    // Significant-motion filter (industry standard battery optimization)
    if (_lastBroadcastLat != null && _lastBroadcastLng != null && _lastBroadcastTime != null) {
      final elapsedSec = now.difference(_lastBroadcastTime!).inSeconds;
      final distMeters = Geolocator.distanceBetween(
          _lastBroadcastLat!, _lastBroadcastLng!, lat, lng);
      final isStationary = speedKmh < 3.0;
      final minIntervalSec = isStationary ? 35 : 10;

      if (distMeters < 8.0 && elapsedSec < minIntervalSec) return;
    }

    _lastBroadcastLat = lat;
    _lastBroadcastLng = lng;
    _lastBroadcastTime = now;

    try {
      await _memberLocations(tripId).doc(memberId).set({
        'memberId': memberId,
        'lat': lat,
        'lng': lng,
        'speedKmh': speedKmh,
        'heading': heading,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) print('[FirestoreSyncService] broadcastLocation error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────────

  Map<String, dynamic> _withServerTimestamp(Map<String, dynamic> data) {
    return {...data, 'updatedAt': FieldValue.serverTimestamp()};
  }

  void dispose() {
    for (final subs in _tripListeners.values) {
      for (final sub in subs) {
        sub.cancel();
      }
    }
    _tripListeners.clear();
    _connectedTripId = null;
  }
}

final firestoreSyncServiceProvider = Provider<FirestoreSyncService>((ref) {
  final service = FirestoreSyncService(ref);
  ref.onDispose(service.dispose);
  return service;
});
