import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../../models/stoppage.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';
import 'realtime_sync_service.dart';

class LiveTrackingState {
  final bool isTracking;
  final bool isSimulated;
  final Position? currentPosition;
  final List<LatLng> routePoints;
  final double totalDistanceKm;
  final double currentSpeedKmh;
  final DateTime? trackingStartedAt;
  final String? activeStoppageId;
  final DateTime? stationarySince;
  final String? statusMessage;
  final Duration? broadcastDuration;
  final DateTime? broadcastExpiresAt;

  const LiveTrackingState({
    this.isTracking = false,
    this.isSimulated = false,
    this.currentPosition,
    this.routePoints = const [],
    this.totalDistanceKm = 0.0,
    this.currentSpeedKmh = 0.0,
    this.trackingStartedAt,
    this.activeStoppageId,
    this.stationarySince,
    this.statusMessage,
    this.broadcastDuration,
    this.broadcastExpiresAt,
  });

  bool get isBroadcasting =>
      isTracking &&
      broadcastExpiresAt != null &&
      DateTime.now().isBefore(broadcastExpiresAt!);

  Duration? get broadcastRemaining {
    if (broadcastExpiresAt == null) return null;
    final diff = broadcastExpiresAt!.difference(DateTime.now());
    if (diff.isNegative) return null;
    return diff;
  }

  LiveTrackingState copyWith({
    bool? isTracking,
    bool? isSimulated,
    Position? currentPosition,
    List<LatLng>? routePoints,
    double? totalDistanceKm,
    double? currentSpeedKmh,
    DateTime? trackingStartedAt,
    String? activeStoppageId,
    DateTime? stationarySince,
    String? statusMessage,
    Duration? broadcastDuration,
    DateTime? broadcastExpiresAt,
    bool clearBroadcast = false,
  }) {
    return LiveTrackingState(
      isTracking: isTracking ?? this.isTracking,
      isSimulated: isSimulated ?? this.isSimulated,
      currentPosition: currentPosition ?? this.currentPosition,
      routePoints: routePoints ?? this.routePoints,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      trackingStartedAt: trackingStartedAt ?? this.trackingStartedAt,
      activeStoppageId: activeStoppageId ?? this.activeStoppageId,
      stationarySince: stationarySince ?? this.stationarySince,
      statusMessage: statusMessage ?? this.statusMessage,
      broadcastDuration: clearBroadcast ? null : (broadcastDuration ?? this.broadcastDuration),
      broadcastExpiresAt: clearBroadcast ? null : (broadcastExpiresAt ?? this.broadcastExpiresAt),
    );
  }
}

class LiveLocationTrackerNotifier extends StateNotifier<LiveTrackingState> {
  final Ref _ref;
  StreamSubscription<Position>? _positionStreamSub;
  Timer? _simulatedDriveTimer;
  Timer? _broadcastExpiryTimer;
  String? _activeTripId;

  LiveLocationTrackerNotifier(this._ref) : super(const LiveTrackingState());

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _simulatedDriveTimer?.cancel();
    _broadcastExpiryTimer?.cancel();
    super.dispose();
  }

  /// Starts or updates time-limited location broadcasting (15m, 4h, 8h, full day / 24h).
  /// Automatically stops broadcasting and preserves battery when the duration expires.
  void startLocationBroadcast(String tripId, Duration duration) {
    _broadcastExpiryTimer?.cancel();
    final expiresAt = DateTime.now().add(duration);
    state = state.copyWith(
      broadcastDuration: duration,
      broadcastExpiresAt: expiresAt,
      statusMessage: 'Live broadcast active (${_formatDurationLabel(duration)})',
    );

    if (!state.isTracking) {
      startTracking(tripId);
    }

    _broadcastExpiryTimer = Timer(duration, () {
      stopLocationBroadcast(expired: true);
    });
  }

  /// Stops broadcasting location to companions
  void stopLocationBroadcast({bool expired = false}) {
    _broadcastExpiryTimer?.cancel();
    state = state.copyWith(
      clearBroadcast: true,
      statusMessage: expired
          ? 'Live broadcast expired. Location is now private.'
          : 'Live broadcast stopped.',
    );
  }

  static String _formatDurationLabel(Duration duration) {
    if (duration.inMinutes == 15) return '15 mins';
    if (duration.inHours == 4) return '4 hours';
    if (duration.inHours == 8) return '8 hours';
    if (duration.inHours == 24) return 'Full Day';
    return '${duration.inMinutes} mins';
  }

  Future<bool> requestPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(statusMessage: 'Location services disabled on device.');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(statusMessage: 'Location permission denied.');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(statusMessage: 'Location permissions permanently denied.');
        return false;
      }

      return true;
    } catch (e) {
      state = state.copyWith(statusMessage: 'Permission check error: $e');
      return false;
    }
  }

  Future<void> startTracking(String tripId, {bool simulateIfUnavailable = true}) async {
    _activeTripId = tripId;
    _simulatedDriveTimer?.cancel();

    final hasPerm = await requestPermission();
    if (!hasPerm && !simulateIfUnavailable) {
      return;
    }

    Position? initialPos;
    if (hasPerm) {
      try {
        initialPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 6),
          ),
        );
      } catch (e) {
        try {
          initialPos = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }
    }

    if (initialPos != null) {
      final initLatLng = LatLng(initialPos.latitude, initialPos.longitude);
      state = LiveTrackingState(
        isTracking: true,
        isSimulated: false,
        currentPosition: initialPos,
        routePoints: [initLatLng],
        trackingStartedAt: DateTime.now(),
        statusMessage: '🛰️ Live GPS Active',
      );

      _positionStreamSub?.cancel();
      LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
          forceLocationManager: false,
          intervalDuration: const Duration(seconds: 4),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Trip Live Route Tracking',
            notificationText: 'Battery-optimized travel route recording active.',
            enableWakeLock: false,
            setOngoing: true,
          ),
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        );
      }

      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _onNewPosition,
        onError: (err) {
          state = state.copyWith(statusMessage: 'GPS Stream: $err');
        },
      );
    } else if (simulateIfUnavailable) {
      // Start Simulated Drive along trip area
      _startSimulatedTracking(tripId);
    } else {
      state = state.copyWith(statusMessage: 'Could not acquire GPS coordinates.');
    }
  }

  void _startSimulatedTracking(String tripId) {
    _positionStreamSub?.cancel();
    _simulatedDriveTimer?.cancel();

    final stoppages = _ref.read(allStoppagesProvider).where((s) => s.tripId == tripId).toList();
    double startLat = 37.7749;
    double startLng = -122.4194;

    if (stoppages.isNotEmpty) {
      startLat = stoppages.first.latitude;
      startLng = stoppages.first.longitude;
    }

    final initialPos = Position(
      latitude: startLat,
      longitude: startLng,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 10.0,
      altitudeAccuracy: 1.0,
      heading: 45.0,
      headingAccuracy: 1.0,
      speed: 12.5, // ~45 km/h
      speedAccuracy: 1.0,
    );

    final initLatLng = LatLng(startLat, startLng);
    state = LiveTrackingState(
      isTracking: true,
      isSimulated: true,
      currentPosition: initialPos,
      routePoints: [initLatLng],
      currentSpeedKmh: 45.0,
      trackingStartedAt: DateTime.now(),
      statusMessage: '🚗 Auto Tracking Active (Road Mode)',
    );

    int step = 0;
    _simulatedDriveTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!state.isTracking) {
        timer.cancel();
        return;
      }

      step++;
      final lastPos = state.currentPosition ?? initialPos;
      // Advance coordinates along a realistic road trajectory
      final deltaLat = (math.sin(step * 0.2) * 0.0015) + 0.001;
      final deltaLng = (math.cos(step * 0.2) * 0.0015) - 0.001;
      final newLat = lastPos.latitude + deltaLat;
      final newLng = lastPos.longitude + deltaLng;
      final speedKmh = 40.0 + (step % 5) * 4.0;

      final updatedPos = Position(
        latitude: newLat,
        longitude: newLng,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 15.0,
        altitudeAccuracy: 1.0,
        heading: 90.0,
        headingAccuracy: 1.0,
        speed: speedKmh / 3.6,
        speedAccuracy: 1.0,
      );

      final newPoint = LatLng(newLat, newLng);
      final updatedPoints = [...state.routePoints, newPoint];
      final addedDistKm = Geolocator.distanceBetween(
        lastPos.latitude,
        lastPos.longitude,
        newLat,
        newLng,
      ) / 1000.0;

      state = state.copyWith(
        currentPosition: updatedPos,
        routePoints: updatedPoints,
        totalDistanceKm: state.totalDistanceKm + addedDistKm,
        currentSpeedKmh: speedKmh,
        statusMessage: '🚗 Live Tracking • ${speedKmh.toStringAsFixed(0)} km/h',
      );

      if (_activeTripId != null && state.isBroadcasting) {
        final currentTrip = _ref.read(currentTripProvider);
        final creatorId = currentTrip?.currentUserMember?.id ?? currentTrip?.members.firstOrNull?.id ?? 'User';
        _ref.read(tripListProvider.notifier).updateMemberLocation(_activeTripId!, creatorId, newLat, newLng);
        _ref.read(realtimeSyncServiceProvider).broadcastLocation(creatorId, newLat, newLng, speedKmh: speedKmh, heading: 90.0);
      }
    });
  }

  void _onNewPosition(Position pos) {
    if (!state.isTracking) return;

    final newPoint = LatLng(pos.latitude, pos.longitude);
    final updatedPoints = [...state.routePoints, newPoint];

    double addedDist = 0.0;
    if (state.routePoints.isNotEmpty) {
      final lastPoint = state.routePoints.last;
      addedDist = Geolocator.distanceBetween(
        lastPoint.latitude,
        lastPoint.longitude,
        newPoint.latitude,
        newPoint.longitude,
      ) / 1000.0;
    }

    final speedKmh = pos.speed >= 0 ? (pos.speed * 3.6) : 0.0;
    final now = DateTime.now();

    DateTime? stationarySince = state.stationarySince;
    if (speedKmh < 3.0) {
      stationarySince ??= now;
    } else {
      stationarySince = null;
    }

    state = state.copyWith(
      currentPosition: pos,
      routePoints: updatedPoints,
      totalDistanceKm: state.totalDistanceKm + addedDist,
      currentSpeedKmh: speedKmh,
      stationarySince: stationarySince,
      statusMessage: '🛰️ Live Tracking • ${speedKmh.toStringAsFixed(1)} km/h',
    );

    if (_activeTripId != null && state.isBroadcasting) {
      final currentTrip = _ref.read(currentTripProvider);
      final creatorId = currentTrip?.currentUserMember?.id ?? currentTrip?.members.firstOrNull?.id ?? 'User';
      _ref.read(tripListProvider.notifier).updateMemberLocation(_activeTripId!, creatorId, pos.latitude, pos.longitude);
      _ref.read(realtimeSyncServiceProvider).broadcastLocation(creatorId, pos.latitude, pos.longitude, speedKmh: speedKmh, heading: pos.heading);
    }

    if (stationarySince != null &&
        now.difference(stationarySince).inMinutes >= 3 &&
        state.activeStoppageId == null &&
        _activeTripId != null) {
      _autoCreateStoppage(pos, stationarySince);
    }
  }

  void _autoCreateStoppage(Position pos, DateTime arrivedAt) {
    if (_activeTripId == null) return;

    final currentTrip = _ref.read(currentTripProvider);
    final creatorId = currentTrip?.currentUserMember?.id ?? currentTrip?.members.firstOrNull?.id ?? 'User';

    final stoppageIndex = _ref.read(allStoppagesProvider).where((s) => s.tripId == _activeTripId).length + 1;
    final autoStop = Stoppage(
      id: const Uuid().v4(),
      tripId: _activeTripId!,
      name: 'Auto Pitstop #$stoppageIndex',
      category: 'Rest Stop',
      latitude: pos.latitude,
      longitude: pos.longitude,
      arrivedAt: arrivedAt,
      createdBy: creatorId,
      orderIndex: stoppageIndex,
      address: 'GPS: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}',
    );

    _ref.read(allStoppagesProvider.notifier).addStoppage(autoStop);
    state = state.copyWith(
      activeStoppageId: autoStop.id,
      statusMessage: '📍 Auto-detected Pitstop #$stoppageIndex',
    );
  }

  Future<Stoppage?> tagCurrentLocationAsStoppage({
    required String tripId,
    required String name,
    required String category,
    double? fallbackLat,
    double? fallbackLng,
  }) async {
    Position? pos = state.currentPosition;
    if (pos == null) {
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
      } catch (_) {}
    }

    final double lat = pos?.latitude ?? fallbackLat ?? 37.7749;
    final double lng = pos?.longitude ?? fallbackLng ?? -122.4194;

    final currentTrip = _ref.read(currentTripProvider);
    final creatorId = currentTrip?.currentUserMember?.id ?? currentTrip?.members.firstOrNull?.id ?? 'User';
    final stoppageIndex = _ref.read(allStoppagesProvider).where((s) => s.tripId == tripId).length + 1;

    final newStop = Stoppage(
      id: const Uuid().v4(),
      tripId: tripId,
      name: name,
      category: category,
      latitude: lat,
      longitude: lng,
      arrivedAt: DateTime.now(),
      createdBy: creatorId,
      orderIndex: stoppageIndex,
      address: 'GPS: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
    );

    await _ref.read(allStoppagesProvider.notifier).addStoppage(newStop);
    state = state.copyWith(
      activeStoppageId: newStop.id,
      statusMessage: '📍 Tagged: ${newStop.name}',
    );
    return newStop;
  }

  void stopTracking() {
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
    _simulatedDriveTimer?.cancel();
    _simulatedDriveTimer = null;
    state = state.copyWith(
      isTracking: false,
      statusMessage: 'Tracking paused',
    );
  }
}

final liveLocationTrackerProvider =
    StateNotifierProvider<LiveLocationTrackerNotifier, LiveTrackingState>((ref) {
  return LiveLocationTrackerNotifier(ref);
});
