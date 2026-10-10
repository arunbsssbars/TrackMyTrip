import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackmytrip/core/services/media_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaCacheService Offline Queue & Serialization Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('MediaItem serializes and deserializes to/from JSON cleanly', () {
      final now = DateTime.now();
      final original = MediaItem(
        id: 'test_id_123',
        localPath: '/local/test.jpg',
        remoteUrl: 'https://res.cloudinary.com/test/image/upload/test.jpg',
        status: MediaUploadStatus.uploaded,
        uploadProgress: 1.0,
        createdAt: now,
        entityType: 'memory',
        entityId: 'mem_xyz',
        tripId: 'trip_abc',
      );

      final json = original.toJson();
      final restored = MediaItem.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.localPath, equals(original.localPath));
      expect(restored.remoteUrl, equals(original.remoteUrl));
      expect(restored.status, equals(MediaUploadStatus.uploaded));
      expect(restored.uploadProgress, equals(1.0));
      expect(restored.entityType, equals('memory'));
      expect(restored.entityId, equals('mem_xyz'));
      expect(restored.tripId, equals('trip_abc'));
    });

    test('persistPendingQueue saves local/failed items and restorePendingQueue recovers them', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = MediaCacheService();

      // Register two local items
      service.register(
        localPath: '/tmp/local1.jpg',
        entityType: 'memory',
        entityId: 'mem_1',
        status: MediaUploadStatus.local,
      );
      service.register(
        localPath: '/tmp/local2.jpg',
        entityType: 'memory',
        entityId: 'mem_2',
        status: MediaUploadStatus.failed,
      );

      await service.persistPendingQueue(prefs: prefs);

      final savedJson = prefs.getString('cld_pending_media_queue');
      expect(savedJson, isNotNull);
      final decoded = jsonDecode(savedJson!) as List<dynamic>;
      expect(decoded.length, equals(2));

      // Create fresh service instance simulating app restart
      final newService = MediaCacheService();
      await newService.restorePendingQueue(prefs: prefs);

      expect(newService.allItems.length, equals(2));
      expect(newService.itemForEntity('mem_1'), isNotNull);
      expect(newService.itemForEntity('mem_2'), isNotNull);
    });

    test('deleteItem removes item from cache and persists updated queue', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = MediaCacheService();

      final item = service.register(
        localPath: '/tmp/local1.jpg',
        entityType: 'memory',
        entityId: 'mem_1',
        status: MediaUploadStatus.local,
      );

      await service.persistPendingQueue(prefs: prefs);
      expect(service.allItems.length, equals(1));

      await service.deleteItem(item.id);
      expect(service.allItems.isEmpty, isTrue);

      final savedJson = prefs.getString('cld_pending_media_queue');
      expect(savedJson, equals('[]'));
    });
  });
}
