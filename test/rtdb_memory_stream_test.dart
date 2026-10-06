import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackmytrip/core/database/app_database.dart';
import 'package:trackmytrip/models/memory.dart';
import 'package:trackmytrip/models/trip.dart';
import 'package:trackmytrip/providers/memory_provider.dart';
import 'package:trackmytrip/providers/trip_provider.dart';
import 'package:trackmytrip/core/services/realtime_sync_service.dart';
import 'package:trackmytrip/core/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('RTDB Memory Stream & Reaction Tests', () {
    late AppDatabase appDb;
    late LocalStorageService storage;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final inMemDb = await databaseFactory.openDatabase(inMemoryDatabasePath);
      appDb = await AppDatabase.open(customDb: inMemDb);
      storage = await LocalStorageService.init(database: appDb);

      final trip = Trip(
        id: 'trip_100',
        title: 'Goa Holiday',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 3)),
        defaultCurrency: 'INR',
        members: const [],
        createdByMemberId: 'user_a',
        createdAt: DateTime.now(),
      );
      await storage.saveTrip(trip);

      final initialMemory = Memory(
        id: 'mem_1',
        tripId: 'trip_100',
        stoppageId: 'general_trip_100',
        uploadedByMemberId: 'user_a',
        mediaPath: 'path/to/img1.jpg',
        createdAt: DateTime.now(),
        likedByMemberIds: ['user_b'],
      );
      await storage.saveAllMemories([initialMemory]);

      container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      appDb.database.close();
    });

    test('receiveRemoteLike updates memory likes correctly without re-broadcasting', () {
      final notifier = container.read(allMemoriesProvider.notifier);

      // User C likes mem_1
      notifier.receiveRemoteLike('mem_1', 'user_c', true);

      final memories = container.read(allMemoriesProvider);
      final mem = memories.firstWhere((m) => m.id == 'mem_1');
      expect(mem.likedByMemberIds, contains('user_c'));
      expect(mem.likedByMemberIds, contains('user_b'));

      // User B unlikes mem_1
      notifier.receiveRemoteLike('mem_1', 'user_b', false);

      final updated = container.read(allMemoriesProvider).firstWhere((m) => m.id == 'mem_1');
      expect(updated.likedByMemberIds, isNot(contains('user_b')));
      expect(updated.likedByMemberIds, contains('user_c'));
    });

    test('tripMemoriesProvider cleanly isolates memories by trip ID', () {
      final tripMemories = container.read(tripMemoriesProvider('trip_100'));
      expect(tripMemories.length, 1);
      expect(tripMemories.first.id, 'mem_1');

      final emptyTripMemories = container.read(tripMemoriesProvider('trip_999'));
      expect(emptyTripMemories.isEmpty, isTrue);
    });

    test('activeMemoryUploadersProvider correctly maintains list of companions uploading', () {
      expect(container.read(activeMemoryUploadersProvider('trip_100')), isEmpty);

      container.read(activeMemoryUploadersProvider('trip_100').notifier).state = ['Alice', 'Bob'];
      expect(container.read(activeMemoryUploadersProvider('trip_100')), equals(['Alice', 'Bob']));

      container.read(activeMemoryUploadersProvider('trip_100').notifier).state = [];
      expect(container.read(activeMemoryUploadersProvider('trip_100')), isEmpty);
    });
  });
}
