import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackmytrip/core/database/app_database.dart';
import 'package:trackmytrip/core/services/local_storage_service.dart';
import 'package:trackmytrip/core/services/media_cache_service.dart';
import 'package:trackmytrip/core/services/proximity_alert_service.dart';
import 'package:trackmytrip/core/services/tombstone_service.dart';
import 'package:trackmytrip/core/services/user_service.dart';
import 'package:trackmytrip/core/utils/notification_formatter.dart';
import 'package:trackmytrip/models/memory.dart';
import 'package:trackmytrip/models/proximity_alert.dart';
import 'package:trackmytrip/models/trip.dart';
import 'package:trackmytrip/models/trip_member.dart';
import 'package:trackmytrip/models/user_profile.dart';
import 'package:trackmytrip/providers/memory_provider.dart';
import 'package:trackmytrip/providers/trip_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase appDb;
  late LocalStorageService storage;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Memory Deletion & Activity Alert Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dbName = 'test_mem_del_${DateTime.now().microsecondsSinceEpoch}.db';
      appDb = await AppDatabase.open(customPath: dbName);
      storage = await LocalStorageService.init(prefs: prefs, database: appDb);
      UserService.resetCurrentUser();
      UserService.updateCurrentUser(const UserProfile(
        id: 'user_tester_1',
        username: 'tester',
        displayName: 'Test Traveler',
        email: 'tester@trackmytrip.com',
      ));
    });

    test('Memory model properly serializes and deserializes deleteToken', () {
      final memory = Memory(
        id: 'mem_100',
        tripId: 'trip_100',
        stoppageId: 'stop_100',
        uploadedByMemberId: 'user_tester_1',
        mediaPath: 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
        remoteUrl: 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
        deleteToken: 'cloudinary_del_token_abc',
        uploadStatus: MediaUploadStatus.uploaded,
        caption: 'Mountain Summit',
        createdAt: DateTime.now(),
      );

      expect(memory.deleteToken, equals('cloudinary_del_token_abc'));

      final json = memory.toJson();
      expect(json['deleteToken'], equals('cloudinary_del_token_abc'));

      final fromJson = Memory.fromJson(json);
      expect(fromJson.deleteToken, equals('cloudinary_del_token_abc'));

      final copied = memory.copyWith(deleteToken: 'new_token_456');
      expect(copied.deleteToken, equals('new_token_456'));
    });

    test('MediaItem model correctly preserves deleteToken', () {
      final item = MediaItem(
        id: 'item_1',
        localPath: '/data/user/photo.jpg',
        remoteUrl: 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
        deleteToken: 'item_del_tok_123',
        status: MediaUploadStatus.uploaded,
        createdAt: DateTime.now(),
        entityType: 'memory',
        entityId: 'mem_100',
      );

      expect(item.deleteToken, equals('item_del_tok_123'));

      final json = item.toJson();
      expect(json['deleteToken'], equals('item_del_tok_123'));

      final reconstructed = MediaItem.fromJson(json);
      expect(reconstructed.deleteToken, equals('item_del_tok_123'));
    });

    test('NotificationFormatter formats memory deletion messages accurately', () {
      final alertSelf = ProximityAlert(
        id: 'alert_del_1',
        tripId: 'trip_1',
        type: AlertType.memoryDeleted,
        title: 'Memory Removed',
        message: 'Test Traveler removed memory "Mountain Summit"',
        senderMemberId: 'user_tester_1',
        senderName: 'Test Traveler',
        timestamp: DateTime.now(),
      );

      // Current user is the actor -> "You removed memory ..."
      final formattedSelf = NotificationFormatter.formatMessage(
        alertSelf,
        currentUserId: 'user_tester_1',
        currentUserName: 'Test Traveler',
      );
      expect(formattedSelf, equals('You removed memory "Mountain Summit"'));

      // Companion views the alert -> "Test Traveler removed memory ..."
      final formattedCompanion = NotificationFormatter.formatMessage(
        alertSelf,
        currentUserId: 'companion_user_2',
        currentUserName: 'Bob Companion',
      );
      expect(formattedCompanion, equals('Test Traveler removed memory "Mountain Summit"'));
    });

    test('deleteMemory removes memory, registers tombstone, and broadcasts AlertType.memoryDeleted', () async {
      final trip = Trip(
        id: 'trip_1',
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
      await storage.saveTrip(trip);

      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
        ],
      );

      final memoryNotifier = container.read(allMemoriesProvider.notifier);
      final alertService = container.read(proximityAlertServiceProvider);

      // Seed a memory into state
      final testMemory = Memory(
        id: 'mem_del_test_1',
        tripId: 'trip_1',
        stoppageId: 'stop_1',
        uploadedByMemberId: 'user_tester_1',
        mediaPath: 'https://res.cloudinary.com/testcloud/image/upload/sample.jpg',
        remoteUrl: 'https://res.cloudinary.com/testcloud/image/upload/sample.jpg',
        deleteToken: 'token_mem_test_del',
        caption: 'Campfire',
        createdAt: DateTime.now(),
        uploadStatus: MediaUploadStatus.uploaded,
      );

      await memoryNotifier.addMemory(testMemory, broadcast: false);
      expect(container.read(allMemoriesProvider).any((m) => m.id == 'mem_del_test_1'), isTrue);

      // Delete memory with broadcast true
      await memoryNotifier.deleteMemory('mem_del_test_1', broadcast: true);

      // Settle async notifications and mutations
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify removed from state
      expect(container.read(allMemoriesProvider).any((m) => m.id == 'mem_del_test_1'), isFalse);

      // Verify tombstone registered
      expect(TombstoneService.isMemoryTombstoned('mem_del_test_1'), isTrue);

      // Verify AlertType.memoryDeleted was broadcast into ProximityAlertService
      final broadcastedAlert = alertService.alerts.where((a) => a.type == AlertType.memoryDeleted).firstOrNull;
      expect(broadcastedAlert, isNotNull);
      expect(broadcastedAlert!.title, equals('Memory Removed'));
      expect(broadcastedAlert.message, contains('removed memory "Campfire"'));
      expect(broadcastedAlert.itemId, equals('mem_del_test_1'));

      container.dispose();
    });
  });
}
