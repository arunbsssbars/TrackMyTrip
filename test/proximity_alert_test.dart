import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trip_tracker_app/core/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_tracker_app/core/services/local_storage_service.dart';
import 'package:trip_tracker_app/core/services/proximity_alert_service.dart';
import 'package:trip_tracker_app/models/proximity_alert.dart';
import 'package:trip_tracker_app/models/stoppage.dart';
import 'package:trip_tracker_app/models/trip_member.dart';
import 'package:trip_tracker_app/providers/trip_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 7: ProximityAlert Model Tests', () {
    test('ProximityAlert serializes and deserializes correctly', () {
      final alert = ProximityAlert(
        id: 'alt_001',
        tripId: 'trip_100',
        type: AlertType.companionStray,
        title: 'Companion Stray Warning',
        message: 'Sarah is 1.8 km away from the group',
        senderMemberId: 'usr_sarah',
        senderName: 'Sarah',
        latitude: 32.2432,
        longitude: 77.1892,
        distanceMeters: 1840.0,
        timestamp: DateTime(2026, 9, 4, 11, 45),
        urgency: AlertUrgency.high,
        isRead: false,
      );

      final json = alert.toJson();
      expect(json['id'], equals('alt_001'));
      expect(json['type'], equals('companionStray'));
      expect(json['urgency'], equals('high'));
      expect(json['distanceMeters'], equals(1840.0));

      final revived = ProximityAlert.fromJson(json);
      expect(revived.id, equals('alt_001'));
      expect(revived.title, equals('Companion Stray Warning'));
      expect(revived.urgency, equals(AlertUrgency.high));
      expect(revived.type, equals(AlertType.companionStray));
    });
  });

  group('Phase 7: LocalStorageService Alert Persistence Tests', () {
    late SharedPreferences prefs;
    late AppDatabase appDb;

    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      appDb = await AppDatabase.open(customPath: inMemoryDatabasePath);
    });

    tearDown(() async {
      await appDb.database.close();
    });

    test('Alerts can be saved, retrieved, marked as read, and cleared', () async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      final storage = await LocalStorageService.init(prefs: prefs, database: appDb);

      expect(storage.getAllAlerts(), isEmpty);

      final alert1 = ProximityAlert(
        id: 'alt_1',
        tripId: 'trip_1',
        type: AlertType.stoppageArrival,
        title: 'Arrived at Pitstop',
        message: 'Arun reached Cafe Coffee Day',
        senderMemberId: 'usr_me',
        senderName: 'Arun',
        timestamp: DateTime.now(),
      );

      final alert2 = ProximityAlert(
        id: 'alt_2',
        tripId: 'trip_1',
        type: AlertType.sosEmergency,
        title: 'EMERGENCY SOS',
        message: 'Need help!',
        senderMemberId: 'usr_sarah',
        senderName: 'Sarah',
        timestamp: DateTime.now(),
        urgency: AlertUrgency.critical,
      );

      await storage.addAlert(alert1);
      await storage.addAlert(alert2);

      final alerts = storage.getAllAlerts();
      expect(alerts.length, equals(2));
      expect(alerts[0].id, equals('alt_2')); // Most recent first
      expect(alerts[1].id, equals('alt_1'));

      // Mark alert1 as read
      await storage.markAlertAsRead('alt_1');
      final updated = storage.getAllAlerts();
      expect(updated.firstWhere((a) => a.id == 'alt_1').isRead, isTrue);
      expect(updated.firstWhere((a) => a.id == 'alt_2').isRead, isFalse);

      // Clear all
      await storage.clearAllAlerts();
      expect(storage.getAllAlerts(), isEmpty);
    });
  });

  group('Phase 7: ProximityAlertService Logic & Geofencing Tests', () {
    test('Detects companion straying beyond 1.5 km threshold', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = await LocalStorageService.init(prefs: prefs, database: await AppDatabase.open(customPath: inMemoryDatabasePath));
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
        ],
      );

      final service = container.read(proximityAlertServiceProvider);

      // My position in Manali center: (32.2396, 77.1887)
      // Companion 1: Near (0.2 km away) -> (32.2410, 77.1890)
      // Companion 2: Far (3.2 km away) -> (32.2680, 77.1890)
      const nearCompanion = TripMember(
        id: 'usr_near',
        name: 'Mike',
        latitude: 32.2410,
        longitude: 77.1890,
      );

      const farCompanion = TripMember(
        id: 'usr_far',
        name: 'Elena',
        latitude: 32.2680,
        longitude: 77.1890,
      );

      service.evaluateCompanionProximities(
        tripId: 'trip_100',
        myLat: 32.2396,
        myLng: 77.1887,
        companions: [nearCompanion, farCompanion],
        myName: 'Trip Lead',
      );

      // Only Elena should trigger a stray alert
      expect(service.alerts.length, equals(1));
      final strayAlert = service.alerts.first;
      expect(strayAlert.senderMemberId, equals('usr_far'));
      expect(strayAlert.type, equals(AlertType.companionStray));
      expect(strayAlert.urgency, equals(AlertUrgency.high));
      expect(strayAlert.distanceMeters, greaterThan(1500));
    });

    test('Detects pitstop arrival within 350m geofence radius', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = await LocalStorageService.init(prefs: prefs, database: await AppDatabase.open(customPath: inMemoryDatabasePath));
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
        ],
      );

      final service = container.read(proximityAlertServiceProvider);

      // User location: (32.2396, 77.1887)
      // Stop 1 (Within 100m): (32.2400, 77.1890)
      // Stop 2 (Far away 10km): (32.3200, 77.1890)
      final stopNearby = Stoppage(
        id: 'stop_nearby',
        tripId: 'trip_100',
        name: 'Mall Road Viewpoint',
        latitude: 32.2400,
        longitude: 77.1890,
        category: 'Scenic View',
        arrivedAt: DateTime.now(),
        createdBy: 'usr_me',
      );

      final stopFar = Stoppage(
        id: 'stop_far',
        tripId: 'trip_100',
        name: 'Solang Valley Stop',
        latitude: 32.3200,
        longitude: 77.1890,
        category: 'Adventure',
        arrivedAt: DateTime.now(),
        createdBy: 'usr_me',
      );

      service.evaluateStoppageArrivals(
        tripId: 'trip_100',
        myLat: 32.2396,
        myLng: 77.1887,
        activeStoppages: [stopNearby, stopFar],
        myMemberId: 'usr_me',
        myName: 'Arun',
      );

      // Only stopNearby should trigger arrival
      expect(service.alerts.length, equals(1));
      final arrivalAlert = service.alerts.first;
      expect(arrivalAlert.type, equals(AlertType.stoppageArrival));
      expect(arrivalAlert.title, equals('Arrived at Pitstop'));
      expect(arrivalAlert.message, contains('Mall Road Viewpoint'));
    });

    test('Emergency SOS alert broadcasts with critical urgency', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = await LocalStorageService.init(prefs: prefs, database: await AppDatabase.open(customPath: inMemoryDatabasePath));
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
        ],
      );

      final service = container.read(proximityAlertServiceProvider);

      await service.triggerEmergencySos(
        tripId: 'trip_100',
        memberId: 'usr_me',
        memberName: 'Arun',
        lat: 32.2396,
        lng: 77.1887,
        customNote: 'Vehicle breakdown near bend 4',
      );

      expect(service.alerts.length, equals(1));
      final sos = service.alerts.first;
      expect(sos.type, equals(AlertType.sosEmergency));
      expect(sos.urgency, equals(AlertUrgency.critical));
      expect(sos.message, contains('Vehicle breakdown near bend 4'));
      expect(sos.latitude, equals(32.2396));
      expect(sos.longitude, equals(77.1887));
    });
  });
}
