import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

class TileDownloadProgress {
  final int downloaded;
  final int total;
  final double percentage;
  final bool isCompleted;
  final String? error;

  const TileDownloadProgress({
    required this.downloaded,
    required this.total,
    required this.percentage,
    this.isCompleted = false,
    this.error,
  });
}

class MapTileCacheService {
  static Directory? _cacheDir;

  /// 100 MB standard LRU disk storage budget
  static const int maxCacheSizeBytes = 100 * 1024 * 1024;

  /// Standard OSM User-Agent per OpenStreetMap Foundation usage policy
  static const String osmUserAgent = 'TrackMyTrip/1.0 (https://trackmytrip.app; support@trackmytrip.app)';

  /// Enforces LRU disk storage budget by pruning oldest accessed tiles when size exceeds budget
  static Future<int> enforceCacheBudget({int budgetBytes = maxCacheSizeBytes}) async {
    try {
      final dir = await getCacheDirectory();
      if (!await dir.exists()) return 0;

      final tileEntries = <({File file, int size, DateTime modified})>[];
      int totalBytes = 0;

      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.png')) {
          try {
            final stat = await entity.stat();
            tileEntries.add((file: entity, size: stat.size, modified: stat.modified));
            totalBytes += stat.size;
          } catch (_) {}
        }
      }

      if (totalBytes <= budgetBytes) {
        return 0; // Within budget
      }

      // Sort by modified ascending (oldest first - LRU)
      tileEntries.sort((a, b) => a.modified.compareTo(b.modified));

      final targetSize = (budgetBytes * 0.85).round(); // Target 85% of budget to provide headroom
      int prunedCount = 0;

      for (final entry in tileEntries) {
        if (totalBytes <= targetSize) break;
        try {
          await entry.file.delete();
          totalBytes -= entry.size;
          prunedCount++;
        } catch (_) {}
      }

      return prunedCount;
    } catch (_) {
      return 0;
    }
  }

  /// Deletes legacy cache folders that contain 403 blocked, 404, or API-key watermarked tiles
  static Future<void> purgeLegacyCache() async {
    try {
      final baseDir = await getApplicationDocumentsDirectory();
      for (final legacy in [
        'offline_osm_tiles_v2',
        'offline_osm_tiles_v1',
        'offline_carto_tiles_v1',
        'offline_carto_tiles',
        'offline_map_tiles',
        'offline_tiles',
        'map_tiles',
      ]) {
        final dir = Directory('${baseDir.path}/$legacy');
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    } catch (_) {}
  }

  static Future<Directory> getCacheDirectory() async {
    if (_cacheDir != null) return _cacheDir!;
    await purgeLegacyCache();
    final baseDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${baseDir.path}/offline_osm_tiles_v3');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  /// Converts Longitude to OSM Tile X
  static int lon2tile(double lon, int zoom) {
    return ((lon + 180.0) / 360.0 * (1 << zoom)).floor();
  }

  /// Converts Latitude to OSM Tile Y
  static int lat2tile(double lat, int zoom) {
    final latRad = lat * math.pi / 180.0;
    return ((1.0 - (math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi)) / 2.0 * (1 << zoom)).floor();
  }

  /// Calculates the set of tile coordinates for given route points along a corridor
  static List<({int z, int x, int y})> calculateTileCoordinates({
    required List<LatLng> points,
    List<int> zoomLevels = const [11, 12, 13, 14, 15],
    double margin = 0.02,
    int maxTiles = 350,
  }) {
    if (points.isEmpty) return [];

    final Set<String> visitedKeys = {};
    final List<({int z, int x, int y})> tiles = [];

    // Sample points along route to avoid redundant tile math for dense polylines
    final List<LatLng> sampledPoints = [];
    if (points.length <= 50) {
      sampledPoints.addAll(points);
    } else {
      final step = (points.length / 50).ceil();
      for (int i = 0; i < points.length; i += step) {
        sampledPoints.add(points[i]);
      }
      if (sampledPoints.last != points.last) {
        sampledPoints.add(points.last);
      }
    }

    for (final z in zoomLevels) {
      for (final p in sampledPoints) {
        final cx = lon2tile(p.longitude, z);
        final cy = lat2tile(p.latitude, z);

        // Add center tile and immediate 1-ring neighbors for a corridor buffer
        for (int dx = -1; dx <= 1; dx++) {
          for (int dy = -1; dy <= 1; dy++) {
            final x = cx + dx;
            final y = cy + dy;
            final key = '$z/$x/$y';
            if (!visitedKeys.contains(key)) {
              visitedKeys.add(key);
              tiles.add((z: z, x: x, y: y));
              if (tiles.length >= maxTiles) return tiles;
            }
          }
        }
      }
    }

    return tiles;
  }

  /// Pre-caches tiles for a list of route points, emitting progress with concurrent batching
  static Stream<TileDownloadProgress> downloadRouteTiles({
    required List<LatLng> points,
    List<int> zoomLevels = const [11, 12, 13, 14, 15],
  }) async* {
    final tiles = calculateTileCoordinates(points: points, zoomLevels: zoomLevels);
    if (tiles.isEmpty) {
      yield const TileDownloadProgress(downloaded: 0, total: 0, percentage: 1.0, isCompleted: true);
      return;
    }

    final cacheDir = await getCacheDirectory();
    // Enforce 100 MB LRU budget before acquiring new tiles
    await enforceCacheBudget();
    final client = http.Client();
    int downloaded = 0;

    yield TileDownloadProgress(downloaded: 0, total: tiles.length, percentage: 0.0);

    // Concurrently download in batches of 4 workers (strictly complies with OSM tile server usage policy)
    const batchSize = 4;
    for (int i = 0; i < tiles.length; i += batchSize) {
      final end = math.min(i + batchSize, tiles.length);
      final batch = tiles.sublist(i, end);

      await Future.wait(batch.map((t) async {
        final tileFile = File('${cacheDir.path}/${t.z}/${t.x}/${t.y}.png');
        if (await tileFile.exists()) {
          final len = await tileFile.length();
          if (len > 500) {
            return;
          } else {
            try {
              await tileFile.delete();
            } catch (_) {}
          }
        }

        try {
          final url = Uri.parse('https://tile.openstreetmap.de/${t.z}/${t.x}/${t.y}.png');
          final response = await client.get(url, headers: const {
            'User-Agent': osmUserAgent,
          }).timeout(const Duration(seconds: 6));

          if (response.statusCode == 200 && response.bodyBytes.length > 500) {
            await tileFile.parent.create(recursive: true);
            await tileFile.writeAsBytes(response.bodyBytes);
          }
        } catch (_) {}
      }));

      downloaded = end;
      yield TileDownloadProgress(
        downloaded: downloaded,
        total: tiles.length,
        percentage: downloaded / tiles.length,
      );
    }

    client.close();
    yield TileDownloadProgress(
      downloaded: tiles.length,
      total: tiles.length,
      percentage: 1.0,
      isCompleted: true,
    );
  }

  /// Returns the count and total size of cached tiles
  static Future<({int count, double megabytes})> getCacheStats() async {
    try {
      final dir = await getCacheDirectory();
      if (!await dir.exists()) return (count: 0, megabytes: 0.0);

      int count = 0;
      int totalBytes = 0;

      await for (final file in dir.list(recursive: true, followLinks: false)) {
        if (file is File && file.path.endsWith('.png')) {
          count++;
          totalBytes += await file.length();
        }
      }

      final mb = totalBytes / (1024 * 1024);
      return (count: count, megabytes: mb);
    } catch (_) {
      return (count: 0, megabytes: 0.0);
    }
  }

  /// Clears all offline cached tiles
  static Future<void> clearCache() async {
    try {
      await purgeLegacyCache();
      final baseDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${baseDir.path}/offline_osm_tiles_v3');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      _cacheDir = null;
    } catch (_) {}
  }
}

/// Custom TileProvider that checks offline disk cache first, falling back to network
class OfflineCachedTileProvider extends TileProvider {
  final String? localCachePath;

  OfflineCachedTileProvider({this.localCachePath});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    if (localCachePath != null) {
      final file = File('$localCachePath/${coordinates.z}/${coordinates.x}/${coordinates.y}.png');
      if (file.existsSync() && file.lengthSync() > 500) {
        // Touch file modification time asynchronously for LRU tracking
        file.setLastModified(DateTime.now()).catchError((_) {});
        return FileImage(file);
      }
    }

    final url = getTileUrl(coordinates, options);
    return NetworkImage(
      url,
      headers: const {
        'User-Agent': MapTileCacheService.osmUserAgent,
      },
    );
  }
}
