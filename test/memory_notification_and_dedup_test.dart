import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/services/media_cache_service.dart';
import 'package:trackmytrip/core/services/tombstone_service.dart';
import 'package:trackmytrip/core/utils/notification_formatter.dart';
import 'package:trackmytrip/models/memory.dart';
import 'package:trackmytrip/models/proximity_alert.dart';

void main() {
  group('NotificationFormatter Title Normalization Tests', () {
    test('normalizes memory, bill, and stop alert titles by stripping "New "', () {
      final alertMemory = ProximityAlert(
        id: 'a1',
        tripId: 't1',
        type: AlertType.memoryAdded,
        title: 'New Memory Added',
        message: 'Arun added a memory photo',
        senderMemberId: 'u1',
        senderName: 'Arun',
        timestamp: DateTime.now(),
      );

      final alertBill = ProximityAlert(
        id: 'a2',
        tripId: 't1',
        type: AlertType.billAdded,
        title: 'New Bill Added',
        message: 'Arun added a dinner bill',
        senderMemberId: 'u1',
        senderName: 'Arun',
        timestamp: DateTime.now(),
      );

      final alertWaypoint = ProximityAlert(
        id: 'a3',
        tripId: 't1',
        type: AlertType.stoppageAdded,
        title: 'New Waypoint Added',
        message: 'Arun added stop "Hotel"',
        senderMemberId: 'u1',
        senderName: 'Arun',
        timestamp: DateTime.now(),
      );

      final alertStoppages = ProximityAlert(
        id: 'a4',
        tripId: 't1',
        type: AlertType.stoppageAdded,
        title: 'New Stoppages Added',
        message: 'Arun added stop "Viewpoint"',
        senderMemberId: 'u1',
        senderName: 'Arun',
        timestamp: DateTime.now(),
      );

      expect(NotificationFormatter.formatTitle(alertMemory, currentUserId: 'other'), 'Memory Added');
      expect(NotificationFormatter.formatTitle(alertBill, currentUserId: 'other'), 'Bill Added');
      expect(NotificationFormatter.formatTitle(alertWaypoint, currentUserId: 'other'), 'Stop Added');
      expect(NotificationFormatter.formatTitle(alertStoppages, currentUserId: 'other'), 'Stop Added');
    });

    test('retains SOS distress title when sender views it', () {
      final sosAlert = ProximityAlert(
        id: 'sos_1',
        tripId: 't1',
        type: AlertType.sosEmergency,
        title: 'EMERGENCY SOS',
        message: 'Arun triggered SOS',
        senderMemberId: 'u1',
        senderName: 'Arun',
        timestamp: DateTime.now(),
      );

      expect(NotificationFormatter.formatTitle(sosAlert, currentUserId: 'u1'), '🚨 SOS Distress Active');
    });

    test('converts SOS added to SOS Sent in activity card', () {
      final sosAddedAlert = ProximityAlert(
        id: 'sos_added_1',
        tripId: 't1',
        type: AlertType.sosEmergency,
        title: 'SOS Added',
        message: 'Arun added SOS',
        senderMemberId: 'u1',
        senderName: 'Arun',
        timestamp: DateTime.now(),
      );
      expect(NotificationFormatter.formatTitle(sosAddedAlert, currentUserId: 'u1'), 'SOS Sent');
      expect(NotificationFormatter.formatTitle(sosAddedAlert, currentUserId: 'other'), 'SOS Sent');
    });
  });

  group('Memory MediaUploadStatus Tests', () {
    test('Memory correctly preserves uploadStatus and localPath', () {
      final memory = Memory(
        id: 'mem_1',
        tripId: 'trip_1',
        stoppageId: 'stop_1',
        uploadedByMemberId: 'user_1',
        mediaPath: 'C:/Users/Arun/Pictures/sunset.jpg',
        localPath: 'C:/Users/Arun/Pictures/sunset.jpg',
        remoteUrl: 'https://firebasestorage.googleapis.com/...',
        caption: 'Sunset View',
        createdAt: DateTime.now(),
        uploadStatus: MediaUploadStatus.uploaded,
      );

      expect(memory.localPath, isNotNull);
      expect(memory.uploadStatus, MediaUploadStatus.uploaded);
      final json = memory.toJson();
      final rehydrated = Memory.fromJson(json);
      expect(rehydrated.uploadStatus, MediaUploadStatus.uploaded);
      expect(rehydrated.localPath, 'C:/Users/Arun/Pictures/sunset.jpg');
    });

    test('TombstoneService correctly marks and verifies memory tombstones', () async {
      const memId = 'mem_tombstone_test_1';
      expect(TombstoneService.isMemoryTombstoned(memId), isFalse);

      await TombstoneService.markMemoryTombstoned(memId);
      expect(TombstoneService.isMemoryTombstoned(memId), isTrue);
      expect(TombstoneService.getAllTombstonedMemoryIds().contains(memId), isTrue);
    });

    test('MediaCacheService registers and purges item via deleteForEntity', () async {
      final service = MediaCacheService();
      final item = service.register(
        localPath: 'test_path_1.jpg',
        entityType: 'memory',
        entityId: 'mem_entity_1',
      );

      expect(service.itemForEntity('mem_entity_1'), isNotNull);
      expect(service.itemForEntity('mem_entity_1')?.id, item.id);

      await service.deleteForEntity('mem_entity_1');
      expect(service.itemForEntity('mem_entity_1'), isNull);
    });
  });
}
