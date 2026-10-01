import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackmytrip/core/database/app_database.dart';
import 'package:trackmytrip/core/services/local_storage_service.dart';
import 'package:trackmytrip/core/services/proximity_alert_service.dart';
import 'package:trackmytrip/core/services/realtime_sync_service.dart';
import 'package:trackmytrip/core/services/user_service.dart';
import 'package:trackmytrip/models/proximity_alert.dart';
import 'package:trackmytrip/models/stoppage.dart';
import 'package:trackmytrip/models/trip.dart';
import 'package:trackmytrip/models/trip_member.dart';
import 'package:trackmytrip/providers/stoppage_provider.dart';
import 'package:trackmytrip/providers/trip_provider.dart';

class MockRealtimeSyncService extends RealtimeSyncService {
  MockRealtimeSyncService(super.ref);

  final List<Stoppage> updatedStoppagesBroadcasted = [];
  final List<Map<String, String>> deletedStoppagesBroadcasted = [];

  @override
  void broadcastUpdateStoppage(Stoppage stoppage) {
    updatedStoppagesBroadcasted.add(stoppage);
  }

  @override
  void broadcastDeleteStoppage(String tripId, String stoppageId) {
    deletedStoppagesBroadcasted.add({'tripId': tripId, 'stoppageId': stoppageId});
  }
}

class MockTripNotifier extends StateNotifier<List<Trip>> implements TripNotifier {
  MockTripNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase appDb;
  late LocalStorageService storage;
  late Trip testTrip;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dbName = 'test_db_${DateTime.now().microsecondsSinceEpoch}.db';
    appDb = await AppDatabase.open(customPath: dbName);
    storage = await LocalStorageService.init(prefs: prefs, database: appDb);

    final currentUser = UserService.getCurrentUser();
    testTrip = Trip(
      id: 'trip_100',
      title: 'Convoy Roadtrip',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 3)),
      defaultCurrency: 'INR',
      tripType: 'group',
      members: [
        TripMember(id: currentUser.id, name: currentUser.displayName, isCurrentUser: true),
        const TripMember(id: 'usr_sarah', name: 'Sarah'),
        const TripMember(id: 'usr_other', name: 'Other Companion'),
      ],
      createdByMemberId: currentUser.id,
      createdAt: DateTime.now(),
    );
    await storage.saveTrips([testTrip]);
  });

  group('Banner Muting & Silent Activity Hub Ingestion', () {
    test('Turning off in-app banners suppresses banner stream for regular alerts while pushing to alerts list', () async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          tripListProvider.overrideWith((ref) => MockTripNotifier([testTrip])),
        ],
      );

      final service = container.read(proximityAlertServiceProvider);

      // Disable in-app banners
      service.toggleInAppBanners(false);
      expect(service.inAppBannersEnabled, isFalse);

      final emittedBanners = <ProximityAlert>[];
      final subscription = service.bannerStream.listen((alert) {
        emittedBanners.add(alert);
      });

      // Ingest a standard bill notification from a companion
      final billAlert = ProximityAlert(
        id: 'bill_alert_01',
        tripId: 'trip_100',
        type: AlertType.billAdded,
        title: 'New Expense Added',
        message: 'Sarah added Dinner bill',
        senderMemberId: 'usr_sarah',
        senderName: 'Sarah',
        timestamp: DateTime.now(),
        urgency: AlertUrgency.normal,
      );

      await service.ingestRemoteAlert(billAlert);

      // Wait a tick for streams to flush
      await Future.delayed(const Duration(milliseconds: 50));

      // Assert banner stream did NOT emit anything
      expect(emittedBanners, isEmpty);

      // Assert alert was silently stored and is available in Activity tab feed
      expect(service.alerts.any((a) => a.id == 'bill_alert_01'), isTrue);

      await subscription.cancel();
    });

    test('Critical SOS Emergency alert bypasses banner mute for convoy safety', () async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          tripListProvider.overrideWith((ref) => MockTripNotifier([testTrip])),
        ],
      );

      final service = container.read(proximityAlertServiceProvider);
      service.toggleInAppBanners(false);
      expect(service.inAppBannersEnabled, isFalse);

      final emittedBanners = <ProximityAlert>[];
      final subscription = service.bannerStream.listen((alert) {
        emittedBanners.add(alert);
      });

      final sosAlert = ProximityAlert(
        id: 'sos_alert_01',
        tripId: 'trip_100',
        type: AlertType.sosEmergency,
        title: 'EMERGENCY SOS',
        message: 'Vehicle breakdown near valley',
        senderMemberId: 'usr_sarah',
        senderName: 'Sarah',
        timestamp: DateTime.now(),
        urgency: AlertUrgency.critical,
      );

      await service.ingestRemoteAlert(sosAlert);
      await Future.delayed(const Duration(milliseconds: 50));

      // SOS must safely bypass banner mute
      expect(emittedBanners.length, equals(1));
      expect(emittedBanners.first.id, equals('sos_alert_01'));
      expect(service.alerts.any((a) => a.id == 'sos_alert_01'), isTrue);

      await subscription.cancel();
    });

    test('Enabling banners allows regular alerts to emit on banner stream', () async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          tripListProvider.overrideWith((ref) => MockTripNotifier([testTrip])),
        ],
      );

      final service = container.read(proximityAlertServiceProvider);
      service.toggleInAppBanners(true);
      expect(service.inAppBannersEnabled, isTrue);

      final emittedBanners = <ProximityAlert>[];
      final subscription = service.bannerStream.listen((alert) {
        emittedBanners.add(alert);
      });

      final stopAlert = ProximityAlert(
        id: 'stop_alert_01',
        tripId: 'trip_100',
        type: AlertType.stoppageAdded,
        title: 'New Stop Added',
        message: 'Cafe added to route',
        senderMemberId: 'usr_sarah',
        senderName: 'Sarah',
        timestamp: DateTime.now(),
      );

      await service.ingestRemoteAlert(stopAlert);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(emittedBanners.length, equals(1));
      expect(emittedBanners.first.id, equals('stop_alert_01'));

      await subscription.cancel();
    });
  });

  group('RTDB Stoppage Route Synchronization', () {
    test('updateStoppage broadcasts update over RTDB sync service', () async {
      late MockRealtimeSyncService mockRtdb;
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          tripListProvider.overrideWith((ref) => MockTripNotifier([testTrip])),
          realtimeSyncServiceProvider.overrideWith((ref) {
            mockRtdb = MockRealtimeSyncService(ref);
            return mockRtdb;
          }),
        ],
      );

      final initialStop = Stoppage(
        id: 'stop_101',
        tripId: 'trip_100',
        name: 'Petrol Pump',
        latitude: 28.5000,
        longitude: 77.2000,
        category: 'Fuel',
        arrivedAt: DateTime.now(),
        createdBy: 'usr_arun',
      );

      await container.read(allStoppagesProvider.notifier).addStoppage(initialStop, broadcast: false);
      expect(container.read(allStoppagesProvider).length, equals(1));

      // Now update the stoppage coordinates / name
      final updatedStop = initialStop.copyWith(
        name: 'Petrol Pump & Quick Mart',
        latitude: 28.5050,
      );

      await container.read(allStoppagesProvider.notifier).updateStoppage(updatedStop, broadcast: true);

      // Verify state was updated
      final stateStops = container.read(allStoppagesProvider);
      expect(stateStops.first.name, equals('Petrol Pump & Quick Mart'));
      expect(stateStops.first.latitude, equals(28.5050));

      // Verify RTDB broadcast was triggered
      expect(mockRtdb.updatedStoppagesBroadcasted.length, equals(1));
      expect(mockRtdb.updatedStoppagesBroadcasted.first.id, equals('stop_101'));
      expect(mockRtdb.updatedStoppagesBroadcasted.first.name, equals('Petrol Pump & Quick Mart'));

      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('deleteStoppage broadcasts deletion over RTDB sync service', () async {
      late MockRealtimeSyncService mockRtdb;
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          tripListProvider.overrideWith((ref) => MockTripNotifier([testTrip])),
          realtimeSyncServiceProvider.overrideWith((ref) {
            mockRtdb = MockRealtimeSyncService(ref);
            return mockRtdb;
          }),
        ],
      );

      final stop = Stoppage(
        id: 'stop_102',
        tripId: 'trip_100',
        name: 'Coffee Shop',
        latitude: 28.5100,
        longitude: 77.2100,
        category: 'Food',
        arrivedAt: DateTime.now(),
        createdBy: 'usr_arun',
      );

      await container.read(allStoppagesProvider.notifier).addStoppage(stop, broadcast: false);
      expect(container.read(allStoppagesProvider).length, equals(1));

      // Delete the stoppage
      await container.read(allStoppagesProvider.notifier).deleteStoppage('stop_102', broadcast: true);

      // Verify state was removed
      expect(container.read(allStoppagesProvider), isEmpty);

      // Verify RTDB deletion broadcast was triggered
      expect(mockRtdb.deletedStoppagesBroadcasted.length, equals(1));
      expect(mockRtdb.deletedStoppagesBroadcasted.first['stoppageId'], equals('stop_102'));
      expect(mockRtdb.deletedStoppagesBroadcasted.first['tripId'], equals('trip_100'));

      await Future.delayed(const Duration(milliseconds: 50));
    });
  });
}
