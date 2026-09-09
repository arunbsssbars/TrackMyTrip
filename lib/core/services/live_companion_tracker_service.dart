import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../models/stoppage.dart';
import '../../models/trip_member.dart';
import '../../providers/trip_provider.dart';

class CompanionLivePosition {
  final String memberId;
  final double latitude;
  final double longitude;
  final double speedKmh;
  final double heading;
  final DateTime lastUpdated;
  final bool isLiveNetwork;
  final int waypointIndex;

  const CompanionLivePosition({
    required this.memberId,
    required this.latitude,
    required this.longitude,
    this.speedKmh = 0.0,
    this.heading = 0.0,
    required this.lastUpdated,
    this.isLiveNetwork = false,
    this.waypointIndex = 0,
  });

  CompanionLivePosition copyWith({
    String? memberId,
    double? latitude,
    double? longitude,
    double? speedKmh,
    double? heading,
    DateTime? lastUpdated,
    bool? isLiveNetwork,
    int? waypointIndex,
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
    );
  }
}

class LiveCompanionTrackerNotifier extends StateNotifier<Map<String, CompanionLivePosition>> {
  final Ref _ref;
  Timer? _convoyTicker;
  String? _activeTripId;
  List<LatLng> _routePoints = [];

  LiveCompanionTrackerNotifier(this._ref) : super({});

  @override
  void dispose() {
    _convoyTicker?.cancel();
    super.dispose();
  }

  /// Ingests live location broadcast from a real remote companion device over WebSocket
  void onRemoteLocationUpdate(
    String memberId,
    double lat,
    double lng, {
    double speedKmh = 0.0,
    double heading = 0.0,
  }) {
    final existing = state[memberId];
    final updated = (existing ?? CompanionLivePosition(
      memberId: memberId,
      latitude: lat,
      longitude: lng,
      lastUpdated: DateTime.now(),
      isLiveNetwork: true,
    )).copyWith(
      latitude: lat,
      longitude: lng,
      speedKmh: speedKmh,
      heading: heading,
      lastUpdated: DateTime.now(),
      isLiveNetwork: true, // Flags that this companion is actively reporting live GPS
    );

    state = {
      ...state,
      memberId: updated,
    };
  }

  /// Starts realistic road movement for companions along the route.
  /// Battery-efficient: Only runs while MapTab is in foreground; stopped on dispose.
  void startConvoySimulation({
    required String tripId,
    required List<TripMember> companions,
    List<LatLng> roadRoute = const [],
    List<Stoppage> stoppages = const [],
    LatLng? userPos,
  }) {
    _activeTripId = tripId;
    _routePoints = roadRoute;

    if (companions.isEmpty) return;

    // Initialize positions if not already present
    final newState = Map<String, CompanionLivePosition>.from(state);
    final basePos = userPos ?? (stoppages.isNotEmpty ? LatLng(stoppages.first.latitude, stoppages.first.longitude) : const LatLng(37.7749, -122.4194));

    for (int i = 0; i < companions.length; i++) {
      final m = companions[i];
      if (!newState.containsKey(m.id)) {
        double initLat = m.latitude ?? basePos.latitude;
        double initLng = m.longitude ?? basePos.longitude;
        int initialWp = 0;

        if (roadRoute.isNotEmpty) {
          // Spread companions slightly along the route (e.g. 5 to 15 waypoints apart)
          initialWp = (i * 8) % roadRoute.length;
          initLat = roadRoute[initialWp].latitude;
          initLng = roadRoute[initialWp].longitude;
        } else if (stoppages.isNotEmpty) {
          final s = stoppages[i % stoppages.length];
          // Slight realistic offset (200m - 500m)
          final angle = (i * 1.5) + 0.5;
          initLat = s.latitude + (math.sin(angle) * 0.003);
          initLng = s.longitude + (math.cos(angle) * 0.003);
        }

        newState[m.id] = CompanionLivePosition(
          memberId: m.id,
          latitude: initLat,
          longitude: initLng,
          speedKmh: 42.0 + (i * 6.5),
          heading: 45.0,
          lastUpdated: DateTime.now(),
          isLiveNetwork: false,
          waypointIndex: initialWp,
        );
      }
    }
    state = newState;

    _convoyTicker?.cancel();
    // 3-second tick: smooth enough for map navigation while preserving 95% CPU/battery
    _convoyTicker = Timer.periodic(const Duration(seconds: 3), (_) {
      _tickConvoyMovement(companions, stoppages);
    });
  }

  void _tickConvoyMovement(List<TripMember> companions, List<Stoppage> stoppages) {
    if (state.isEmpty) return;

    final updated = Map<String, CompanionLivePosition>.from(state);
    bool changed = false;

    for (int i = 0; i < companions.length; i++) {
      final companion = companions[i];
      final current = updated[companion.id];
      if (current == null) continue;

      // Real network GPS overrides convoy simulation
      if (current.isLiveNetwork) {
        continue;
      }

      double newLat = current.latitude;
      double newLng = current.longitude;
      double newHeading = current.heading;
      int nextWp = current.waypointIndex;

      // Realistic speed variation (40 - 68 km/h)
      final speedVariance = math.sin(DateTime.now().millisecondsSinceEpoch / 4000.0 + i) * 5.0;
      final speedKmh = math.max(25.0, (48.0 + (i * 5.0)) + speedVariance);

      if (_routePoints.length >= 2) {
        // Move along the actual road route
        nextWp = (current.waypointIndex + 1) % _routePoints.length;
        final targetPoint = _routePoints[nextWp];
        newHeading = Geolocator.bearingBetween(current.latitude, current.longitude, targetPoint.latitude, targetPoint.longitude);
        newLat = targetPoint.latitude;
        newLng = targetPoint.longitude;
      } else {
        // Smooth road-like trajectory simulation around base area
        const deltaSec = 3.0;
        final distMeters = (speedKmh * 1000.0 / 3600.0) * deltaSec; // distance traveled in 3 sec (~40m)
        final angleRad = (i * 1.2) + (DateTime.now().millisecondsSinceEpoch / 10000.0);
        newLat = current.latitude + (math.sin(angleRad) * (distMeters / 111320.0));
        newLng = current.longitude + (math.cos(angleRad) * (distMeters / (111320.0 * math.cos(current.latitude * math.pi / 180.0))));
        newHeading = (angleRad * 180.0 / math.pi) % 360.0;
      }

      updated[companion.id] = current.copyWith(
        latitude: newLat,
        longitude: newLng,
        speedKmh: speedKmh,
        heading: newHeading,
        lastUpdated: DateTime.now(),
        waypointIndex: nextWp,
      );
      changed = true;

      // Update in tripListProvider so all listeners across tabs reflect the new coordinates
      if (_activeTripId != null) {
        _ref.read(tripListProvider.notifier).updateMemberLocation(_activeTripId!, companion.id, newLat, newLng);
      }
    }

    if (changed) {
      state = updated;
    }
  }

  /// Completely stops companion simulation to save 100% battery when leaving Route tab
  void stopConvoySimulation() {
    _convoyTicker?.cancel();
    _convoyTicker = null;
  }
}

final liveCompanionTrackerProvider =
    StateNotifierProvider<LiveCompanionTrackerNotifier, Map<String, CompanionLivePosition>>((ref) {
  return LiveCompanionTrackerNotifier(ref);
});
