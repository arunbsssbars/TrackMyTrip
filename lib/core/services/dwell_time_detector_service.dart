import 'dart:math';
import '../../models/dwell_detection_event.dart';

class DwellTimeDetectorService {
  static final DwellTimeDetectorService _instance = DwellTimeDetectorService._internal();
  factory DwellTimeDetectorService() => _instance;
  DwellTimeDetectorService._internal();

  DwellDetectionEvent? _activeDwell;

  DwellDetectionEvent? get activeDwell => _activeDwell;

  /// Resets or clears the current dwell tracking state
  void reset() {
    _activeDwell = null;
  }

  /// Processes a new location ping and returns updated dwell event if stationary threshold is active
  DwellDetectionEvent? processLocationPing({
    required double latitude,
    required double longitude,
    required double speedKmh,
    required DateTime timestamp,
    double dwellRadiusMeters = 50.0,
    double stationarySpeedThresholdKmh = 3.5,
  }) {
    if (speedKmh > stationarySpeedThresholdKmh) {
      // User is moving, clear active dwell
      _activeDwell = null;
      return null;
    }

    if (_activeDwell == null) {
      // First stationary ping, start tracking dwell
      _activeDwell = DwellDetectionEvent(
        latitude: latitude,
        longitude: longitude,
        startTime: timestamp,
        lastPingTime: timestamp,
        radiusMeters: dwellRadiusMeters,
      );
      return _activeDwell;
    }

    // Check if within stationary radius of the original dwell anchor
    final distance = calculateDistanceMeters(
      lat1: _activeDwell!.latitude,
      lon1: _activeDwell!.longitude,
      lat2: latitude,
      lon2: longitude,
    );

    if (distance <= dwellRadiusMeters) {
      // Still stationary in the same zone, update timestamp
      _activeDwell = _activeDwell!.copyWith(lastPingTime: timestamp);
      return _activeDwell;
    } else {
      // Moved out of radius, start fresh anchor
      _activeDwell = DwellDetectionEvent(
        latitude: latitude,
        longitude: longitude,
        startTime: timestamp,
        lastPingTime: timestamp,
        radiusMeters: dwellRadiusMeters,
      );
      return _activeDwell;
    }
  }

  /// Accurate Great-Circle Haversine distance formula in meters
  static double calculateDistanceMeters({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const double earthRadiusMeters = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180.0);
}
