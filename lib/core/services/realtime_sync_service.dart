import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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

class RealtimeSyncService {
  final Ref ref;
  WebSocket? _socket;
  String? _connectedTripId;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _isDisposed = false;

  // Candidate hosts for WebSocket connectivity (Wi-Fi, Tailscale, Emulator, Localhost)
  static const List<String> defaultCandidates = [
    '172.20.10.11:8086',
    '100.98.130.99:8086',
    '10.0.2.2:8086',
    '127.0.0.1:8086',
  ];
  String _serverHost = '172.20.10.11:8086';

  // Throttling state for battery optimization
  double? _lastBroadcastLat;
  double? _lastBroadcastLng;
  DateTime? _lastBroadcastTime;

  RealtimeSyncService(this.ref);

  String get serverHost => _serverHost;
  bool get isConnected => _socket != null && _socket!.readyState == WebSocket.open;

  void connectTripRoom(String tripId) {
    if (_connectedTripId == tripId && _socket != null && _socket!.readyState == WebSocket.open) {
      return;
    }

    _disconnect();
    _connectedTripId = tripId;
    _establishConnection(tripId);
  }

  Future<void> _establishConnection(String tripId) async {
    if (_isDisposed) return;

    final candidates = [
      _serverHost,
      ...defaultCandidates.where((c) => c != _serverHost),
    ];

    for (final host in candidates) {
      if (_isDisposed) return;
      try {
        final wsUrl = 'ws://$host/ws/trips/$tripId';
        final socket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 3));
        _socket = socket;
        _serverHost = host;

        _subscription = _socket!.listen(
          (data) => _handleIncomingMessage(data),
          onDone: () => _scheduleReconnect(tripId),
          onError: (_) => _scheduleReconnect(tripId),
        );
        return;
      } catch (_) {
        // Try next candidate host
      }
    }

    // Gentle reconnect after delay
    _scheduleReconnect(tripId);
  }

  void _handleIncomingMessage(dynamic rawData) {
    try {
      final data = jsonDecode(rawData as String) as Map<String, dynamic>;
      final type = data['type'] as String?;
      final payload = data['payload'] as Map<String, dynamic>?;

      if (type == null || payload == null) return;

      switch (type) {
        case 'MEMBER_LOCATION_UPDATE':
          final memberId = payload['memberId'] as String;
          final lat = (payload['lat'] as num).toDouble();
          final lng = (payload['lng'] as num).toDouble();
          final speedKmh = (payload['speedKmh'] as num?)?.toDouble() ?? 0.0;
          final heading = (payload['heading'] as num?)?.toDouble() ?? 0.0;

          if (_connectedTripId != null) {
            // Update companion tracker with real live network coordinates
            ref.read(liveCompanionTrackerProvider.notifier).onRemoteLocationUpdate(
              memberId,
              lat,
              lng,
              speedKmh: speedKmh,
              heading: heading,
            );

            // Update in tripListProvider so trip state stays in sync
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
          break;

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
          ref.read(proximityAlertServiceProvider).ingestRemoteAlert(alert);
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

    _sendMessage({
      'type': 'MEMBER_LOCATION_UPDATE',
      'payload': {
        'memberId': memberId,
        'lat': lat,
        'lng': lng,
        'speedKmh': speedKmh,
        'heading': heading,
        'timestamp': now.toIso8601String(),
      },
    });
  }

  /// Broadcasts a newly tagged stoppage to all companions
  void broadcastNewStoppage(Stoppage stoppage) {
    _sendMessage({
      'type': 'STOPPAGE_ADDED',
      'payload': stoppage.toJson(),
    });
  }

  /// Broadcasts a newly logged shared bill to all companions
  void broadcastNewExpense(Expense expense) {
    _sendMessage({
      'type': 'EXPENSE_ADDED',
      'payload': expense.toJson(),
    });
  }

  /// Broadcasts a newly uploaded photo memory to all companions
  void broadcastNewMemory(Memory memory) {
    _sendMessage({
      'type': 'MEMORY_ADDED',
      'payload': memory.toJson(),
    });
  }

  /// Broadcasts an activity / audit event to all companions
  void broadcastAuditLog(TripAuditLog log) {
    _sendMessage({
      'type': 'AUDIT_LOG_ADDED',
      'payload': log.toJson(),
    });
  }

  /// Broadcasts a proximity / safety / SOS alert to all companions
  void broadcastProximityAlert(ProximityAlert alert) {
    _sendMessage({
      'type': 'PROXIMITY_ALERT',
      'payload': alert.toJson(),
    });
  }

  /// Broadcasts a trip invitation to a companion
  void broadcastTripInvitation(Map<String, dynamic> invitationJson) {
    _sendMessage({
      'type': 'TRIP_INVITATION',
      'payload': invitationJson,
    });
  }

  /// Broadcasts an invitation response (accepted or declined)
  void broadcastInvitationResponse(Map<String, dynamic> responseJson) {
    _sendMessage({
      'type': 'INVITATION_RESPONSE',
      'payload': responseJson,
    });
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (_socket != null && _socket!.readyState == WebSocket.open) {
      try {
        _socket!.add(jsonEncode(message));
      } catch (_) {}
    }
  }

  void _scheduleReconnect(String tripId) {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_connectedTripId == tripId && !_isDisposed) {
        _establishConnection(tripId);
      }
    });
  }

  void _disconnect() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _socket?.close();
    _socket = null;
  }

  void dispose() {
    _isDisposed = true;
    _disconnect();
  }
}

final realtimeSyncServiceProvider = Provider<RealtimeSyncService>((ref) {
  final service = RealtimeSyncService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
