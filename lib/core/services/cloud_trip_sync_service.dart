import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/trip.dart';
import 'trip_share_service.dart';

class CloudTripSyncService {
  static const List<String> _candidateBases = [
    'http://172.20.10.11:8086/api/rooms',
    'http://10.0.2.2:8086/api/rooms',
    'http://127.0.0.1:8086/api/rooms',
    'http://localhost:8086/api/rooms',
  ];

  static String? _preferredBase;

  // Active sync polling timers per trip
  static final Map<String, Timer> _activeTimers = {};
  static final Map<String, String> _tripRoomCodes = {};
  static final Map<String, DateTime> _lastSyncedTimes = {};
  static Timer? _globalTimer;

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
    final code = customCode ??
        package.trip.shareCode ??
        _tripRoomCodes[package.trip.id] ??
        generateRoomCode(package.trip.id);
    registerRoomCode(package.trip.id, code);

    final payload = {
      'code': code,
      'updatedAt': DateTime.now().toIso8601String(),
      'package': package.toJson(),
    };
    final jsonBody = jsonEncode(payload);

    final endpoints = _preferredBase != null
        ? [_preferredBase!, ..._candidateBases.where((e) => e != _preferredBase)]
        : _candidateBases;

    for (final base in endpoints) {
      try {
        final url = Uri.parse('$base/$code');
        final response = await http.post(
          url,
          body: jsonBody,
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          _preferredBase = base;
          _lastSyncedTimes[package.trip.id] = package.exportedAt;
          if (kDebugMode) {
            print('Successfully published live trip room $code to $base (Expenses: ${package.expenses.length})');
          }
          return true;
        }
      } catch (_) {}
    }

    return false;
  }

  /// Fetches a live trip package from the cloud by room code
  static Future<TripPackage?> fetchTripByCode(String inputCode) async {
    String cleanCode = inputCode.trim().toUpperCase();
    if (!cleanCode.startsWith('TRIP-') && cleanCode.length == 4) {
      cleanCode = 'TRIP-$cleanCode';
    }

    final endpoints = _preferredBase != null
        ? [_preferredBase!, ..._candidateBases.where((e) => e != _preferredBase)]
        : _candidateBases;

    for (final base in endpoints) {
      try {
        final url = Uri.parse('$base/$cleanCode');
        final response = await http.get(url).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200 && response.body.isNotEmpty) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data.containsKey('package')) {
            final pkgMap = data['package'] as Map<String, dynamic>;
            final pkg = TripPackage.fromJson(pkgMap);
            _preferredBase = base;
            registerRoomCode(pkg.trip.id, cleanCode);
            return pkg;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// Starts live synchronization polling for active trip session
  static void startLiveSync({
    required String tripId,
    required String roomCode,
    required Function(TripPackage) onRemoteUpdateReceived,
    Duration interval = const Duration(seconds: 3),
  }) {
    stopLiveSync(tripId);
    registerRoomCode(tripId, roomCode);

    _activeTimers[tripId] = Timer.periodic(interval, (timer) async {
      try {
        final remotePkg = await fetchTripByCode(roomCode);
        if (remotePkg != null) {
          final lastLocalSync = _lastSyncedTimes[tripId];
          final isNewer = lastLocalSync == null || remotePkg.exportedAt.isAfter(lastLocalSync);
          if (isNewer) {
            _lastSyncedTimes[tripId] = remotePkg.exportedAt;
            onRemoteUpdateReceived(remotePkg);
          }
        }
      } catch (_) {}
    });
  }

  /// Starts global synchronization for all active trips (e.g. on HomeScreen)
  static void startGlobalSync({
    required List<Trip> trips,
    required Function(TripPackage) onUpdateReceived,
    Duration interval = const Duration(seconds: 4),
  }) {
    _globalTimer?.cancel();
    if (trips.isEmpty) return;

    _globalTimer = Timer.periodic(interval, (_) async {
      for (final trip in trips) {
        try {
          final code = getRoomCode(trip.id, trip: trip);
          final remotePkg = await fetchTripByCode(code);
          if (remotePkg != null) {
            final lastLocalSync = _lastSyncedTimes[trip.id];
            final isNewer = lastLocalSync == null || remotePkg.exportedAt.isAfter(lastLocalSync);
            if (isNewer) {
              _lastSyncedTimes[trip.id] = remotePkg.exportedAt;
              onUpdateReceived(remotePkg);
            }
          }
        } catch (_) {}
      }
    });
  }

  /// Stops global synchronization
  static void stopGlobalSync() {
    _globalTimer?.cancel();
    _globalTimer = null;
  }

  /// Stops live synchronization for a trip
  static void stopLiveSync(String tripId) {
    _activeTimers[tripId]?.cancel();
    _activeTimers.remove(tripId);
  }

  /// Checks if live sync is actively running for a trip
  static bool isLiveSyncActive(String tripId) {
    return _activeTimers.containsKey(tripId);
  }

  /// Last synced timestamp
  static DateTime? getLastSyncedTime(String tripId) {
    return _lastSyncedTimes[tripId];
  }
}
