import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trip_tracker_app/core/database/app_database.dart';
import 'package:trip_tracker_app/core/services/firestore_sync_service.dart';
import 'package:trip_tracker_app/core/services/local_storage_service.dart';
import 'package:trip_tracker_app/core/services/offline_sync_engine.dart';
import 'package:trip_tracker_app/core/services/cloud_trip_sync_service.dart';
import 'package:trip_tracker_app/models/auth_user.dart';
import 'package:trip_tracker_app/models/trip.dart';
import 'package:trip_tracker_app/models/expense.dart';
import 'package:trip_tracker_app/models/proximity_alert.dart';
import 'package:trip_tracker_app/models/stoppage.dart';
import 'package:trip_tracker_app/models/sync_mutation.dart';
import 'package:trip_tracker_app/providers/trip_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('FirestoreSyncService & OfflineSyncEngine Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AppDatabase appDb;
    late LocalStorageService storage;
    late ProviderContainer container;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      final inMemDb = await databaseFactory.openDatabase(inMemoryDatabasePath);
      appDb = await AppDatabase.open(customDb: inMemDb);
      storage = await LocalStorageService.init(database: appDb);

      container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          firestoreSyncServiceProvider.overrideWith((ref) => FirestoreSyncService(ref, db: fakeFirestore)),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      appDb.database.close();
    });

    test('FirestoreSyncService pushes stoppage and expense to fake firestore', () async {
      final syncService = container.read(firestoreSyncServiceProvider);

      final stoppage = Stoppage(
        id: 'stop_test_001',
        tripId: 'trip_alpha_1',
        name: 'Grand Canyon Lookout',
        latitude: 36.0544,
        longitude: -112.1401,
        arrivedAt: DateTime.now(),
        category: 'scenic',
        createdBy: 'usr_1',
      );

      await syncService.pushStoppage(stoppage);

      // Verify in Firestore
      final snap = await fakeFirestore
          .collection('trips')
          .doc('trip_alpha_1')
          .collection('stoppages')
          .doc('stop_test_001')
          .get();

      expect(snap.exists, isTrue);
      expect(snap.data()!['name'], equals('Grand Canyon Lookout'));
      expect(snap.data()!['latitude'], equals(36.0544));

      // Push expense
      final expense = Expense(
        id: 'exp_test_001',
        tripId: 'trip_alpha_1',
        stoppageId: 'stop_test_001',
        title: 'National Park Pass',
        totalAmount: 35.00,
        currency: 'USD',
        category: 'tickets',
        paidByMemberId: 'member_arun',
        splitType: SplitType.equal,
        splits: [],
        createdAt: DateTime.now(),
      );

      await syncService.pushExpense(expense);

      final expSnap = await fakeFirestore
          .collection('trips')
          .doc('trip_alpha_1')
          .collection('expenses')
          .doc('exp_test_001')
          .get();

      expect(expSnap.exists, isTrue);
      expect(expSnap.data()!['title'], equals('National Park Pass'));
      expect(expSnap.data()!['totalAmount'], equals(35.0));
    });

    test('FirestoreSyncService pushes proximity & SOS alert to firestore', () async {
      final syncService = container.read(firestoreSyncServiceProvider);

      final alert = ProximityAlert(
        id: 'alert_sos_001',
        tripId: 'trip_alpha_1',
        type: AlertType.sosEmergency,
        title: 'EMERGENCY SOS',
        message: 'Need immediate roadside assistance!',
        senderMemberId: 'usr_me_001',
        senderName: 'Arun',
        latitude: 0,
        longitude: 0,
        timestamp: DateTime.now(),
        urgency: AlertUrgency.critical,
      );

      await syncService.pushProximityAlert(alert);

      final snap = await fakeFirestore
          .collection('trips')
          .doc('trip_alpha_1')
          .collection('proximity_alerts')
          .doc('alert_sos_001')
          .get();

      expect(snap.exists, isTrue);
      expect(snap.data()!['type'], equals('sosEmergency'));
      expect(snap.data()!['urgency'], equals('critical'));
    });

    test('FirestoreSyncService broadcasts location with throttled filtering', () async {
      final syncService = container.read(firestoreSyncServiceProvider);

      await syncService.broadcastLocation(
        'trip_alpha_1',
        'usr_me_001',
        28.6139,
        77.2090,
        speedKmh: 45.0,
        heading: 180.0,
      );

      final snap = await fakeFirestore
          .collection('trips')
          .doc('trip_alpha_1')
          .collection('member_locations')
          .doc('usr_me_001')
          .get();

      expect(snap.exists, isTrue);
      expect(snap.data()!['lat'], equals(28.6139));
      expect(snap.data()!['lng'], equals(77.2090));
      expect(snap.data()!['speedKmh'], equals(45.0));
    });

    test('OfflineSyncEngine flushes pending SQLite mutations to Firestore', () async {
      CloudTripSyncService.customDb = fakeFirestore;

      final trip = Trip(
        id: 'trip_alpha_1',
        title: 'Desert Route',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 3)),
        defaultCurrency: 'USD',
        members: const [],
        createdByMemberId: 'usr_1',
        createdAt: DateTime.now(),
      );
      await storage.saveTrip(trip);
      await storage.saveAuthSession(
        AuthUser(
          id: 'usr_1',
          username: 'user_one',
          displayName: 'User One',
          email: 'user1@example.com',
          provider: AuthProviderType.email,
          createdAt: DateTime.now(),
        ),
      );

      final engine = OfflineSyncEngine(storage);
      addTearDown(engine.dispose);

      // Enqueue a local offline mutation
      await engine.enqueueMutation(
        action: MutationAction.addStoppage,
        entityType: 'stoppages',
        entityId: 'stop_offline_77',
        tripId: 'trip_alpha_1',
        payload: {
          'id': 'stop_offline_77',
          'tripId': 'trip_alpha_1',
          'name': 'Desert Rest Area',
          'latitude': 35.1983,
          'longitude': -111.6513,
        },
        syncImmediately: false,
      );

      expect(engine.pendingCount, equals(1));

      // Flush mutations
      final success = await engine.syncPendingMutationsNow();
      expect(success, isTrue);
      expect(engine.pendingCount, equals(0));

      // Verify mutation arrived in fake Firestore
      final snap = await fakeFirestore
          .collection('trips')
          .doc('trip_alpha_1')
          .collection('stoppages')
          .doc('stop_offline_77')
          .get();

      expect(snap.exists, isTrue);
      expect(snap.data()!['name'], equals('Desert Rest Area'));
    });
  });
}
