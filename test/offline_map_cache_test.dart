import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trackmytrip/core/services/map_tile_cache_service.dart';

void main() {
  group('Offline Map Cache & Tile Provider Verification Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('osm_tile_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('OfflineCachedTileProvider returns FileImage when tile is cached on disk (even when network is available)', () async {
      final cachePath = tempDir.path;
      final provider = OfflineCachedTileProvider(localCachePath: cachePath);

      // Create a mock downloaded tile on disk at z=13, x=1300, y=3100
      final tileFile = File('$cachePath/13/1300/3100.png');
      await tileFile.parent.create(recursive: true);
      // Write dummy PNG payload > 500 bytes
      final dummyBytes = List<int>.filled(1024, 0xFF);
      await tileFile.writeAsBytes(dummyBytes);

      expect(tileFile.existsSync(), isTrue);
      expect(tileFile.lengthSync(), greaterThan(500));

      const coords = TileCoordinates(1300, 3100, 13);
      final tileLayer = TileLayer(
        urlTemplate: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.trackmytrip.app',
      );

      final imageProvider = provider.getImage(coords, tileLayer);

      // VERIFICATION: Provider returns FileImage, bypassing network entirely!
      expect(imageProvider, isA<FileImage>());
      final fileImage = imageProvider as FileImage;
      expect(fileImage.file.path, equals(tileFile.path));
    });

    test('OfflineCachedTileProvider falls back to NetworkImage when tile is missing from disk', () {
      final cachePath = tempDir.path;
      final provider = OfflineCachedTileProvider(localCachePath: cachePath);

      // Request coordinates for a tile that does NOT exist locally
      const coords = TileCoordinates(9999, 8888, 12);
      final tileLayer = TileLayer(
        urlTemplate: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.trackmytrip.app',
      );

      final imageProvider = provider.getImage(coords, tileLayer);

      // VERIFICATION: Provider falls back to NetworkImage for streaming
      expect(imageProvider, isA<NetworkImage>());
      final networkImage = imageProvider as NetworkImage;
      expect(networkImage.url, contains('12/9999/8888.png'));
      expect(networkImage.headers?['User-Agent'], contains('TrackMyTrip'));
    });

    test('OfflineCachedTileProvider rejects corrupt/empty (<500 bytes) tiles and falls back to NetworkImage', () async {
      final cachePath = tempDir.path;
      final provider = OfflineCachedTileProvider(localCachePath: cachePath);

      // Create an invalid/error HTML tile (< 500 bytes)
      final tileFile = File('$cachePath/14/2000/4000.png');
      await tileFile.parent.create(recursive: true);
      await tileFile.writeAsBytes([0x00, 0x01, 0x02]); // 3 bytes only

      const coords = TileCoordinates(2000, 4000, 14);
      final tileLayer = TileLayer(
        urlTemplate: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
      );

      final imageProvider = provider.getImage(coords, tileLayer);

      // VERIFICATION: Corrupt tile rejected, safely falls back to network
      expect(imageProvider, isA<NetworkImage>());
    });

    test('calculateTileCoordinates computes valid bounding box tile set for route points', () {
      final points = [
        const LatLng(36.6002, -121.8947), // Monterey
        const LatLng(36.2704, -121.8081), // Big Sur
      ];

      final tiles = MapTileCacheService.calculateTileCoordinates(
        points: points,
        zoomLevels: [12, 13],
        margin: 0.02,
        maxTiles: 100,
      );

      expect(tiles.isNotEmpty, isTrue);
      expect(tiles.length, lessThanOrEqualTo(100));
      for (final t in tiles) {
        expect([12, 13], contains(t.z));
        expect(t.x, greaterThan(0));
        expect(t.y, greaterThan(0));
      }
    });
  });
}
