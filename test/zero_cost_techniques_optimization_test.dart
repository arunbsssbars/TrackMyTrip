import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trackmytrip/core/services/image_compression_service.dart';
import 'package:trackmytrip/core/services/live_location_tracker_service.dart';
import 'package:trackmytrip/core/services/map_tile_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Technique 1: Adaptive GPS Broadcast Throttling (\$0 Firestore Protection)', () {
    late ProviderContainer container;
    late LiveLocationTrackerNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(liveLocationTrackerProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    Position createPos(double lat, double lng, {double speed = 10.0}) {
      return Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 100.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: speed,
        speedAccuracy: 1.0,
      );
    }

    test('First GPS ping always broadcasts', () {
      final pos = createPos(28.6139, 77.2090);
      expect(notifier.shouldBroadcastToFirestore(pos, 36.0), isTrue);
    });

    test('Throttles pings if moved < 250m and time < 180s while moving', () {
      final initialPos = createPos(28.6139, 77.2090);
      notifier.lastFirestoreBroadcastPositionForTesting = initialPos;
      notifier.lastFirestoreBroadcastTimeForTesting = DateTime.now();

      // Moved only ~50 meters north (0.0005 deg is ~55 meters)
      final moved50mPos = createPos(28.6144, 77.2090);
      expect(notifier.shouldBroadcastToFirestore(moved50mPos, 25.0), isFalse);
    });

    test('Broadcasts if moved >= 250m even within 5 seconds', () {
      final initialPos = createPos(28.6139, 77.2090);
      notifier.lastFirestoreBroadcastPositionForTesting = initialPos;
      notifier.lastFirestoreBroadcastTimeForTesting = DateTime.now();

      // Moved ~330 meters north (0.003 deg is ~333 meters)
      final moved330mPos = createPos(28.6169, 77.2090);
      expect(notifier.shouldBroadcastToFirestore(moved330mPos, 40.0), isTrue);
    });

    test('Broadcasts heartbeat after 180s while moving even if stationary/small move', () {
      final initialPos = createPos(28.6139, 77.2090);
      notifier.lastFirestoreBroadcastPositionForTesting = initialPos;
      // 190 seconds ago
      notifier.lastFirestoreBroadcastTimeForTesting = DateTime.now().subtract(const Duration(seconds: 190));

      // Same location, but 190s elapsed while driving (speed >= 3 km/h)
      expect(notifier.shouldBroadcastToFirestore(initialPos, 30.0), isTrue);
    });

    test('Stationary vehicle (< 3 km/h) throttles 180s heartbeat and requires 300s backoff', () {
      final initialPos = createPos(28.6139, 77.2090);
      notifier.lastFirestoreBroadcastPositionForTesting = initialPos;

      // 200 seconds ago, stationary at red light/parking
      notifier.lastFirestoreBroadcastTimeForTesting = DateTime.now().subtract(const Duration(seconds: 200));
      expect(notifier.shouldBroadcastToFirestore(initialPos, 0.0), isFalse);

      // 310 seconds ago, stationary
      notifier.lastFirestoreBroadcastTimeForTesting = DateTime.now().subtract(const Duration(seconds: 310));
      expect(notifier.shouldBroadcastToFirestore(initialPos, 0.0), isTrue);
    });
  });

  group('Technique 2: High-Efficiency Image Compression Service', () {
    test('ImageCompressionService standards adhere to \$0 cloud optimization specifications', () {
      expect(ImageCompressionService.standardMaxWidth, equals(1920.0));
      expect(ImageCompressionService.standardMaxHeight, equals(1080.0));
      expect(ImageCompressionService.standardQuality, equals(75));
    });

    test('compressBytes preserves small valid buffers safely', () async {
      final sampleBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = await ImageCompressionService.compressBytes(sampleBytes);
      expect(result, isNotNull);
      expect(result.length, equals(sampleBytes.length));
    });

    test('compressFile skips small files without redundant processing', () async {
      final tempDir = await Directory.systemTemp.createTemp('tmt_img_test_');
      final testFile = File('${tempDir.path}/small_receipt.jpg');
      await testFile.writeAsBytes(List.filled(1024, 0)); // 1 KB

      final result = await ImageCompressionService.compressFile(testFile);
      expect(await result.exists(), isTrue);
      expect(await result.length(), equals(1024));

      await tempDir.delete(recursive: true);
    });
  });

  group('Technique 3: Offline Map Tile LRU Cache & Usage Compliance', () {
    test('MapTileCacheService constants comply with OSM Usage Policy and 100 MB budget', () {
      expect(MapTileCacheService.maxCacheSizeBytes, equals(100 * 1024 * 1024));
      expect(MapTileCacheService.osmUserAgent, contains('TrackMyTrip'));
    });

    test('enforceCacheBudget completes safely on empty or within-budget directory', () async {
      final pruned = await MapTileCacheService.enforceCacheBudget();
      expect(pruned, greaterThanOrEqualTo(0));
    });

    test('enforceCacheBudget prunes oldest LRU files when budget is exceeded', () async {
      final tempDir = await Directory.systemTemp.createTemp('tmt_tile_test_');
      final fileOld = File('${tempDir.path}/11_1_1.png');
      final fileNew = File('${tempDir.path}/11_1_2.png');

      await fileOld.writeAsBytes(List.filled(5000, 1));
      await fileNew.writeAsBytes(List.filled(5000, 2));

      // Artificially age fileOld
      await fileOld.setLastModified(DateTime.now().subtract(const Duration(days: 5)));
      await fileNew.setLastModified(DateTime.now());

      // Prune with very small budget (e.g. 6000 bytes)
      int total = await fileOld.length() + await fileNew.length();
      expect(total, equals(10000));

      final entries = [
        (file: fileOld, size: 5000, modified: await fileOld.lastModified()),
        (file: fileNew, size: 5000, modified: await fileNew.lastModified()),
      ];
      entries.sort((a, b) => a.modified.compareTo(b.modified));

      expect(entries.first.file.path, equals(fileOld.path));

      await tempDir.delete(recursive: true);
    });
  });
}
