import 'dart:async';

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/trip.dart';
import 'tombstone_service.dart';
import 'trip_share_service.dart';

class CloudTripSyncService {
  // Active sync stream subscriptions per trip
  static final Map<String, StreamSubscription> _activeSubscriptions = {};
  static final Map<String, String> _tripRoomCodes = {};
  static final Map<String, DateTime> _lastSyncedTimes = {};
  static FirebaseFirestore? _customDb;
  static set customDb(FirebaseFirestore? db) => _customDb = db;
  static FirebaseFirestore get firestore => _customDb ?? FirebaseFirestore.instance;
  static FirebaseFirestore get _firestore => firestore;

  static bool get isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Generates a clean, memorable 6-character room join code (e.g. "TRIP-7482" or "TRIP-9K2M")
  static String generateRoomCode(String tripId) {
    if (_tripRoomCodes.containsKey(tripId)) {
      return _tripRoomCodes[tripId]!;
    }
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final random = Random();
    final randomPart = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    final code = 'TRIP-$randomPart';
    _tripRoomCodes[tripId] = code;
    return code;
  }

  /// Associate an existing code with a trip
  static void registerRoomCode(String tripId, String code) {
    _tripRoomCodes[tripId] = code.toUpperCase().trim();
  }

  /// Retrieves the registered room code for a trip
  static String getRoomCode(String tripId, {Trip? trip}) {
    if (trip?.shareCode != null && trip!.shareCode!.isNotEmpty) {
      _tripRoomCodes[tripId] = trip.shareCode!.toUpperCase().trim();
      return _tripRoomCodes[tripId]!;
    }
    if (_tripRoomCodes.containsKey(tripId)) {
      return _tripRoomCodes[tripId]!;
    }
    return generateRoomCode(tripId);
  }

  /// Publishes or updates a trip in the cloud room for live sharing
  static Future<bool> publishTrip(TripPackage package, {String? customCode}) async {
    if (TombstoneService.isTombstoned(package.trip.id)) {
      return false;
    }
    final code = customCode ??
        package.trip.shareCode ??
        _tripRoomCodes[package.trip.id] ??
        generateRoomCode(package.trip.id);
    registerRoomCode(package.trip.id, code);

    final safeMemories = package.memories.where((m) => !TombstoneService.isMemoryTombstoned(m.id)).toList();
    final safePackage = TripPackage(
      trip: package.trip,
      stoppages: package.stoppages,
      expenses: package.expenses,
      memories: safeMemories,
      settlements: package.settlements,
      auditLogs: package.auditLogs,
      exportedAt: package.exportedAt,
    );

    try {
      await _firestore.collection('rooms').doc(code).set({
        'code': code,
        'updatedAt': FieldValue.serverTimestamp(),
        'package': safePackage.toJson(),
      });
      _lastSyncedTimes[package.trip.id] = safePackage.exportedAt;
      if (kDebugMode) {
        debugPrint('[CloudTripSyncService] Successfully published live trip room $code to Firestore (Memories: ${safeMemories.length})');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CloudTripSyncService] Failed to publish trip to Firestore: $e');
      }
      return false;
    }
  }

  /// Fetches a live trip package from the cloud by room code
  static Future<TripPackage?> fetchTripByCode(String inputCode) async {
    String cleanCode = inputCode.trim().toUpperCase();
    if (cleanCode.isEmpty) return null;
    if (!cleanCode.startsWith('TRIP-') && cleanCode.length == 4) {
      cleanCode = 'TRIP-$cleanCode';
    }

    try {
      final docSnapshot = await _firestore.collection('rooms').doc(cleanCode).get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        if (data['package'] is Map) {
          final pkgMap = Map<String, dynamic>.from(data['package'] as Map);
          final pkg = TripPackage.fromJson(pkgMap);
          registerRoomCode(pkg.trip.id, cleanCode);
          return pkg;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CloudTripSyncService] Failed to fetch trip from Firestore: $e');
      }
    }
    return null;
  }

  /// Starts live synchronization polling for active trip session
  static void startLiveSync({
    required String tripId,
    required String roomCode,
    required Function(TripPackage) onRemoteUpdateReceived,
    Duration interval = const Duration(seconds: 3), // kept for backwards compat with args
  }) {
    stopLiveSync(tripId);
    registerRoomCode(tripId, roomCode);

    if (!isFirebaseAvailable && _customDb == null) return;

    try {
      _activeSubscriptions[tripId] = _firestore
          .collection('rooms')
          .doc(roomCode)
          .snapshots()
          .listen((docSnapshot) {
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        if (data['package'] is Map) {
          final pkgMap = Map<String, dynamic>.from(data['package'] as Map);
          final remotePkg = TripPackage.fromJson(pkgMap);
          final safeMemories = remotePkg.memories.where((m) => !TombstoneService.isMemoryTombstoned(m.id)).toList();
          final filteredPkg = TripPackage(
            trip: remotePkg.trip,
            stoppages: remotePkg.stoppages,
            expenses: remotePkg.expenses,
            memories: safeMemories,
            settlements: remotePkg.settlements,
            auditLogs: remotePkg.auditLogs,
            exportedAt: remotePkg.exportedAt,
          );
          
          final lastLocalSync = _lastSyncedTimes[tripId];
          final isNewer = lastLocalSync == null || remotePkg.exportedAt.isAfter(lastLocalSync);
          
          if (isNewer) {
            _lastSyncedTimes[tripId] = remotePkg.exportedAt;
            onRemoteUpdateReceived(filteredPkg);
          }
        }
      }
    });
    } catch (_) {}
  }

  /// Starts global synchronization for all active trips (e.g. on HomeScreen)
  static void startGlobalSync({
    required List<Trip> trips,
    required Function(TripPackage) onUpdateReceived,
    Duration interval = const Duration(seconds: 4), // kept for backwards compat
  }) {
    // With Firestore, we can just start individual live syncs for all trips
    // using snapshots, rather than manually polling.
    for (final trip in trips) {
      final code = getRoomCode(trip.id, trip: trip);
      if (!isLiveSyncActive(trip.id)) {
        startLiveSync(
          tripId: trip.id,
          roomCode: code,
          onRemoteUpdateReceived: onUpdateReceived,
        );
      }
    }
  }

  /// Stops global synchronization
  static void stopGlobalSync() {
    for (final sub in _activeSubscriptions.values) {
      sub.cancel();
    }
    _activeSubscriptions.clear();
  }

  /// Stops live synchronization for a trip
  static void stopLiveSync(String tripId) {
    _activeSubscriptions[tripId]?.cancel();
    _activeSubscriptions.remove(tripId);
  }

  /// Checks if live sync is actively running for a trip
  static bool isLiveSyncActive(String tripId) {
    return _activeSubscriptions.containsKey(tripId);
  }

  /// Deletes the room doc from Firestore when a trip is deleted
  static Future<void> deleteRoom(String tripId) async {
    stopLiveSync(tripId);
    final roomCode = _tripRoomCodes[tripId];
    if (roomCode != null) {
      try {
        await _firestore.collection('rooms').doc(roomCode).delete();
      } catch (_) {}
      _tripRoomCodes.remove(tripId);
    }
    try {
      final snap = await _firestore
          .collection('rooms')
          .where('package.trip.id', isEqualTo: tripId)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
    try {
      final snap2 = await _firestore
          .collection('rooms')
          .where('tripId', isEqualTo: tripId)
          .get();
      for (final doc in snap2.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
    try {
      await FirebaseDatabase.instance.ref('trips/$tripId').remove();
    } catch (_) {}
  }

  /// Removes a companion from the live room package
  static Future<void> removeMemberFromRoom(String tripId, String memberId) async {
    final roomCode = _tripRoomCodes[tripId];
    if (roomCode == null) return;
    try {
      final doc = await _firestore.collection('rooms').doc(roomCode).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey('package')) {
          final pkgMap = Map<String, dynamic>.from(data['package'] as Map);
          final tripMap = Map<String, dynamic>.from(pkgMap['trip'] as Map);
          final members = (tripMap['members'] as List<dynamic>?) ?? [];
          final filteredMembers = members.where((m) => m is Map && m['id'] != memberId).toList();
          tripMap['members'] = filteredMembers;
          pkgMap['trip'] = tripMap;
          await _firestore.collection('rooms').doc(roomCode).update({
            'package': pkgMap,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (_) {}
  }

  /// Last synced timestamp
  static DateTime? getLastSyncedTime(String tripId) {
    return _lastSyncedTimes[tripId];
  }
}
