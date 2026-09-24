import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../../models/stoppage.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';
import 'realtime_sync_service.dart';
import 'firestore_sync_service.dart';
import 'security_service.dart';
import 'user_service.dart';
import 'proximity_alert_service.dart';
import '../../models/proximity_alert.dart';

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
  final bool privacyFuzzing;

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
    this.privacyFuzzing = false,
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
    bool? privacyFuzzing,
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
      privacyFuzzing: privacyFuzzing ?? this.privacyFuzzing,
    );
  }
}

class LiveLocationTrackerNotifier extends StateNotifier<LiveTrackingState> {
  final Ref _ref;
  StreamSubscription<Position>? _positionStreamSub;
  Timer? _broadcastExpiryTimer;
  String? _activeTripId;

  LiveLocationTrackerNotifier(this._ref) : super(const LiveTrackingState());

  @override
  void dispose() {
    _positionStreamSub?.cancel();
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

    try {
      final currentUser = UserService.getCurrentUser();
      _ref.read(proximityAlertServiceProvider).broadcastActivityAlert(
        tripId: tripId,
        type: AlertType.locationShared,
        title: 'Live Location Shared',
        message: '${currentUser.displayName} is sharing live convoy location (${_formatDurationLabel(duration)})',
        senderMemberId: currentUser.id,
        senderName: currentUser.displayName,
      );
    } catch (_) {}

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

  /// Toggles location coordinate fuzzing for MASVS-PRIVACY compliance
  void setPrivacyFuzzing(bool enabled) {
    state = state.copyWith(privacyFuzzing: enabled);
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

  Future<void> startTracking(String tripId, {bool simulateIfUnavailable = false}) async {
    _activeTripId = tripId;

    final hasPerm = await requestPermission();
    if (!hasPerm) {
      state = state.copyWith(statusMessage: 'Location permission required for live tracking.');
      return;
    }

    Position? initialPos;
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

    if (initialPos != null) {
      final initLatLng = LatLng(initialPos.latitude, initialPos.longitude);
      state = LiveTrackingState(
        isTracking: true,
        isSimulated: false,
        currentPosition: initialPos,
        routePoints: [initLatLng],
        trackingStartedAt: DateTime.now(),
        broadcastDuration: const Duration(hours: 24),
        broadcastExpiresAt: DateTime.now().add(const Duration(hours: 24)),
        statusMessage: '🛰️ Live GPS Active • Broadcasting',
      );
    } else {
      state = LiveTrackingState(
        isTracking: true,
        isSimulated: false,
        trackingStartedAt: DateTime.now(),
        broadcastDuration: const Duration(hours: 24),
        broadcastExpiresAt: DateTime.now().add(const Duration(hours: 24)),
        statusMessage: '🛰️ Searching for GPS signal...',
      );
    }

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
      
      double broadcastLat = pos.latitude;
      double broadcastLng = pos.longitude;
      if (state.privacyFuzzing) {
        final fuzzed = SecurityService.fuzzCoordinates(pos.latitude, pos.longitude);
        broadcastLat = fuzzed.latitude;
        broadcastLng = fuzzed.longitude;
      }

      _ref.read(tripListProvider.notifier).updateMemberLocation(_activeTripId!, creatorId, broadcastLat, broadcastLng);
      _ref.read(realtimeSyncServiceProvider).broadcastLocation(creatorId, broadcastLat, broadcastLng, speedKmh: speedKmh, heading: pos.heading);
      _ref.read(firestoreSyncServiceProvider).broadcastLocation(
        _activeTripId!,
        creatorId,
        broadcastLat,
        broadcastLng,
        speedKmh: speedKmh,
        heading: pos.heading,
      );
    }

    // Auto-stoppages are disabled per user requirements. Stoppages are added intentionally by the user.
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

    final double lat = pos?.latitude ?? fallbackLat ?? 28.6139;
    final double lng = pos?.longitude ?? fallbackLng ?? 77.2090;

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
