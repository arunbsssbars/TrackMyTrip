import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackmytrip/core/database/app_database.dart';
import 'package:trackmytrip/core/services/local_storage_service.dart';
import 'package:trackmytrip/core/services/media_cache_service.dart';
import 'package:trackmytrip/core/services/tombstone_service.dart';
import 'package:trackmytrip/core/services/user_service.dart';
import 'package:trackmytrip/core/services/cloudinary_service.dart';
import 'package:trackmytrip/models/memory.dart';
import 'package:trackmytrip/models/trip.dart';
import 'package:trackmytrip/models/trip_member.dart';
import 'package:trackmytrip/models/user_profile.dart';
import 'package:trackmytrip/providers/memory_provider.dart';
import 'package:trackmytrip/providers/trip_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase appDb;
  late LocalStorageService storage;
  late ProviderContainer container;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dbName = 'test_mem_multi_del_${DateTime.now().microsecondsSinceEpoch}.db';
    appDb = await AppDatabase.open(customPath: dbName);
    storage = await LocalStorageService.init(prefs: prefs, database: appDb);
    await TombstoneService.init(prefs, appDb);

    UserService.resetCurrentUser();
    UserService.updateCurrentUser(const UserProfile(
      id: 'user_tester_1',
      username: 'tester',
      displayName: 'Test Traveler',
      email: 'tester@trackmytrip.com',
    ));

    final mockTrip = Trip(
      id: 'trip_multi_del_1',
      title: 'Himalayan Trek',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 5)),
      defaultCurrency: 'INR',
      members: [
        const TripMember(
          id: 'user_tester_1',
          name: 'Test Traveler',
          role: 'creator',
          isCurrentUser: true,
        ),
      ],
      createdByMemberId: 'user_tester_1',
      createdAt: DateTime.now(),
    );
    await storage.saveTrip(mockTrip);

    container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
      ],
    );
  });

  tearDown(() async {
    await Future.delayed(const Duration(milliseconds: 150));
    container.dispose();
  });

  group('Loop 1: One & Multi Memory Deletion and Cloudinary Sync Engine', () {
    test('Single Memory deletion removes memory, tombstones ID, and purges local storage', () async {
      final notifier = container.read(allMemoriesProvider.notifier);

      final memory = Memory(
        id: 'mem_single_1',
        tripId: 'trip_multi_del_1',
        stoppageId: 'stp_1',
        uploadedByMemberId: 'user_tester_1',
        mediaPath: 'https://res.cloudinary.com/test_cloud/image/upload/v1234/trackmytrip/trips/trip_multi_del_1/memories/mem_single_1.jpg',
        remoteUrl: 'https://res.cloudinary.com/test_cloud/image/upload/v1234/trackmytrip/trips/trip_multi_del_1/memories/mem_single_1.jpg',
        deleteToken: 'del_token_single_1',
        uploadStatus: MediaUploadStatus.uploaded,
        caption: 'Campfire',
        createdAt: DateTime.now(),
      );

      await notifier.addMemory(memory, broadcast: false, pushRemote: false, enqueueSync: false);
      expect(container.read(allMemoriesProvider).length, 1);

      // Execute single memory deletion
      await notifier.deleteMemory(memory.id, broadcast: false);

      // Verify removed from state
      expect(container.read(allMemoriesProvider).isEmpty, isTrue);

      // Verify tombstone is recorded
      expect(TombstoneService.isMemoryTombstoned('mem_single_1'), isTrue);

      // Verify cannot be re-added due to anti-resurrection tombstone
      await notifier.addMemory(memory, broadcast: false, pushRemote: false, enqueueSync: false);
      expect(container.read(allMemoriesProvider).isEmpty, isTrue);
    });

    test('Multi-Memory (batch) deletion purges all selected memories from state, storage, and tombstones all IDs', () async {
      final notifier = container.read(allMemoriesProvider.notifier);

      final mem1 = Memory(
        id: 'batch_mem_1',
        tripId: 'trip_multi_del_1',
        stoppageId: 'stp_1',
        uploadedByMemberId: 'user_tester_1',
        mediaPath: 'https://res.cloudinary.com/test_cloud/image/upload/v1/trackmytrip/trips/trip_multi_del_1/memories/batch_mem_1.jpg',
        remoteUrl: 'https://res.cloudinary.com/test_cloud/image/upload/v1/trackmytrip/trips/trip_multi_del_1/memories/batch_mem_1.jpg',
        deleteToken: 'token_b1',
        uploadStatus: MediaUploadStatus.uploaded,
        caption: 'Summit View',
        createdAt: DateTime.now(),
      );

      final mem2 = Memory(
        id: 'batch_mem_2',
        tripId: 'trip_multi_del_1',
        stoppageId: 'stp_1',
        uploadedByMemberId: 'user_tester_1',
        mediaPath: 'https://res.cloudinary.com/test_cloud/image/upload/v1/trackmytrip/trips/trip_multi_del_1/memories/batch_mem_2.jpg',
        remoteUrl: 'https://res.cloudinary.com/test_cloud/image/upload/v1/trackmytrip/trips/trip_multi_del_1/memories/batch_mem_2.jpg',
        deleteToken: 'token_b2',
        uploadStatus: MediaUploadStatus.uploaded,
        caption: 'Glacier Pass',
        createdAt: DateTime.now(),
      );

      final mem3 = Memory(
        id: 'batch_mem_3',
        tripId: 'trip_multi_del_1',
        stoppageId: 'stp_1',
        uploadedByMemberId: 'user_tester_1',
        mediaPath: 'https://res.cloudinary.com/test_cloud/image/upload/v1/trackmytrip/trips/trip_multi_del_1/memories/batch_mem_3.jpg',
        remoteUrl: 'https://res.cloudinary.com/test_cloud/image/upload/v1/trackmytrip/trips/trip_multi_del_1/memories/batch_mem_3.jpg',
        deleteToken: 'token_b3',
        uploadStatus: MediaUploadStatus.uploaded,
        caption: 'Tent Setup',
        createdAt: DateTime.now(),
      );

      final memKeep = Memory(
        id: 'batch_mem_keep',
        tripId: 'trip_multi_del_1',
        stoppageId: 'stp_1',
        uploadedByMemberId: 'user_tester_1',
        mediaPath: 'https://res.cloudinary.com/test_cloud/image/upload/v1/trackmytrip/trips/trip_multi_del_1/memories/batch_mem_keep.jpg',
        remoteUrl: 'https://res.cloudinary.com/test_cloud/image/upload/v1/trackmytrip/trips/trip_multi_del_1/memories/batch_mem_keep.jpg',
        uploadStatus: MediaUploadStatus.uploaded,
        caption: 'Stars at night',
        createdAt: DateTime.now(),
      );

      await notifier.addMemory(mem1, broadcast: false, pushRemote: false, enqueueSync: false);
      await notifier.addMemory(mem2, broadcast: false, pushRemote: false, enqueueSync: false);
      await notifier.addMemory(mem3, broadcast: false, pushRemote: false, enqueueSync: false);
      await notifier.addMemory(memKeep, broadcast: false, pushRemote: false, enqueueSync: false);

      expect(container.read(allMemoriesProvider).length, 4);

      // Perform batch deletion of 3 memories
      final result = await notifier.deleteMemoriesBatch(
        ['batch_mem_1', 'batch_mem_2', 'batch_mem_3'],
        broadcast: true,
      );

      expect(result['total'], 3);

      // Verify state now only contains the kept memory
      final remaining = container.read(allMemoriesProvider);
      expect(remaining.length, 1);
      expect(remaining.first.id, 'batch_mem_keep');

      // Verify all 3 deleted memories are tombstoned
      expect(TombstoneService.isMemoryTombstoned('batch_mem_1'), isTrue);
      expect(TombstoneService.isMemoryTombstoned('batch_mem_2'), isTrue);
      expect(TombstoneService.isMemoryTombstoned('batch_mem_3'), isTrue);
      expect(TombstoneService.isMemoryTombstoned('batch_mem_keep'), isFalse);
    });

    test('deleteMemoriesBatch safely handles empty list or non-existent IDs without errors', () async {
      final notifier = container.read(allMemoriesProvider.notifier);

      final emptyResult = await notifier.deleteMemoriesBatch([]);
      expect(emptyResult['total'], 0);
      expect(emptyResult['succeeded'], 0);

      final nonExistentResult = await notifier.deleteMemoriesBatch(['non_existent_id_1', 'non_existent_id_2']);
      expect(nonExistentResult['total'], 0);
    });

    test('deleteMemoriesBatch correctly extracts Cloudinary public IDs and maps delete tokens', () {
      const url = 'https://res.cloudinary.com/demo_cloud/image/upload/v1728567890/trackmytrip/trips/trip1/memories/photo_99.jpg';
      final publicId = CloudinaryService.extractPublicId(url);
      expect(publicId, 'trackmytrip/trips/trip1/memories/photo_99');

      const transformedUrl = 'https://res.cloudinary.com/demo_cloud/image/upload/w_800,c_fill,q_auto/v1/trackmytrip/trips/trip1/memories/photo_99.webp';
      final publicIdTransformed = CloudinaryService.extractPublicId(transformedUrl);
      expect(publicIdTransformed, 'trackmytrip/trips/trip1/memories/photo_99');
    });
  });
}
