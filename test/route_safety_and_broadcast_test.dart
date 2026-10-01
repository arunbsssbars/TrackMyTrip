import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trackmytrip/core/services/location_service.dart';
import 'package:trackmytrip/core/services/live_location_tracker_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TransportMode and ETA Tests', () {
    test('TransportMode properties match realistic specifications', () {
      expect(TransportMode.car.label, equals('Car'));
      expect(TransportMode.car.osrmProfile, equals('driving'));
      expect(TransportMode.car.averageSpeedKmh, equals(60.0));

      expect(TransportMode.bike.label, equals('Bike'));
      expect(TransportMode.bike.osrmProfile, equals('bike'));
      expect(TransportMode.bike.averageSpeedKmh, equals(22.0));

      expect(TransportMode.foot.label, equals('On Foot'));
      expect(TransportMode.foot.osrmProfile, equals('foot'));
      expect(TransportMode.foot.averageSpeedKmh, equals(4.5));

      expect(TransportMode.train.label, equals('Train'));
      expect(TransportMode.train.averageSpeedKmh, equals(80.0));
    });

    test('LocationService.calculateRouteEta handles various transport modes', () {
      // 60 km at 60 km/h = 1 hour (60 min)
      final carEta = LocationService.calculateRouteEta(60.0, averageSpeedKmh: TransportMode.car.averageSpeedKmh);
      expect(carEta.inMinutes, equals(60));

      // 22 km at 22 km/h = 1 hour (60 min)
      final bikeEta = LocationService.calculateRouteEta(22.0, averageSpeedKmh: TransportMode.bike.averageSpeedKmh);
      expect(bikeEta.inMinutes, equals(60));

      // 9 km at 4.5 km/h = 2 hours (120 min)
      final footEta = LocationService.calculateRouteEta(9.0, averageSpeedKmh: TransportMode.foot.averageSpeedKmh);
      expect(footEta.inMinutes, equals(120));

      // 160 km at 80 km/h = 2 hours (120 min)
      final trainEta = LocationService.calculateRouteEta(160.0, averageSpeedKmh: TransportMode.train.averageSpeedKmh);
      expect(trainEta.inMinutes, equals(120));
    });
  });

  group('Route Safety Algorithm Tests', () {
    test('fetchNavigableRoute handles empty or single waypoint gracefully', () async {
      final emptyResult = await LocationService.fetchNavigableRoute([]);
      expect(emptyResult.isNavigable, isTrue);
      expect(emptyResult.distanceKm, equals(0.0));
      expect(emptyResult.estimatedDuration, equals(Duration.zero));

      const singlePoint = LatLng(28.6139, 77.2090);
      final singleResult = await LocationService.fetchNavigableRoute([singlePoint]);
      expect(singleResult.isNavigable, isTrue);
      expect(singleResult.points.length, equals(1));
    });

    test('fetchNavigableRoute detects dangerous cross-ocean/continent distances > 4000 km', () async {
      // New Delhi (28.6, 77.2) to London (51.5, -0.1) is ~6700 km
      const delhi = LatLng(28.6139, 77.2090);
      const london = LatLng(51.5074, -0.1278);

      final result = await LocationService.fetchNavigableRoute([delhi, london]);

      // Safety engine must flag route across ocean as unnavigable
      expect(result.isNavigable, isFalse);
      expect(result.safetyAdvisories.isNotEmpty, isTrue);
      expect(result.safetyAdvisories.first, contains('exceeds navigable land limits'));
    });

    test('fetchNavigableRoute generates offline fallback for local points safely', () async {
      // Local points within 20 km (Connaught Place to Noida)
      const cp = LatLng(28.6315, 77.2167);
      const noida = LatLng(28.5355, 77.3910);

      final result = await LocationService.fetchNavigableRoute([cp, noida], mode: TransportMode.bike);

      expect(result.points.isNotEmpty, isTrue);
      expect(result.mode, equals(TransportMode.bike));
      expect(result.distanceKm, greaterThan(10.0));
      expect(result.distanceKm, lessThan(40.0));
    });
  });

  group('Location Broadcast Duration & Expiration Tests', () {
    test('LiveTrackingState defaults to not broadcasting', () {
      const state = LiveTrackingState();
      expect(state.isBroadcasting, isFalse);
      expect(state.broadcastDuration, isNull);
      expect(state.broadcastExpiresAt, isNull);
      expect(state.broadcastRemaining, isNull);
    });

    test('LiveTrackingState reports isBroadcasting true when expiration is in the future and tracking is active', () {
      final futureExpiry = DateTime.now().add(const Duration(minutes: 15));
      final state = LiveTrackingState(
        isTracking: true,
        broadcastDuration: const Duration(minutes: 15),
        broadcastExpiresAt: futureExpiry,
      );

      expect(state.isBroadcasting, isTrue);
      expect(state.broadcastRemaining, isNotNull);
      expect(state.broadcastRemaining!.inMinutes, greaterThanOrEqualTo(14));
    });

    test('LiveTrackingState reports isBroadcasting false when expired', () {
      final pastExpiry = DateTime.now().subtract(const Duration(seconds: 10));
      final state = LiveTrackingState(
        isTracking: true,
        broadcastDuration: const Duration(hours: 4),
        broadcastExpiresAt: pastExpiry,
      );

      expect(state.isBroadcasting, isFalse);
      expect(state.broadcastRemaining, isNull);
    });

    test('LiveTrackingState copyWith updates broadcast attributes properly', () {
      const state = LiveTrackingState(isTracking: true);
      final now = DateTime.now();
      final expiry = now.add(const Duration(hours: 8));

      final updated = state.copyWith(
        broadcastDuration: const Duration(hours: 8),
        broadcastExpiresAt: expiry,
      );

      expect(updated.broadcastDuration, equals(const Duration(hours: 8)));
      expect(updated.broadcastExpiresAt, equals(expiry));
      expect(updated.isBroadcasting, isTrue);

      // Stop broadcasting
      final stopped = updated.copyWith(
        clearBroadcast: true,
      );
      expect(stopped.isBroadcasting, isFalse);
      expect(stopped.broadcastDuration, isNull);
      expect(stopped.broadcastExpiresAt, isNull);
    });
  });
}
