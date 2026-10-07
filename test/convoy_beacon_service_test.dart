import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/models/convoy_peer_beacon.dart';
import 'package:trackmytrip/core/services/convoy_beacon_service.dart';
import 'package:trackmytrip/screens/emergency/convoy_radar_sheet.dart';

void main() {
  group('ConvoyBeaconService Trigonometric & Logic Tests', () {
    final service = ConvoyBeaconService();

    test('Calculates distance and bearing between two points', () {
      // User at (0, 0), Peer due North at (1, 0)
      final dist = service.calculateDistanceKm(
        userLat: 0.0,
        userLon: 0.0,
        peerLat: 1.0,
        peerLon: 0.0,
      );
      expect(dist, closeTo(111.0, 1.0)); // 1 degree latitude is ~111 km

      final bearingNorth = service.calculateBearingDegrees(
        userLat: 0.0,
        userLon: 0.0,
        peerLat: 1.0,
        peerLon: 0.0,
      );
      expect(bearingNorth, closeTo(0.0, 0.5));
      expect(service.getCardinalDirection(bearingNorth), 'N');

      // Peer due East at (0, 1)
      final bearingEast = service.calculateBearingDegrees(
        userLat: 0.0,
        userLon: 0.0,
        peerLat: 0.0,
        peerLon: 1.0,
      );
      expect(bearingEast, closeTo(90.0, 0.5));
      expect(service.getCardinalDirection(bearingEast), 'E');
    });

    test('Prioritizes active SOS peers at the top of sorted list', () {
      final now = DateTime.now();
      final normalClose = ConvoyPeerBeacon(
        peerId: 'peer_1',
        displayName: 'Lead Thar',
        vehiclePlateOrRole: 'HP-01-A-1234',
        latitude: 32.2450,
        longitude: 77.1900, // Very close
        lastPingTime: now,
      );

      final sosFar = ConvoyPeerBeacon(
        peerId: 'peer_2',
        displayName: 'Rear Gypsy',
        vehiclePlateOrRole: 'DL-03-C-5678',
        latitude: 32.2600,
        longitude: 77.2100, // Further away
        lastPingTime: now,
        isSosActive: true,
        sosMessage: 'Flat tyre in ditch',
      );

      final sorted = service.sortBeacons(
        peers: [normalClose, sosFar],
        userLat: 32.2432,
        userLon: 77.1892,
      );

      // Even though sosFar is further, it must be sorted first!
      expect(sorted.first.peerId, 'peer_2');
      expect(sorted.first.isSosActive, true);
    });

    test('Json serialization and deserialization retains accuracy', () {
      final beacon = ConvoyPeerBeacon(
        peerId: 'peer_55',
        displayName: 'Scout Bike',
        vehiclePlateOrRole: 'Himalayan 450',
        latitude: 28.5355,
        longitude: 77.3910,
        lastPingTime: DateTime.utc(2026, 10, 8, 14, 0),
        batteryPercent: 88,
        isSosActive: true,
        sosMessage: 'Fuel empty',
      );

      final json = beacon.toJson();
      final restored = ConvoyPeerBeacon.fromJson(json);

      expect(restored.peerId, 'peer_55');
      expect(restored.displayName, 'Scout Bike');
      expect(restored.isSosActive, true);
      expect(restored.batteryPercent, 88);
    });
  });

  group('AQIL Multi-Viewport & Accessibility Tests for ConvoyRadarSheet', () {
    final now = DateTime.now();
    final samplePeers = [
      ConvoyPeerBeacon(
        peerId: 'p1',
        displayName: 'Lead Scorpio',
        vehiclePlateOrRole: 'Fleet Lead',
        latitude: 32.2500,
        longitude: 77.1920,
        lastPingTime: now,
        batteryPercent: 92,
      ),
      ConvoyPeerBeacon(
        peerId: 'p2',
        displayName: 'Rescue Jimny',
        vehiclePlateOrRole: 'Support Crew',
        latitude: 32.2610,
        longitude: 77.2000,
        lastPingTime: now,
        isSosActive: true,
        sosMessage: 'Engine overheating',
      ),
    ];

    final viewports = <String, Size>{
      'Compact Mobile (320px)': const Size(320, 568),
      'Standard Mobile (393px)': const Size(393, 852),
      'Large Mobile (412px)': const Size(412, 915),
      'Tablet Portrait (800px)': const Size(800, 1280),
      'Desktop Landscape (1280px)': const Size(1280, 800),
    };

    for (final entry in viewports.entries) {
      testWidgets('Renders zero overflow on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConvoyRadarSheet(
                userLatitude: 32.2432,
                userLongitude: 77.1892,
                peers: samplePeers,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Convoy Proximity Radar'), findsOneWidget);
        expect(find.byType(ConvoyRadarSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Renders with 1.5x font scale without overflow and toggles SOS', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool? userSosToggled;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              textScaler: const TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: ConvoyRadarSheet(
                userLatitude: 32.2432,
                userLongitude: 77.1892,
                peers: samplePeers,
                onToggleUserSos: (active) => userSosToggled = active,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Convoy Proximity Radar'), findsOneWidget);

      final sosBtn = find.text('Broadcast Convoy SOS');
      expect(sosBtn, findsOneWidget);
      await tester.ensureVisible(sosBtn);
      await tester.tap(sosBtn);
      await tester.pumpAndSettle();

      expect(userSosToggled, true);
      expect(find.text('SOS ACTIVE (TAP TO CANCEL)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
