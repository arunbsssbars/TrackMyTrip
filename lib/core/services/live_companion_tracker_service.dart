import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../models/stoppage.dart';
import '../../models/trip_member.dart';

class CompanionLivePosition {
  final String memberId;
  final double latitude;
  final double longitude;
  final double speedKmh;
  final double heading;
  final DateTime lastUpdated;
  final bool isLiveNetwork;
  final int waypointIndex;
  final int? batteryLevel;
  final bool? isCharging;

  const CompanionLivePosition({
    required this.memberId,
    required this.latitude,
    required this.longitude,
    this.speedKmh = 0.0,
    this.heading = 0.0,
    required this.lastUpdated,
    this.isLiveNetwork = false,
    this.waypointIndex = 0,
    this.batteryLevel,
    this.isCharging,
  });

  bool get isLowBattery => batteryLevel != null && batteryLevel! <= 15 && isCharging != true;

  CompanionLivePosition copyWith({
    String? memberId,
    double? latitude,
    double? longitude,
    double? speedKmh,
    double? heading,
    DateTime? lastUpdated,
    bool? isLiveNetwork,
    int? waypointIndex,
    int? batteryLevel,
    bool? isCharging,
  }) {
    return CompanionLivePosition(
      memberId: memberId ?? this.memberId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speedKmh: speedKmh ?? this.speedKmh,
      heading: heading ?? this.heading,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isLiveNetwork: isLiveNetwork ?? this.isLiveNetwork,
      waypointIndex: waypointIndex ?? this.waypointIndex,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCharging: isCharging ?? this.isCharging,
    );
  }
}

class LiveCompanionTrackerNotifier extends StateNotifier<Map<String, CompanionLivePosition>> {
  Timer? _ttlCleanupTimer;

  LiveCompanionTrackerNotifier(Ref _) : super({}) {
    _ttlCleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      purgeStaleLocations();
    });
  }

  @override
  void dispose() {
    _ttlCleanupTimer?.cancel();
    super.dispose();
  }

  /// Purges GPS coordinates older than [ttl] (default 2 hours) to comply with MASVS-PRIVACY
  void purgeStaleLocations({Duration ttl = const Duration(hours: 2)}) {
    final cutoff = DateTime.now().subtract(ttl);
    final filtered = Map<String, CompanionLivePosition>.from(state)
      ..removeWhere((_, pos) => pos.lastUpdated.isBefore(cutoff));
    if (filtered.length != state.length) {
      state = filtered;
    }
  }

  /// Manually clears all cached companion locations upon logout or privacy request
  void clearAllCompanionLocations() {
    state = {};
  }

  /// Ingests live location broadcast from a real remote companion device over WebSocket
  void onRemoteLocationUpdate(
    String memberId,
    double lat,
    double lng, {
    double speedKmh = 0.0,
    double heading = 0.0,
    int? batteryLevel,
    bool? isCharging,
  }) {
    final existing = state[memberId];
    final updated = (existing ?? CompanionLivePosition(
      memberId: memberId,
      latitude: lat,
      longitude: lng,
      lastUpdated: DateTime.now(),
      isLiveNetwork: true,
      batteryLevel: batteryLevel,
      isCharging: isCharging,
    )).copyWith(
      latitude: lat,
      longitude: lng,
      speedKmh: speedKmh,
      heading: heading,
      lastUpdated: DateTime.now(),
      isLiveNetwork: true,
      batteryLevel: batteryLevel ?? existing?.batteryLevel,
      isCharging: isCharging ?? existing?.isCharging,
    );

    state = {
      ...state,
      memberId: updated,
    };
  }

  /// Updates companion presence (online/offline) from real-time WebSocket connection state
  void updateCompanionOnlineStatus(String memberId, bool isOnline) {
    final existing = state[memberId];
    if (existing != null) {
      state = {
        ...state,
        memberId: existing.copyWith(
          isLiveNetwork: isOnline,
          lastUpdated: isOnline ? DateTime.now() : existing.lastUpdated,
        ),
      };
    }
  }

  /// Synchronizes companions from real reported member data.
  /// No fake sinusoidal simulated routes or artificial speeds.
  void startConvoySimulation({
    required String tripId,
    required List<TripMember> companions,
    List<LatLng> roadRoute = const [],
    List<Stoppage> stoppages = const [],
    LatLng? userPos,
  }) {
    if (companions.isEmpty) return;

    final newState = Map<String, CompanionLivePosition>.from(state);

    for (final m in companions) {
      // If companion already has a live network position, preserve it
      if (newState.containsKey(m.id)) continue;

      // Only populate if companion has an actual reported coordinate
      if (m.latitude != null && m.longitude != null) {
        newState[m.id] = CompanionLivePosition(
          memberId: m.id,
          latitude: m.latitude!,
          longitude: m.longitude!,
          speedKmh: 0.0,
          heading: 0.0,
          lastUpdated: m.lastSeen ?? DateTime.now(),
          isLiveNetwork: false,
        );
      }
    }
    state = newState;
  }

  /// Stops any companion ticker
  void stopConvoySimulation() {
  }
}

final liveCompanionTrackerProvider =
    StateNotifierProvider<LiveCompanionTrackerNotifier, Map<String, CompanionLivePosition>>((ref) {
  return LiveCompanionTrackerNotifier(ref);
});
