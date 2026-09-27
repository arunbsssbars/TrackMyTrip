import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/stoppage.dart';
import '../../models/expense.dart';
import '../../providers/trip_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/expense_provider.dart';
import '../../models/memory.dart';
import '../../providers/memory_provider.dart';
import '../../models/trip_audit_log.dart';
import '../../providers/audit_log_provider.dart';
import '../../models/proximity_alert.dart';
import 'live_companion_tracker_service.dart';
import 'proximity_alert_service.dart';
import 'user_service.dart';

class RealtimeSyncService {
  final Ref ref;
  String? _connectedTripId;
  StreamSubscription<DatabaseEvent>? _subscription;
  StreamSubscription<DatabaseEvent>? _locationSubscription;
  bool _isDisposed = false;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Throttling state for battery optimization
  double? _lastBroadcastLat;
  double? _lastBroadcastLng;
  DateTime? _lastBroadcastTime;

  RealtimeSyncService(this.ref);

  void connectTripRoom(String tripId) {
    if (_connectedTripId == tripId) return;

    disconnect();
    _connectedTripId = tripId;
    _establishConnection(tripId);
  }

  void _establishConnection(String tripId) {
    if (_isDisposed) return;

    final tripRef = _database.ref('trips/$tripId/events');

    _subscription = tripRef.onChildAdded.listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        _handleIncomingMessage(data);
      }
    });
    
    // Listen for live location updates specifically
    _locationSubscription = _database.ref('trips/$tripId/locations').onValue.listen((event) {
        if (event.snapshot.value != null) {
           final data = Map<String, dynamic>.from(event.snapshot.value as Map);
           data.forEach((memberId, locationData) {
              final locMap = Map<String, dynamic>.from(locationData as Map);
              final lat = (locMap['lat'] as num).toDouble();
              final lng = (locMap['lng'] as num).toDouble();
              final speedKmh = (locMap['speedKmh'] as num?)?.toDouble() ?? 0.0;
              final heading = (locMap['heading'] as num?)?.toDouble() ?? 0.0;
              
              _processLocationUpdate(memberId, lat, lng, speedKmh, heading);
           });
        }
    });
  }

  void _processLocationUpdate(String memberId, double lat, double lng, double speedKmh, double heading) {
     final currentUserId = UserService.getCurrentUser().id;
     if (memberId == currentUserId) return;

     if (_connectedTripId != null) {
        ref.read(liveCompanionTrackerProvider.notifier).onRemoteLocationUpdate(
          memberId,
          lat,
          lng,
          speedKmh: speedKmh,
          heading: heading,
        );

        ref.read(tripListProvider.notifier).updateMemberLocation(_connectedTripId!, memberId, lat, lng);

        try {
          final trips = ref.read(tripListProvider);
          final trip = trips.where((t) => t.id == _connectedTripId).firstOrNull;
          final member = trip?.getMember(memberId);
          final memberName = member?.name ?? 'Companion';

          final activeStoppages = ref.read(allStoppagesProvider).where((s) => s.tripId == _connectedTripId! && s.isOngoing).toList();
          ref.read(proximityAlertServiceProvider).evaluateStoppageArrivals(
            tripId: _connectedTripId!,
            myLat: lat,
            myLng: lng,
            activeStoppages: activeStoppages,
            myMemberId: memberId,
            myName: memberName,
          );

          final currentUser = trip?.currentUserMember;
          if (currentUser != null && currentUser.latitude != null && currentUser.longitude != null && member != null && !member.isCurrentUser) {
            ref.read(proximityAlertServiceProvider).evaluateCompanionProximities(
              tripId: _connectedTripId!,
              myLat: currentUser.latitude!,
              myLng: currentUser.longitude!,
              companions: [member],
              myName: currentUser.name,
            );
          }
        } catch (_) {}
      }
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    try {
      final type = data['type'] as String?;
      final payload = Map<String, dynamic>.from(data['payload'] as Map);

      if (type == null) return;

      // DATA ISOLATION GUARD: Verify that the current user actually belongs to this trip
      final tripId = payload['tripId'] as String?;
      if (tripId != null) {
        final userTrips = ref.read(tripListProvider);
        if (!userTrips.any((t) => t.id == tripId)) {
          return; // Ignore foreign trip events
        }
      }

      switch (type) {
        case 'STOPPAGE_ADDED':
          final stoppage = Stoppage.fromJson(payload);
          ref.read(allStoppagesProvider.notifier).addStoppage(stoppage, broadcast: false);
          break;
        case 'EXPENSE_ADDED':
          final expense = Expense.fromJson(payload);
          ref.read(allExpensesProvider.notifier).addExpense(expense, broadcast: false);
          break;
        case 'MEMORY_ADDED':
          final memory = Memory.fromJson(payload);
          ref.read(allMemoriesProvider.notifier).addMemory(memory, broadcast: false);
          break;
        case 'AUDIT_LOG_ADDED':
          final auditLog = TripAuditLog.fromJson(payload);
          ref.read(allAuditLogsProvider.notifier).receiveRemoteLog(auditLog);
          break;
        case 'PROXIMITY_ALERT':
          final alert = ProximityAlert.fromJson(payload);
          final bool isStaleOrOld = alert.timestamp.isBefore(DateTime.now().subtract(const Duration(seconds: 45)));
          ref.read(proximityAlertServiceProvider).ingestRemoteAlert(alert, isHistorical: isStaleOrOld);
          break;
        case 'TRIP_DELETED':
          final deletedTripId = payload['tripId'] as String?;
          if (deletedTripId != null) {
            disconnect();
            ref.read(tripListProvider.notifier).deleteTripLocally(deletedTripId);
          }
          break;
        case 'MEMBER_LEFT':
          final targetTripId = payload['tripId'] as String?;
          final memberId = payload['memberId'] as String?;
          if (targetTripId != null && memberId != null) {
            ref.read(tripListProvider.notifier).removeMemberFromTrip(targetTripId, memberId);
          }
          break;
      }
    } catch (_) {}
  }

  /// Broadcasts your live location to all companions in the trip with battery-saving throttling
  void broadcastLocation(
    String memberId,
    double lat,
    double lng, {
    double speedKmh = 0.0,
    double heading = 0.0,
  }) {
    if (_connectedTripId == null) return;
    
    final now = DateTime.now();

    // Battery & Radio Throttling (Industry Standard Significant Motion Filter):
    // Only broadcast if user moved >= 8 meters, OR time elapsed >= 10s (or 35s if stationary)
    if (_lastBroadcastLat != null && _lastBroadcastLng != null && _lastBroadcastTime != null) {
      final elapsedSec = now.difference(_lastBroadcastTime!).inSeconds;
      final distMeters = Geolocator.distanceBetween(_lastBroadcastLat!, _lastBroadcastLng!, lat, lng);
      final isStationary = speedKmh < 3.0;
      final minIntervalSec = isStationary ? 35 : 10;

      if (distMeters < 8.0 && elapsedSec < minIntervalSec) {
        return; // Suppress redundant radio transmission to preserve phone battery
      }
    }

    _lastBroadcastLat = lat;
    _lastBroadcastLng = lng;
    _lastBroadcastTime = now;

    _database.ref('trips/$_connectedTripId/locations/$memberId').set({
      'lat': lat,
      'lng': lng,
      'speedKmh': speedKmh,
      'heading': heading,
      'timestamp': now.toIso8601String(),
    });
  }

  void broadcastNewStoppage(Stoppage stoppage) {
    _sendMessage({
      'type': 'STOPPAGE_ADDED',
      'payload': stoppage.toJson(),
    });
  }

  void broadcastNewExpense(Expense expense) {
    _sendMessage({
      'type': 'EXPENSE_ADDED',
      'payload': expense.toJson(),
    });
  }

  void broadcastNewMemory(Memory memory) {
    _sendMessage({
      'type': 'MEMORY_ADDED',
      'payload': memory.toJson(),
    });
  }

  void broadcastAuditLog(TripAuditLog log) {
    _sendMessage({
      'type': 'AUDIT_LOG_ADDED',
      'payload': log.toJson(),
    });
  }

  void broadcastProximityAlert(ProximityAlert alert) {
    _sendMessage({
      'type': 'PROXIMITY_ALERT',
      'payload': alert.toJson(),
    });
  }

  void broadcastTripInvitation(Map<String, dynamic> invitationJson) {
    _sendMessage({
      'type': 'TRIP_INVITATION',
      'payload': invitationJson,
    });
  }

  void broadcastInvitationResponse(Map<String, dynamic> responseJson) {
    _sendMessage({
      'type': 'INVITATION_RESPONSE',
      'payload': responseJson,
    });
  }

  void broadcastTripDeleted(String tripId) {
    _sendMessage({
      'type': 'TRIP_DELETED',
      'payload': {'tripId': tripId},
    });
  }

  void broadcastMemberLeft(String tripId, String memberId, String memberName) {
    _sendMessage({
      'type': 'MEMBER_LEFT',
      'payload': {
        'tripId': tripId,
        'memberId': memberId,
        'memberName': memberName,
      },
    });
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (_connectedTripId != null && !_isDisposed) {
      _database.ref('trips/$_connectedTripId/events').push().set(message);
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _connectedTripId = null;
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
  }
}

final realtimeSyncServiceProvider = Provider<RealtimeSyncService>((ref) {
  final service = RealtimeSyncService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
