import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/map_tile_cache_service.dart';
import '../../../core/theme/app_theme.dart';

class OfflineMapDownloadSheet extends StatefulWidget {
  final List<LatLng> routePoints;
  final String tripTitle;

  const OfflineMapDownloadSheet({
    super.key,
    required this.routePoints,
    required this.tripTitle,
  });

  static Future<void> show(BuildContext context, {required List<LatLng> routePoints, required String tripTitle}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OfflineMapDownloadSheet(
        routePoints: routePoints,
        tripTitle: tripTitle,
      ),
    );
  }

  @override
  State<OfflineMapDownloadSheet> createState() => _OfflineMapDownloadSheetState();
}

class _OfflineMapDownloadSheetState extends State<OfflineMapDownloadSheet> {
  bool _isDownloading = false;
  TileDownloadProgress? _progress;
  StreamSubscription<TileDownloadProgress>? _sub;

  int _cachedCount = 0;
  double _cachedMb = 0.0;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadCacheStats();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadCacheStats() async {
    final stats = await MapTileCacheService.getCacheStats();
    if (mounted) {
      setState(() {
        _cachedCount = stats.count;
        _cachedMb = stats.megabytes;
        _loadingStats = false;
      });
    }
  }

  void _startDownload() {
    final tiles = MapTileCacheService.calculateTileCoordinates(points: widget.routePoints);
    if (tiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No route points or stoppages found to cache.')),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = TileDownloadProgress(downloaded: 0, total: tiles.length, percentage: 0.0);
    });

    _sub?.cancel();
    _sub = MapTileCacheService.downloadRouteTiles(points: widget.routePoints).listen(
      (progress) {
        if (mounted) {
          setState(() {
            _progress = progress;
            if (progress.isCompleted) {
              _isDownloading = false;
            }
          });
          if (progress.isCompleted) {
            _loadCacheStats();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Offline map downloaded successfully! Map will render in Airplane mode.'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() => _isDownloading = false);
        }
      },
    );
  }

  Future<void> _clearCache() async {
    await MapTileCacheService.clearCache();
    await _loadCacheStats();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline map cache cleared.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final calculatedTiles = MapTileCacheService.calculateTileCoordinates(points: widget.routePoints);
    final estTilesCount = calculatedTiles.length;
    final estMb = (estTilesCount * 0.022).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.download_for_offline_rounded, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Offline Map Pre-Caching',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                    ),
                    Text(
                      widget.tripTitle,
                      style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[400] : AppTheme.textMutedLight),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Info Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(child: Text('Route Coverage Points', style: TextStyle(fontSize: 12.5, color: Colors.grey))),
                    const SizedBox(width: 8),
                    Text('${widget.routePoints.length} GPS Points', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(child: Text('Estimated Offline Tiles', style: TextStyle(fontSize: 12.5, color: Colors.grey))),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '~$estTilesCount tiles (≈$estMb MB)',
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(child: Text('Current Local Storage', style: TextStyle(fontSize: 12.5, color: Colors.grey))),
                    const SizedBox(width: 8),
                    _loadingStats
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : Flexible(
                            child: Text(
                              '$_cachedCount tiles (${_cachedMb.toStringAsFixed(1)} MB)',
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Download Progress Bar
          if (_isDownloading && _progress != null) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Downloading tiles: ${_progress!.downloaded} / ${_progress!.total}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${(_progress!.percentage * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress!.percentage,
                    minHeight: 8,
                    backgroundColor: Colors.grey.withAlpha(50),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Ready Status
          if (_cachedCount > 0 && !_isDownloading) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.offline_pin_rounded, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Map tiles are cached! The map will display even without mobile network.',
                      style: TextStyle(color: Colors.green, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Buttons
          Row(
            children: [
              if (_cachedCount > 0) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isDownloading ? null : _clearCache,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.red),
                    label: const Text('Clear', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.red.withAlpha(80)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _isDownloading ? null : _startDownload,
                  icon: _isDownloading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(_isDownloading ? 'Downloading...' : 'Download Offline Map'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
