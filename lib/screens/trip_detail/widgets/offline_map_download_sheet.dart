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

  String _selectedPack = 'Trip Route';

  static final Map<String, List<LatLng>> _regionalPacks = {
    'Trip Route': [],
    'Manali & Solang': [const LatLng(32.2396, 77.1887), const LatLng(32.3166, 77.1575), const LatLng(32.3716, 77.2466)],
    'Shimla & Kufri': [const LatLng(31.1048, 77.1734), const LatLng(31.0988, 77.2678), const LatLng(31.1444, 77.1592)],
    'Goa Coastal': [const LatLng(15.5524, 73.7557), const LatLng(15.4909, 73.8278), const LatLng(15.2832, 73.9863)],
    'Leh & Ladakh': [const LatLng(34.1526, 77.5771), const LatLng(34.2787, 77.6047), const LatLng(33.7595, 78.6674)],
  };

  List<LatLng> get _effectivePoints {
    if (_selectedPack == 'Trip Route' || !_regionalPacks.containsKey(_selectedPack)) {
      return widget.routePoints;
    }
    return _regionalPacks[_selectedPack]!;
  }

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
    final points = _effectivePoints;
    final tiles = MapTileCacheService.calculateTileCoordinates(points: points);
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
    _sub = MapTileCacheService.downloadRouteTiles(points: points).listen(
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
    final effectivePts = _effectivePoints;
    final calculatedTiles = MapTileCacheService.calculateTileCoordinates(points: effectivePts);
    final estTilesCount = calculatedTiles.length;
    final estMb = (estTilesCount * 0.022).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
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
          const SizedBox(height: 16),

          // Regional Pack Filter Chips
          const Text(
            'Select Region / Preset Pack:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _regionalPacks.keys.map((packName) {
                final isSelected = _selectedPack == packName;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(packName),
                    selected: isSelected,
                    onSelected: _isDownloading
                        ? null
                        : (selected) {
                            if (selected) {
                              setState(() {
                                _selectedPack = packName;
                              });
                            }
                          },
                    selectedColor: AppTheme.primary.withAlpha(40),
                    checkmarkColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppTheme.primary : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected ? AppTheme.primary : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

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
                    const Expanded(child: Text('Selected Area Points', style: TextStyle(fontSize: 12.5, color: Colors.grey))),
                    const SizedBox(width: 8),
                    Text('${effectivePts.length} GPS Points', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                    Expanded(
                      child: Text(
                        'Downloading tiles: ${_progress!.downloaded} / ${_progress!.total}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
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
    ),
  );
}
}
