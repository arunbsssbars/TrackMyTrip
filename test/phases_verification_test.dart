import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_tracker_app/core/services/local_storage_service.dart';
import 'package:trip_tracker_app/core/services/user_service.dart';
import 'package:trip_tracker_app/core/services/media_cache_service.dart';
import 'package:trip_tracker_app/models/user_profile.dart';
import 'package:trip_tracker_app/models/sync_mutation.dart';
import 'package:trip_tracker_app/models/trip_audit_log.dart';
import 'package:trip_tracker_app/models/memory.dart';
import 'package:trip_tracker_app/models/expense.dart';
import 'package:trip_tracker_app/models/stoppage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1 Verification: User Identity & Companion Discovery', () {
    test('UserProfile serializes and deserializes correctly with @username', () {
      final profile = const UserProfile(
        id: 'usr_123',
        username: 'arun_explorer',
        displayName: 'Arun V',
        email: 'arun@example.com',
        phone: '+91 98765 43210',
        bio: 'Road trip enthusiast',
        colorHex: '#2563EB',
      );

      expect(profile.handle, equals('@arun_explorer'));

      final json = profile.toJson();
      final revived = UserProfile.fromJson(json);

      expect(revived.id, equals('usr_123'));
      expect(revived.username, equals('arun_explorer'));
      expect(revived.handle, equals('@arun_explorer'));
      expect(revived.displayName, equals('Arun V'));
    });

    test('UserService searches mock companion directory by @username and display name', () async {
      // Search with '@'
      final results1 = await UserService.searchUsers('@sarah');
      expect(results1, isNotEmpty);
      expect(results1.first.username, equals('sarah_travels'));

      // Search without '@'
      final results2 = await UserService.searchUsers('mike');
      expect(results2, isNotEmpty);
      expect(results2.first.displayName, contains('Mike'));

      // Search non-existent
      final results3 = await UserService.searchUsers('nonexistent_person_xyz');
      expect(results3, isEmpty);
    });
  });

  group('Phase 2 Verification: Real-Time Sync Event Serialization', () {
    test('Events payload serialization for WebSocket rooms', () {
      // Stoppage event payload
      final stoppage = Stoppage(
        id: 'stp_1',
        tripId: 'trp_1',
        name: 'Solang Valley Viewpoint',
        latitude: 32.3166,
        longitude: 77.1578,
        category: 'Scenic View',
        arrivedAt: DateTime(2026, 9, 4, 10, 30),
        createdBy: 'usr_1',
      );
      final stopJson = stoppage.toJson();
      expect(stopJson['name'], equals('Solang Valley Viewpoint'));
      expect(stopJson['createdBy'], equals('usr_1'));

      // Expense event payload
      final expense = Expense(
        id: 'exp_1',
        tripId: 'trp_1',
        title: 'Highway Dhaba Lunch',
        totalAmount: 1450.0,
        currency: 'INR',
        category: 'Food & Dining',
        paidByMemberId: 'usr_1',
        splitType: SplitType.equal,
        splits: [],
        createdAt: DateTime(2026, 9, 4, 13, 15),
      );
      final expJson = expense.toJson();
      expect(expJson['totalAmount'], equals(1450.0));
      expect(expJson['category'], equals('Food & Dining'));
    });
  });

  group('Phase 3 Verification: Offline SQLite Outbox Mutation Queue', () {
    test('Mutations can be enqueued, retrieved, and removed in LocalStorageService', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      expect(storage.getPendingMutations(), isEmpty);

      final mutation1 = SyncMutation(
        id: 'mut_101',
        action: MutationAction.addExpense,
        entityType: 'expense',
        entityId: 'exp_101',
        tripId: 'trip_100',
        payload: {'title': 'Mountain Toll', 'amount': 120.0},
        createdAt: DateTime.now(),
        status: SyncStatus.pending,
      );

      final mutation2 = SyncMutation(
        id: 'mut_102',
        action: MutationAction.addStoppage,
        entityType: 'stoppage',
        entityId: 'stp_102',
        tripId: 'trip_100',
        payload: {'name': 'Tea Stall'},
        createdAt: DateTime.now(),
        status: SyncStatus.pending,
      );

      await storage.enqueueMutation(mutation1);
      await storage.enqueueMutation(mutation2);

      final pending = storage.getPendingMutations();
      expect(pending.length, equals(2));
      expect(pending[0].id, equals('mut_101'));
      expect(pending[1].id, equals('mut_102'));

      // Remove synced mutation
      await storage.removeMutation('mut_101');
      final remaining = storage.getPendingMutations();
      expect(remaining.length, equals(1));
      expect(remaining[0].id, equals('mut_102'));
    });
  });

  group('Phase 4 Verification: S3-Compatible Media & Receipt Cache', () {
    test('Memory model tracks uploadStatus, localPath, and remoteUrl', () {
      final memLocal = Memory(
        id: 'mem_1',
        tripId: 'trip_1',
        stoppageId: 'stp_1',
        uploadedByMemberId: 'usr_1',
        mediaPath: '/data/user/0/com.example.triptracker/trip_media/photo1.jpg',
        localPath: '/data/user/0/com.example.triptracker/trip_media/photo1.jpg',
        uploadStatus: MediaUploadStatus.local,
        createdAt: DateTime.now(),
      );

      expect(memLocal.isUserPhoto, isTrue);
      expect(memLocal.displayPath, equals('/data/user/0/com.example.triptracker/trip_media/photo1.jpg'));

      final json = memLocal.toJson();
      expect(json['uploadStatus'], equals('local'));

      // Simulate cloud upload completion
      final memUploaded = memLocal.copyWith(
        remoteUrl: 'https://s3.ap-south-1.amazonaws.com/trip-bucket/photo1.jpg',
        uploadStatus: MediaUploadStatus.uploaded,
      );
      expect(memUploaded.displayPath, equals('https://s3.ap-south-1.amazonaws.com/trip-bucket/photo1.jpg'));
      expect(memUploaded.uploadStatus, equals(MediaUploadStatus.uploaded));
    });

    test('MediaCacheService registers and tracks media items', () {
      final cacheService = MediaCacheService();

      final item = cacheService.register(
        localPath: '/local/test_receipt.jpg',
        entityType: 'receipt',
        entityId: 'exp_999',
      );

      expect(item.entityId, equals('exp_999'));
      expect(item.isLocal, isTrue);
      expect(cacheService.itemForEntity('exp_999'), isNotNull);
    });
  });

  group('Phase 5 Verification: User Profile & Traveler Persona Switcher', () {
    test('Updating current user switches persona and author identity', () {
      final defaultUser = UserService.getCurrentUser();
      expect(defaultUser.id, isNotEmpty);

      // Switch persona to Sarah
      final sarah = const UserProfile(
        id: 'usr_sarah_101',
        username: 'sarah_travels',
        displayName: 'Sarah Jenkins',
        email: 'sarah.j@example.com',
        colorHex: '0xFFEC4899',
      );
      UserService.updateCurrentUser(sarah);

      final currentUser = UserService.getCurrentUser();
      expect(currentUser.username, equals('sarah_travels'));
      expect(currentUser.displayName, equals('Sarah Jenkins'));
      expect(currentUser.handle, equals('@sarah_travels'));

      // Restore default user
      UserService.updateCurrentUser(defaultUser);
      expect(UserService.getCurrentUser().id, equals(defaultUser.id));
    });
  });

  group('Phase 6 Verification: Live Activity Feed & Audit Trail', () {
    test('TripAuditLog categorizes activities and serializes properly', () {
      final expLog = TripAuditLog(
        id: 'log_1',
        tripId: 'trip_1',
        actionType: 'create_expense',
        itemTitle: 'Fuel Refill',
        performedByMemberId: 'usr_1',
        performedByName: 'Arun',
        timestamp: DateTime.now(),
        changeDetails: 'Logged 45L Diesel',
      );
      expect(expLog.category, equals('expense'));

      final stopLog = TripAuditLog(
        id: 'log_2',
        tripId: 'trip_1',
        actionType: 'create_stoppage',
        itemTitle: 'Viewpoint',
        performedByMemberId: 'usr_1',
        performedByName: 'Arun',
        timestamp: DateTime.now(),
      );
      expect(stopLog.category, equals('stoppage'));

      final memLog = TripAuditLog(
        id: 'log_3',
        tripId: 'trip_1',
        actionType: 'add_memory',
        itemTitle: 'Sunset over hills',
        performedByMemberId: 'usr_1',
        performedByName: 'Arun',
        timestamp: DateTime.now(),
      );
      expect(memLog.category, equals('memory'));

      final setLog = TripAuditLog(
        id: 'log_4',
        tripId: 'trip_1',
        actionType: 'create_settlement',
        itemTitle: 'Payment to Sarah',
        performedByMemberId: 'usr_1',
        performedByName: 'Arun',
        timestamp: DateTime.now(),
      );
      expect(setLog.category, equals('settlement'));

      final json = expLog.toJson();
      final revived = TripAuditLog.fromJson(json);
      expect(revived.itemTitle, equals('Fuel Refill'));
      expect(revived.category, equals('expense'));
    });
  });
}
