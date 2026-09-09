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

  /// Calculates the set of tile coordinates for given points across specified zoom levels
  static List<({int z, int x, int y})> calculateTileCoordinates({
    required List<LatLng> points,
    List<int> zoomLevels = const [11, 12, 13, 14, 15],
    double margin = 0.03,
    int maxTiles = 450,
  }) {
    if (points.isEmpty) return [];

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    minLat = math.max(-85.0, minLat - margin);
    maxLat = math.min(85.0, maxLat + margin);
    minLng = math.max(-180.0, minLng - margin);
    maxLng = math.min(180.0, maxLng + margin);

    final List<({int z, int x, int y})> tiles = [];

    for (final z in zoomLevels) {
      final x1 = lon2tile(minLng, z);
      final x2 = lon2tile(maxLng, z);
      final y1 = lat2tile(maxLat, z); // Note: tile Y is inverted
      final y2 = lat2tile(minLat, z);

      final minX = math.min(x1, x2);
      final maxX = math.max(x1, x2);
      final minY = math.min(y1, y2);
      final maxY = math.max(y1, y2);

      for (int x = minX; x <= maxX; x++) {
        for (int y = minY; y <= maxY; y++) {
          tiles.add((z: z, x: x, y: y));
          if (tiles.length >= maxTiles) return tiles;
        }
      }
    }

    return tiles;
  }

  /// Pre-caches tiles for a list of route points, emitting progress
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
    final client = http.Client();
    int downloaded = 0;

    yield TileDownloadProgress(downloaded: 0, total: tiles.length, percentage: 0.0);

    for (final t in tiles) {
      final tileFile = File('${cacheDir.path}/${t.z}/${t.x}/${t.y}.png');
      if (await tileFile.exists()) {
        final len = await tileFile.length();
        if (len > 500) {
          downloaded++;
          yield TileDownloadProgress(
            downloaded: downloaded,
            total: tiles.length,
            percentage: downloaded / tiles.length,
          );
          continue;
        } else {
          // Corrupt or 403 error page from previous block, remove it
          try {
            await tileFile.delete();
          } catch (_) {}
        }
      }

      try {
        final url = Uri.parse('https://tile.openstreetmap.de/${t.z}/${t.x}/${t.y}.png');
        final response = await client.get(url, headers: const {
          'User-Agent': 'TripTrackerApp/1.0 (https://triptracker.app; travel@triptracker.app)',
        }).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200 && response.bodyBytes.length > 500) {
          await tileFile.parent.create(recursive: true);
          await tileFile.writeAsBytes(response.bodyBytes);
        }
      } catch (_) {
        // Continue downloading other tiles even if one fails
      }

      downloaded++;
      yield TileDownloadProgress(
        downloaded: downloaded,
        total: tiles.length,
        percentage: downloaded / tiles.length,
      );

      // Brief delay to be polite to OpenStreetMap tile servers
      await Future.delayed(const Duration(milliseconds: 30));
    }

    client.close();
    yield TileDownloadProgress(
      downloaded: downloaded,
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
        return FileImage(file);
      }
    }

    final url = getTileUrl(coordinates, options);
    return NetworkImage(
      url,
      headers: const {
        'User-Agent': 'TripTrackerApp/1.0 (https://triptracker.app; travel@triptracker.app)',
      },
    );
  }
}
