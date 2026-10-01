import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackmytrip/core/database/app_database.dart';
import 'package:trackmytrip/core/services/local_storage_service.dart';
import 'package:trackmytrip/core/services/offline_sync_engine.dart';
import 'package:trackmytrip/core/services/cloud_trip_sync_service.dart';
import 'package:trackmytrip/core/services/tombstone_service.dart';
import 'package:trackmytrip/models/auth_user.dart';
import 'package:trackmytrip/models/trip.dart';
import 'package:trackmytrip/models/sync_mutation.dart';
import 'package:trackmytrip/providers/trip_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('OfflineSyncEngine Resilience & Mutation Routing Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AppDatabase appDb;
    late LocalStorageService storage;
    late ProviderContainer container;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      CloudTripSyncService.customDb = fakeFirestore;

      final inMemDb = await databaseFactory.openDatabase(inMemoryDatabasePath);
      appDb = await AppDatabase.open(customDb: inMemDb);
      storage = await LocalStorageService.init(database: appDb);
      await TombstoneService.reload(appDb);

      container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await appDb.close();
    });

    test('Root trip entity updates route to trips/{tripId} rather than subcollections', () async {
      final trip = Trip(
        id: 'trip_root_1',
        title: 'Original Title',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 2)),
        defaultCurrency: 'USD',
        members: const [],
        createdByMemberId: 'usr_root',
        createdAt: DateTime.now(),
      );
      await storage.saveTrip(trip);
      await storage.saveAuthSession(
        AuthUser(
          id: 'usr_root',
          username: 'user_root',
          displayName: 'User Root',
          email: 'root@example.com',
          provider: AuthProviderType.email,
          createdAt: DateTime.now(),
        ),
      );

      final engine = OfflineSyncEngine(storage);
      addTearDown(engine.dispose);

      // Enqueue a root trip update mutation
      await engine.enqueueMutation(
        action: MutationAction.updateTrip,
        entityType: 'trip',
        entityId: 'trip_root_1',
        tripId: 'trip_root_1',
        payload: {
          'id': 'trip_root_1',
          'title': 'Updated Title Offline',
        },
        syncImmediately: false,
      );

      expect(engine.pendingCount, equals(1));

      final success = await engine.syncPendingMutationsNow();
      expect(success, isTrue);
      expect(engine.pendingCount, equals(0));

      // Verify the root document was updated in Firestore
      final snap = await fakeFirestore.collection('trips').doc('trip_root_1').get();
      expect(snap.exists, isTrue);
      expect(snap.data()!['title'], equals('Updated Title Offline'));
    });

    test('Root trip delete mutation deletes Firestore root doc and room', () async {
      await fakeFirestore.collection('trips').doc('trip_del_1').set({'title': 'To Delete'});
      await fakeFirestore.collection('rooms').doc('TRIP-9999').set({
        'code': 'TRIP-9999',
        'tripId': 'trip_del_1',
      });
      CloudTripSyncService.registerRoomCode('trip_del_1', 'TRIP-9999');

      await storage.saveAuthSession(
        AuthUser(
          id: 'usr_root',
          username: 'user_root',
          displayName: 'User Root',
          email: 'root@example.com',
          provider: AuthProviderType.email,
          createdAt: DateTime.now(),
        ),
      );

      final engine = OfflineSyncEngine(storage);
      addTearDown(engine.dispose);

      await engine.enqueueMutation(
        action: MutationAction.deleteTrip,
        entityType: 'trip',
        entityId: 'trip_del_1',
        tripId: 'trip_del_1',
        payload: {},
        syncImmediately: false,
      );

      expect(engine.pendingCount, equals(1));
      final success = await engine.syncPendingMutationsNow();
      expect(success, isTrue);
      expect(engine.pendingCount, equals(0));

      final snap = await fakeFirestore.collection('trips').doc('trip_del_1').get();
      expect(snap.exists, isFalse);
    });

    test('Tombstoned trips prune pending mutations and clear remote records', () async {
      await TombstoneService.markTombstoned('trip_tomb_1');
      await fakeFirestore.collection('trips').doc('trip_tomb_1').set({'title': 'Old Trip'});

      await storage.saveAuthSession(
        AuthUser(
          id: 'usr_root',
          username: 'user_root',
          displayName: 'User Root',
          email: 'root@example.com',
          provider: AuthProviderType.email,
          createdAt: DateTime.now(),
        ),
      );

      final engine = OfflineSyncEngine(storage);
      addTearDown(engine.dispose);

      await engine.enqueueMutation(
        action: MutationAction.addStoppage,
        entityType: 'stoppage',
        entityId: 'stop_orphan',
        tripId: 'trip_tomb_1',
        payload: {'name': 'Orphan Stop'},
        syncImmediately: false,
      );

      expect(engine.pendingCount, equals(1));
      final success = await engine.syncPendingMutationsNow();
      expect(success, isTrue);
      expect(engine.pendingCount, equals(0));

      final snap = await fakeFirestore.collection('trips').doc('trip_tomb_1').get();
      expect(snap.exists, isFalse);
    });

    test('Queue deduplication keeps the latest mutation for identical entities', () async {
      final engine = OfflineSyncEngine(storage);
      addTearDown(engine.dispose);

      final now = DateTime.now();
      final m1 = SyncMutation(
        id: 'mut_1',
        action: MutationAction.updateExpense,
        entityType: 'expense',
        entityId: 'exp_dup_1',
        tripId: 'trip_dup',
        payload: {'amount': 50.0},
        createdAt: now.subtract(const Duration(seconds: 10)),
      );
      final m2 = SyncMutation(
        id: 'mut_2',
        action: MutationAction.updateExpense,
        entityType: 'expense',
        entityId: 'exp_dup_1',
        tripId: 'trip_dup',
        payload: {'amount': 75.0},
        createdAt: now,
      );

      await storage.enqueueMutation(m1);
      await storage.enqueueMutation(m2);

      final mutations = storage.getPendingMutations();
      expect(mutations.length, equals(1));
      expect(mutations.first.payload['amount'], equals(75.0));
    });
  });
}
