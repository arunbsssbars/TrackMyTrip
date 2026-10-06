import 'dart:async';
import 'dart:io' show Platform;
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
import 'tombstone_service.dart';

class RealtimeSyncService {
  final Ref ref;
  String? _connectedTripId;
  StreamSubscription<DatabaseEvent>? _subscription;
  StreamSubscription<DatabaseEvent>? _locationSubscription;
  StreamSubscription<DatabaseEvent>? _presenceSubscription;
  StreamSubscription<DatabaseEvent>? _sosSubscription;
  StreamSubscription<DatabaseEvent>? _wakeQueueSubscription;
  StreamSubscription<DatabaseEvent>? _connectionStatusSubscription;
  StreamSubscription<DatabaseEvent>? _nudgeSubscription;
  StreamSubscription<DatabaseEvent>? _memoryActivitySubscription;
  bool _isDisposed = false;
  
  FirebaseDatabase? _databaseInstance;
  FirebaseDatabase? get _database {
    if (_databaseInstance != null) return _databaseInstance;
    try {
      _databaseInstance = FirebaseDatabase.instance;
      return _databaseInstance;
    } catch (_) {
      return null;
    }
  }

  String? _lastRegisteredToken;

  // Throttling state for battery optimization
  double? _lastBroadcastLat;
  double? _lastBroadcastLng;
  DateTime? _lastBroadcastTime;

  RealtimeSyncService(this.ref) {
    _initConnectionListener();
  }

  void _initConnectionListener() {
    final db = _database;
    if (db == null) return;
    try {
      _connectionStatusSubscription = db.ref('.info/connected').onValue.listen((event) {
        final isConnected = event.snapshot.value == true;
        if (isConnected && !_isDisposed) {
          _onReconnected();
        }
      });
    } catch (_) {}
  }

  void _onReconnected() {
    final currentUserId = UserService.getCurrentUser().id;
    if (currentUserId.isNotEmpty) {
      if (_connectedTripId != null) {
        final db = _database;
        if (db != null) {
          try {
            final myPresenceRef = db.ref('trips/$_connectedTripId/presence/$currentUserId');
            myPresenceRef.onDisconnect().set({
              'status': 'offline',
              'lastSeen': ServerValue.timestamp,
            });
            myPresenceRef.set({
              'status': 'online',
              'lastSeen': ServerValue.timestamp,
            });
          } catch (_) {}
        }
      }
      if (_lastRegisteredToken != null) {
        registerFcmTokenInRtdb(currentUserId, _lastRegisteredToken!);
      }
    }
  }

  void connectTripRoom(String tripId) {
    if (_connectedTripId == tripId) return;

    disconnect();
    _connectedTripId = tripId;
    _establishConnection(tripId);
  }

  void _establishConnection(String tripId) {
    if (_isDisposed) return;
    final db = _database;
    if (db == null) return;

    final tripRef = db.ref('trips/$tripId/events');

    _subscription = tripRef.onChildAdded.listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        _handleIncomingMessage(data);
      }
    });
    
    // Listen for live location updates specifically
    _locationSubscription = db.ref('trips/$tripId/locations').onValue.listen((event) {
        if (event.snapshot.value != null) {
           final data = Map<String, dynamic>.from(event.snapshot.value as Map);
           data.forEach((memberId, locationData) {
              final locMap = Map<String, dynamic>.from(locationData as Map);
              final lat = (locMap['lat'] as num).toDouble();
              final lng = (locMap['lng'] as num).toDouble();
              final speedKmh = (locMap['speedKmh'] as num?)?.toDouble() ?? 0.0;
              final heading = (locMap['heading'] as num?)?.toDouble() ?? 0.0;
              final batteryLevel = (locMap['battery'] as num?)?.toInt();
              final isCharging = locMap['isCharging'] as bool?;
              
              _processLocationUpdate(
                memberId,
                lat,
                lng,
                speedKmh,
                heading,
                batteryLevel: batteryLevel,
                isCharging: isCharging,
              );
           });
        }
    });

    // 1. RTDB Presence: Register onDisconnect and mark current user online
    final currentUserId = UserService.getCurrentUser().id;
    if (currentUserId.isNotEmpty) {
      try {
        final myPresenceRef = db.ref('trips/$tripId/presence/$currentUserId');
        myPresenceRef.onDisconnect().set({
          'status': 'offline',
          'lastSeen': ServerValue.timestamp,
        });
        myPresenceRef.set({
          'status': 'online',
          'lastSeen': ServerValue.timestamp,
        });
      } catch (_) {}
    }

    // 2. RTDB Presence: Listen for companion online/offline status in real time
    _presenceSubscription = db.ref('trips/$tripId/presence').onValue.listen((event) {
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        data.forEach((memberId, presenceVal) {
          if (presenceVal is Map) {
            final isOnline = presenceVal['status'] == 'online';
            ref.read(liveCompanionTrackerProvider.notifier).updateCompanionOnlineStatus(memberId, isOnline);
          }
        });
      }
    });

    // 3. RTDB Active SOS Latch: Guarantees newly entering companions immediately catch ongoing emergencies
    _sosSubscription = db.ref('trips/$tripId/active_sos').onValue.listen((event) {
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        data.forEach((_, alertData) {
          if (alertData is Map) {
            try {
              final alert = ProximityAlert.fromJson(Map<String, dynamic>.from(alertData));
              ref.read(proximityAlertServiceProvider).ingestRemoteAlert(alert);
            } catch (_) {}
          }
        });
      }
    });

    // 4. RTDB Nudge listener: Hands-free convoy ping
    if (currentUserId.isNotEmpty) {
      _nudgeSubscription = db.ref('trips/$tripId/nudges/$currentUserId').onValue.listen((event) {
        if (event.snapshot.value != null && event.snapshot.value is Map) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          final senderName = data['senderName']?.toString() ?? 'A companion';
          final ts = data['timestamp'];
          if (ts is int && DateTime.now().millisecondsSinceEpoch - ts < 15000) {
            ref.read(proximityAlertServiceProvider).ingestRemoteAlert(
              ProximityAlert(
                id: 'nudge_${DateTime.now().millisecondsSinceEpoch}',
                tripId: tripId,
                title: 'Convoy Nudge',
                message: '$senderName is pinging you!',
                type: AlertType.general,
                senderMemberId: currentUserId,
                senderName: senderName,
                timestamp: DateTime.now(),
              ),
            );
          }
          db.ref('trips/$tripId/nudges/$currentUserId').remove();
        }
      });
    }

    // 5. RTDB Live Memory Activity: Informs companions when someone is uploading/sharing a photo
    _memoryActivitySubscription = db.ref('trips/$tripId/memory_activity').onValue.listen((event) {
      final currentUserId = UserService.getCurrentUser().id;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final List<String> uploaders = [];
        data.forEach((memId, val) {
          if (memId != currentUserId && val is Map) {
            // Guard with 45-second TTL so stale activities never show forever
            final timestamp = val['timestamp'];
            if (timestamp is int && (now - timestamp) > 45000) {
              try {
                db.ref('trips/$tripId/memory_activity/$memId').remove();
              } catch (_) {}
              return;
            }
            final name = val['name']?.toString() ?? val['memberName']?.toString();
            if (name != null && name.isNotEmpty && !uploaders.contains(name)) {
              uploaders.add(name);
            }
          }
        });
        ref.read(activeMemoryUploadersProvider(tripId).notifier).state = uploaders;
      } else {
        ref.read(activeMemoryUploadersProvider(tripId).notifier).state = [];
      }
    });
  }

  void _processLocationUpdate(
    String memberId,
    double lat,
    double lng,
    double speedKmh,
    double heading, {
    int? batteryLevel,
    bool? isCharging,
  }) {
     final currentUserId = UserService.getCurrentUser().id;
     if (memberId == currentUserId) return;

     if (_connectedTripId != null) {
        ref.read(liveCompanionTrackerProvider.notifier).onRemoteLocationUpdate(
          memberId,
          lat,
          lng,
          speedKmh: speedKmh,
          heading: heading,
          batteryLevel: batteryLevel,
          isCharging: isCharging,
        );

        ref.read(tripListProvider.notifier).updateMemberLocation(_connectedTripId!, memberId, lat, lng);

        try {
          final trips = ref.read(tripListProvider);
          final trip = trips.where((t) => t.id == _connectedTripId).firstOrNull;
          final member = trip?.getMember(memberId);
          final memberName = member?.name ?? 'Companion';

          // Proactive battery warning if companion battery drops <= 15% and not charging
          if (batteryLevel != null && batteryLevel <= 15 && isCharging != true) {
            ref.read(proximityAlertServiceProvider).evaluateBatteryWarning(
              tripId: _connectedTripId!,
              memberId: memberId,
              memberName: memberName,
              batteryLevel: batteryLevel,
            );
          }

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
        case 'STOPPAGE_UPDATED':
          final stoppage = Stoppage.fromJson(payload);
          ref.read(allStoppagesProvider.notifier).updateStoppage(stoppage, broadcast: false);
          break;
        case 'STOPPAGE_DELETED':
          final stoppageId = payload['stoppageId'] as String?;
          if (stoppageId != null) {
            ref.read(allStoppagesProvider.notifier).deleteStoppage(stoppageId, broadcast: false);
          }
          break;
        case 'EXPENSE_ADDED':
          final expense = Expense.fromJson(payload);
          ref.read(allExpensesProvider.notifier).addExpense(expense, broadcast: false);
          break;
        case 'MEMORY_ADDED':
          final memory = Memory.fromJson(payload);
          if (!TombstoneService.isMemoryTombstoned(memory.id)) {
            ref.read(allMemoriesProvider.notifier).addMemory(memory, broadcast: false);
          }
          break;
        case 'MEMORY_DELETED':
          final memoryId = payload['memoryId'] as String?;
          if (memoryId != null) {
            TombstoneService.markMemoryTombstoned(memoryId);
            ref.read(allMemoriesProvider.notifier).deleteMemory(memoryId, broadcast: false);
          }
          break;
        case 'MEMORY_LIKED':
          final memoryId = payload['memoryId'] as String?;
          final memberId = payload['memberId'] as String?;
          final isLiked = payload['isLiked'] as bool?;
          if (memoryId != null && memberId != null && isLiked != null) {
            ref.read(allMemoriesProvider.notifier).receiveRemoteLike(memoryId, memberId, isLiked);
          }
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
            ref.read(tripListProvider.notifier).archiveTripByCreator(deletedTripId);
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
    int? batteryLevel,
    bool? isCharging,
  }) {
    if (_connectedTripId == null) return;
    final db = _database;
    if (db == null) return;
    
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

    final Map<String, dynamic> locPayload = {
      'lat': lat,
      'lng': lng,
      'speedKmh': speedKmh,
      'heading': heading,
      'timestamp': now.toIso8601String(),
    };
    if (batteryLevel != null) locPayload['battery'] = batteryLevel;
    if (isCharging != null) locPayload['isCharging'] = isCharging;

    db.ref('trips/$_connectedTripId/locations/$memberId').set(locPayload);
  }

  /// Sends a zero-cost convoy nudge chime to a companion
  void nudgeCompanion(String tripId, String targetMemberId, String senderName) {
    final db = _database;
    if (db == null || tripId.isEmpty || targetMemberId.isEmpty) return;
    db.ref('trips/$tripId/nudges/$targetMemberId').set({
      'senderName': senderName,
      'timestamp': ServerValue.timestamp,
    });
  }

  void broadcastNewStoppage(Stoppage stoppage) {
    _sendMessage({
      'type': 'STOPPAGE_ADDED',
      'payload': stoppage.toJson(),
    });
  }

  void broadcastUpdateStoppage(Stoppage stoppage) {
    _sendMessage({
      'type': 'STOPPAGE_UPDATED',
      'payload': stoppage.toJson(),
    });
  }

  void broadcastDeleteStoppage(String tripId, String stoppageId) {
    _sendMessage({
      'type': 'STOPPAGE_DELETED',
      'payload': {
        'tripId': _connectedTripId ?? tripId,
        'stoppageId': stoppageId,
      },
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

    // Latch SOS in RTDB so companions entering later catch it immediately
    if (alert.type == AlertType.sosEmergency && _connectedTripId != null) {
      final db = _database;
      if (db != null) {
        db.ref('trips/$_connectedTripId/active_sos/${alert.senderMemberId}').set(alert.toJson());
      }
    }
  }

  void resolveActiveSos(String tripId, String memberId) {
    final db = _database;
    if (db != null) {
      db.ref('trips/$tripId/active_sos/$memberId').remove();
    }
  }

  // ---------------------------------------------------------------------------
  // IMPROVEMENT 1 — FCM Token Freshness (RTDB + onDisconnect auto-invalidation)
  // ---------------------------------------------------------------------------

  /// Registers the FCM token in RTDB at `users/{uid}/fcmMeta`.
  ///
  /// Configures an `onDisconnect` hook so the Firebase server automatically
  /// marks `tokenValid: false` when the client socket drops (crash, battery death,
  /// network loss). On re-connect the client writes `tokenValid: true` again.
  /// This eliminates silent FCM delivery failures caused by stale tokens.
  Future<void> registerFcmTokenInRtdb(String uid, String token) async {
    if (uid.isEmpty || token.isEmpty) return;
    _lastRegisteredToken = token;
    final db = _database;
    if (db == null) return;
    final metaRef = db.ref('users/$uid/fcmMeta');
    try {
      // Server auto-invalidates token on ungraceful disconnect
      await metaRef.onDisconnect().update({'tokenValid': false});
      await metaRef.set({
        'token': token,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'tokenValid': true,
        'registeredAt': ServerValue.timestamp,
      });
    } catch (_) {}
  }

  /// Removes the RTDB token entry on clean logout or account deletion.
  Future<void> unregisterFcmTokenInRtdb(String uid) async {
    if (uid.isEmpty) return;
    _lastRegisteredToken = null;
    final db = _database;
    if (db == null) return;
    try {
      await db.ref('users/$uid/fcmMeta').remove();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // IMPROVEMENT 2 — Delivery ACK (client-side notification receipt)
  // ---------------------------------------------------------------------------

  /// Writes a delivery receipt to `users/{uid}/notif_ack/{msgId}` when a
  /// notification is displayed. Enables the SOS sender to show a live
  /// "X/N companions notified" counter without any Cloud Functions.
  Future<void> ackNotification({
    required String myUid,
    required String msgId,
    required String type,
    required String tripId,
  }) async {
    if (myUid.isEmpty || msgId.isEmpty) return;
    final db = _database;
    if (db == null) return;
    try {
      await db.ref('users/$myUid/notif_ack/$msgId').set({
        'receivedAt': ServerValue.timestamp,
        'type': type,
        'tripId': tripId,
        'status': 'displayed',
      });
    } catch (_) {}
  }

  /// Returns a stream that emits the total ACK count for a given [msgId]
  /// across a list of [companionUids]. Used in the SOS screen to show
  /// "3/5 companions notified" in real-time.
  Stream<int> watchSosAckCount(List<String> companionUids, String msgId) {
    if (companionUids.isEmpty || msgId.isEmpty) return Stream.value(0);
    final db = _database;
    if (db == null) return Stream.value(0);
    final streams = companionUids.map((uid) =>
      db.ref('users/$uid/notif_ack/$msgId').onValue.map(
        (e) => e.snapshot.exists ? 1 : 0,
      ),
    ).toList();
    // Merge all companion streams into a running sum
    return streams.fold<Stream<int>>(
      Stream.value(0),
      (combined, stream) => combined.asyncExpand((prevCount) =>
        stream.map((v) => prevCount + v),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // IMPROVEMENT 3 — Notification Gate (deduplication for online users)
  // ---------------------------------------------------------------------------

  /// Attempts to set a deduplication gate at `trips/{tripId}/notif_gate/{alertId}`.
  ///
  /// Returns `true` if the gate was successfully set (no hot gate exists) —
  /// the caller should proceed with the FCM topic send.
  /// Returns `false` if a gate is already active within [ttlMs] — the caller
  /// should suppress the redundant FCM send to avoid notification storms.
  Future<bool> setNotifGate({
    required String tripId,
    required String alertId,
    required String type,
    required String senderUid,
    int ttlMs = 30000,
  }) async {
    if (tripId.isEmpty || alertId.isEmpty) return true;
    final db = _database;
    if (db == null) return true;
    final gateRef = db.ref('trips/$tripId/notif_gate/$alertId');
    try {
      final existing = await gateRef.get();
      if (existing.value != null && existing.value is Map) {
        final gateData = Map<String, dynamic>.from(existing.value as Map);
        final sentAt = gateData['sentAt'];
        if (sentAt is int) {
          final ageMs = DateTime.now().millisecondsSinceEpoch - sentAt;
          if (ageMs < ttlMs) return false; // Gate still hot — suppress duplicate
        }
      }
      await gateRef.set({
        'sentAt': ServerValue.timestamp,
        'type': type,
        'senderUid': senderUid,
        'ttlMs': ttlMs,
      });
      return true; // Gate set — proceed with FCM
    } catch (_) {
      return true; // Fail open: RTDB unavailable → allow FCM
    }
  }

  /// Returns `false` (suppress system notif) if the user is currently live in
  /// the RTDB room for [tripId] — they already received the event as an in-app
  /// banner via the RTDB socket and do not need a duplicate system tray notification.
  bool shouldShowSystemNotif(String tripId) {
    return _connectedTripId != tripId;
  }

  // ---------------------------------------------------------------------------
  // IMPROVEMENT 4 — Wake-on-Demand Queue (reliable targeted delivery fallback)
  // ---------------------------------------------------------------------------

  /// Enqueues a targeted direct message to [targetUid] at
  /// `global/wake_queue/{targetUid}/{msgId}`.
  ///
  /// This is a reliable, zero-cost fallback for companions whose FCM token is
  /// stale or who are temporarily offline. RTDB persistence ensures the message
  /// is delivered on the next app open even without a working FCM token.
  Future<void> enqueueDirectMessage({
    required String targetUid,
    required String msgId,
    required Map<String, dynamic> payload,
    required String senderUid,
    int ttlMs = 86400000, // 24 hours default
  }) async {
    if (targetUid.isEmpty || msgId.isEmpty) return;
    final db = _database;
    if (db == null) return;
    try {
      await db.ref('global/wake_queue/$targetUid/$msgId').set({
        'payload': payload,
        'senderUid': senderUid,
        'sentAt': ServerValue.timestamp,
        'ttlMs': ttlMs,
      });
    } catch (_) {}
  }

  /// Starts listening to the current user's RTDB wake queue at
  /// `global/wake_queue/{myUid}`. Messages are processed and then deleted
  /// (exactly-once delivery semantics).
  ///
  /// Called once on user login in [auth_provider.dart].
  void listenWakeQueue(String myUid) {
    if (myUid.isEmpty || _isDisposed) return;
    final db = _database;
    if (db == null) return;
    _wakeQueueSubscription?.cancel();
    _wakeQueueSubscription = db
        .ref('global/wake_queue/$myUid')
        .onChildAdded
        .listen((event) {
      final msgId = event.snapshot.key;
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        _processWakeMessage(myUid, msgId ?? '', data);
      }
    });
  }

  /// Cancels the wake-queue listener. Called on logout.
  void cancelWakeQueue() {
    _wakeQueueSubscription?.cancel();
    _wakeQueueSubscription = null;
  }

  void _processWakeMessage(String myUid, String msgId, Map<String, dynamic> data) {
    if (msgId.isEmpty) return;
    final db = _database;
    if (db == null) return;
    // TTL guard — discard expired wake messages before processing
    final sentAt = data['sentAt'];
    final ttlMs = (data['ttlMs'] as num?)?.toInt() ?? 86400000;
    if (sentAt is int) {
      final ageMs = DateTime.now().millisecondsSinceEpoch - sentAt;
      if (ageMs > ttlMs) {
        db.ref('global/wake_queue/$myUid/$msgId').remove();
        return;
      }
    }
    // Process the embedded payload through the standard RTDB event handler
    final rawPayload = data['payload'];
    if (rawPayload is Map) {
      final payload = Map<String, dynamic>.from(rawPayload);
      final type = payload['type']?.toString();
      if (type != null && payload.isNotEmpty) {
        _handleIncomingMessage({'type': type, 'payload': payload});
      }
    }
    // Consume (delete) after processing — exactly-once delivery
    db.ref('global/wake_queue/$myUid/$msgId').remove();
  }

  /// Watches real-time distributed editing lock on an expense to prevent simultaneous overwrites
  Stream<Map<String, dynamic>?> watchExpenseLock(String tripId, String expenseId) {
    final db = _database;
    if (db == null) return Stream.value(null);
    return db.ref('trips/$tripId/locks/expenses/$expenseId').onValue.map((event) {
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      }
      return null;
    });
  }

  /// Acquires an atomic editing lock on an expense with automatic onDisconnect release
  Future<bool> acquireExpenseLock(String tripId, String expenseId) async {
    final user = UserService.getCurrentUser();
    if (user.id.isEmpty) return true;
    final db = _database;
    if (db == null) return true;

    final lockRef = db.ref('trips/$tripId/locks/expenses/$expenseId');
    try {
      final snapshot = await lockRef.get();
      if (snapshot.value != null && snapshot.value is Map) {
        final existingLock = Map<String, dynamic>.from(snapshot.value as Map);
        final holderId = existingLock['userId']?.toString();
        // If someone else holds the lock and it was acquired recently (< 15 minutes ago), deny acquisition
        if (holderId != null && holderId != user.id) {
          final timestamp = existingLock['timestamp'];
          if (timestamp is int) {
            final lockAgeMs = DateTime.now().millisecondsSinceEpoch - timestamp;
            if (lockAgeMs < 15 * 60 * 1000) {
              return false; // Active lock held by companion
            }
          }
        }
      }

      await lockRef.onDisconnect().remove();
      await lockRef.set({
        'userId': user.id,
        'userName': user.displayName,
        'timestamp': ServerValue.timestamp,
      });
      return true;
    } catch (_) {
      return true; // Gracefully permit offline edits if network fails
    }
  }

  /// Releases the distributed editing lock on an expense
  Future<void> releaseExpenseLock(String tripId, String expenseId) async {
    final user = UserService.getCurrentUser();
    final db = _database;
    if (db == null) return;
    final lockRef = db.ref('trips/$tripId/locks/expenses/$expenseId');
    try {
      final snapshot = await lockRef.get();
      if (snapshot.value != null && snapshot.value is Map) {
        final existing = Map<String, dynamic>.from(snapshot.value as Map);
        if (existing['userId'] == user.id) {
          await lockRef.remove();
        }
      }
    } catch (_) {}
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

  void broadcastDeleteMemory(String memoryId, String tripId) {
    _sendMessage({
      'type': 'MEMORY_DELETED',
      'payload': {
        'tripId': tripId,
        'memoryId': memoryId,
      },
    });
  }

  void broadcastMemoryLike(String memoryId, String memberId, bool isLiked, String tripId) {
    _sendMessage({
      'type': 'MEMORY_LIKED',
      'payload': {
        'tripId': tripId,
        'memoryId': memoryId,
        'memberId': memberId,
        'isLiked': isLiked,
      },
    });
  }

  /// Broadcasts companion memory capture/upload activity in real-time
  void broadcastMemoryActivity(String tripId, String memberId, String memberName, bool isUploading) {
    final db = _database;
    if (db == null || tripId.isEmpty || memberId.isEmpty) return;
    try {
      final activityRef = db.ref('trips/$tripId/memory_activity/$memberId');
      if (isUploading) {
        activityRef.set({
          'name': memberName,
          'timestamp': ServerValue.timestamp,
        });
        activityRef.onDisconnect().remove();
      } else {
        activityRef.remove();
      }
    } catch (_) {}
  }

  void _sendMessage(Map<String, dynamic> message) {
    final db = _database;
    if (db == null) return;
    if (_connectedTripId != null && !_isDisposed) {
      db.ref('trips/$_connectedTripId/events').push().set(message);
    }
  }

  void disconnect() {
    final currentUserId = UserService.getCurrentUser().id;
    final db = _database;
    if (_connectedTripId != null && currentUserId.isNotEmpty && db != null) {
      try {
        db.ref('trips/$_connectedTripId/presence/$currentUserId').set({
          'status': 'offline',
          'lastSeen': ServerValue.timestamp,
        });
      } catch (_) {}
    }

    _subscription?.cancel();
    _subscription = null;
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _presenceSubscription?.cancel();
    _presenceSubscription = null;
    _sosSubscription?.cancel();
    _sosSubscription = null;
    _nudgeSubscription?.cancel();
    _nudgeSubscription = null;
    _memoryActivitySubscription?.cancel();
    _memoryActivitySubscription = null;
    cancelWakeQueue();
    _connectedTripId = null;
  }

  void dispose() {
    _isDisposed = true;
    _connectionStatusSubscription?.cancel();
    _connectionStatusSubscription = null;
    disconnect();
  }
}

final activeMemoryUploadersProvider = StateProvider.family<List<String>, String>((ref, tripId) => []);

final realtimeSyncServiceProvider = Provider<RealtimeSyncService>((ref) {
  final service = RealtimeSyncService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
