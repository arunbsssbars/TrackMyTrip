import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/services/location_service.dart';
import 'package:trackmytrip/models/nearby_poi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NearbyPOI Model Tests', () {
    test('NearbyPOI formats distance correctly for meters and kilometers', () {
      const poiMeters = NearbyPOI(
        id: 'node_1',
        name: 'Indian Oil Fuel Station',
        category: 'Gas / Fuel Station',
        latitude: 28.9930,
        longitude: 77.0150,
        distanceMeters: 85,
      );
      expect(poiMeters.formattedDistance, equals('85 m'));

      const poiKm = NearbyPOI(
        id: 'node_2',
        name: 'Murthal Haveli',
        category: 'Food & Cafe',
        latitude: 29.0270,
        longitude: 77.0730,
        distanceMeters: 1500,
      );
      expect(poiKm.formattedDistance, equals('1.5 km'));
    });

    test('NearbyPOI maps appropriate icons for each category', () {
      const fuelPoi = NearbyPOI(
        id: '1',
        name: 'BPCL Pump',
        category: 'Gas / Fuel Station',
        latitude: 0,
        longitude: 0,
        distanceMeters: 10,
      );
      expect(fuelPoi.icon, equals(Icons.local_gas_station_rounded));

      const foodPoi = NearbyPOI(
        id: '2',
        name: 'Highway Dhaba',
        category: 'Food & Cafe',
        latitude: 0,
        longitude: 0,
        distanceMeters: 20,
      );
      expect(foodPoi.icon, equals(Icons.restaurant_rounded));

      const hotelPoi = NearbyPOI(
        id: '3',
        name: 'Comfort Inn',
        category: 'Hotel & Stay',
        latitude: 0,
        longitude: 0,
        distanceMeters: 30,
      );
      expect(hotelPoi.icon, equals(Icons.hotel_rounded));

      const scenicPoi = NearbyPOI(
        id: '4',
        name: 'Sunset Viewpoint',
        category: 'Sightseeing',
        latitude: 0,
        longitude: 0,
        distanceMeters: 40,
      );
      expect(scenicPoi.icon, equals(Icons.photo_camera_rounded));
    });

    test('NearbyPOI serializes and deserializes properly', () {
      const poi = NearbyPOI(
        id: 'node_99',
        name: 'CCD Highway Cafe',
        category: 'Food & Cafe',
        latitude: 28.501,
        longitude: 77.534,
        distanceMeters: 120,
        rawType: 'amenity:cafe',
        brand: 'Cafe Coffee Day',
      );

      final json = poi.toJson();
      expect(json['id'], equals('node_99'));
      expect(json['name'], equals('CCD Highway Cafe'));
      expect(json['brand'], equals('Cafe Coffee Day'));
      expect(json['distanceMeters'], equals(120));

      final restored = NearbyPOI.fromJson(json);
      expect(restored.id, equals(poi.id));
      expect(restored.name, equals(poi.name));
      expect(restored.category, equals(poi.category));
      expect(restored.latitude, equals(poi.latitude));
      expect(restored.longitude, equals(poi.longitude));
      expect(restored.distanceMeters, equals(poi.distanceMeters));
      expect(restored.brand, equals(poi.brand));
    });
  });

  group('LocationService Smart Geocoding & POI Tests', () {
    test('calculateRouteEta computes accurate drive time duration', () {
      final etaShort = LocationService.calculateRouteEta(45.0, averageSpeedKmh: 45.0);
      expect(etaShort.inMinutes, equals(60));

      final etaZero = LocationService.calculateRouteEta(0.0);
      expect(etaZero, equals(Duration.zero));
    });
  });
}
