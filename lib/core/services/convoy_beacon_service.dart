import 'dart:math';
import '../../models/convoy_peer_beacon.dart';

class ConvoyBeaconService {
  static final ConvoyBeaconService _instance = ConvoyBeaconService._internal();
  factory ConvoyBeaconService() => _instance;
  ConvoyBeaconService._internal();

  /// Calculates distance in kilometres between user and peer
  double calculateDistanceKm({
    required double userLat,
    required double userLon,
    required double peerLat,
    required double peerLon,
  }) {
    const double earthRadiusKm = 6371.0;
    final dLat = _degToRad(peerLat - userLat);
    final dLon = _degToRad(peerLon - userLon);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(userLat)) * cos(_degToRad(peerLat)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  /// Calculates compass bearing in degrees (0 - 360) from user to peer
  double calculateBearingDegrees({
    required double userLat,
    required double userLon,
    required double peerLat,
    required double peerLon,
  }) {
    final lat1 = _degToRad(userLat);
    final lat2 = _degToRad(peerLat);
    final dLon = _degToRad(peerLon - userLon);

    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    final radians = atan2(y, x);
    final degrees = (radians * 180.0 / pi + 360.0) % 360.0;
    return degrees;
  }

  /// Formats bearing degree into 8-point compass cardinal
  String getCardinalDirection(double degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((degrees + 22.5) % 360 / 45).floor();
    return directions[index];
  }

  /// Sorts beacons by distance with active SOS beacons prioritized at the top
  List<ConvoyPeerBeacon> sortBeacons({
    required List<ConvoyPeerBeacon> peers,
    required double userLat,
    required double userLon,
  }) {
    final sorted = List<ConvoyPeerBeacon>.from(peers);
    sorted.sort((a, b) {
      if (a.isSosActive && !b.isSosActive) return -1;
      if (!a.isSosActive && b.isSosActive) return 1;

      final distA = calculateDistanceKm(
        userLat: userLat,
        userLon: userLon,
        peerLat: a.latitude,
        peerLon: a.longitude,
      );
      final distB = calculateDistanceKm(
        userLat: userLat,
        userLon: userLon,
        peerLat: b.latitude,
        peerLon: b.longitude,
      );
      return distA.compareTo(distB);
    });
    return sorted;
  }

  static double _degToRad(double deg) => deg * (pi / 180.0);
}
