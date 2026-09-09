import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/nearby_poi.dart';

class MapLocationPickerDialog extends StatefulWidget {
  final LatLng initialPosition;

  const MapLocationPickerDialog({super.key, required this.initialPosition});

  static Future<LocationDetails?> show(BuildContext context, {LatLng? initialPosition}) {
    final pos = initialPosition ?? const LatLng(36.6002, -121.8947);
    return showDialog<LocationDetails>(
      context: context,
      builder: (ctx) => MapLocationPickerDialog(initialPosition: pos),
    );
  }

  @override
  State<MapLocationPickerDialog> createState() => _MapLocationPickerDialogState();
}

class _MapLocationPickerDialogState extends State<MapLocationPickerDialog> {
  late MapController _mapController;
  late LatLng _pickedPosition;
  bool _isGeocoding = false;
  bool _isDragging = false;
  String _placeName = 'Locating place...';
  String? _address;
  String? _inferredCategory;
  Timer? _debounceTimer;
  List<NearbyPOI> _nearbyPOIs = [];
  bool _isLoadingPOIs = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pickedPosition = widget.initialPosition;
    _reverseGeocodeSelectedPoint(_pickedPosition);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _reverseGeocodeSelectedPoint(LatLng point) async {
    setState(() {
      _isGeocoding = true;
      _placeName = 'Looking up address...';
    });

    _fetchNearbyPOIs(point);

    final details = await LocationService.reverseGeocode(point.latitude, point.longitude);

    if (mounted) {
      setState(() {
        _isGeocoding = false;
        _placeName = details.placeName;
        _address = details.address;
        _inferredCategory = details.category;
      });
    }
  }

  Future<void> _fetchNearbyPOIs(LatLng point) async {
    if (!mounted) return;
    setState(() => _isLoadingPOIs = true);
    try {
      final results = await LocationService.fetchNearbyPOIs(point.latitude, point.longitude);
      if (mounted) {
        setState(() {
          _nearbyPOIs = results;
          _isLoadingPOIs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPOIs = false);
    }
  }

  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    setState(() {
      _pickedPosition = camera.center;
      if (hasGesture) {
        _isDragging = true;
      }
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 450), () {
      if (mounted) {
        setState(() => _isDragging = false);
        _reverseGeocodeSelectedPoint(_pickedPosition);
      }
    });
  }

  Future<void> _centerOnGps() async {
    final pos = await LocationService.getCurrentPosition();
    if (pos != null && mounted) {
      final newPos = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _pickedPosition = newPos;
      });
      _mapController.move(newPos, 15.0);
      _reverseGeocodeSelectedPoint(newPos);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height * 0.78,
          child: Stack(
            children: [
              // Interactive Map (moves underneath stationary center pin)
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _pickedPosition,
                  initialZoom: 14.0,
                  onPositionChanged: _onMapPositionChanged,
                ),
                children: [
                  TileLayer(
                    urlTemplate: AppConstants.getMapTileUrl(isDark: isDark),
                    userAgentPackageName: 'com.triptracker.trip_tracker_app',
                  ),
                ],
              ),

              // Fixed Stationary Center Target & Pin (Map moves underneath!)
              Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Target Ground Shadow
                      Positioned(
                        bottom: 12,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: _isDragging ? 8 : 14,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(_isDragging ? 40 : 100),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(50),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Floating Stationary Pin Icon
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 180),
                        bottom: _isDragging ? 22 : 12,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.redAccent,
                          size: 48,
                          shadows: [
                            Shadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Top Title & Instructions Bar
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A).withAlpha(230) : Colors.white.withAlpha(240),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pan_tool_alt_rounded, color: AppTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Pan map to align center pin with location',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),

              // Floating GPS Center Button
              Positioned(
                right: 16,
                bottom: 225,
                child: FloatingActionButton.small(
                  onPressed: _centerOnGps,
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  tooltip: 'Center on Current GPS',
                  child: const Icon(Icons.my_location_rounded),
                ),
              ),

              // Bottom Place Card & Confirm Button
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -4)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withAlpha(30),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.place_rounded, color: AppTheme.primary, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_isGeocoding || _isDragging)
                                  const Row(
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Detecting place name...',
                                        style: TextStyle(fontSize: 13, color: Colors.grey),
                                      ),
                                    ],
                                  )
                                else ...[
                                  Text(
                                    _placeName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_address != null && _address!.isNotEmpty)
                                    Text(
                                      _address!,
                                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                                const SizedBox(height: 2),
                                Text(
                                  'GPS: ${_pickedPosition.latitude.toStringAsFixed(4)}, ${_pickedPosition.longitude.toStringAsFixed(4)}',
                                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Nearby Tagged Places Quick-Select Chips
                      if (_isLoadingPOIs || _nearbyPOIs.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.near_me_rounded, size: 12, color: AppTheme.primary),
                            const SizedBox(width: 4),
                            const Text(
                              'Nearby Tagged Places',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            if (_isLoadingPOIs) ...[
                              const SizedBox(width: 6),
                              const SizedBox(
                                width: 9,
                                height: 9,
                                child: CircularProgressIndicator(strokeWidth: 1.5),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _nearbyPOIs.map((poi) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                  visualDensity: VisualDensity.compact,
                                  avatar: Icon(poi.icon, size: 13, color: AppTheme.primary),
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        poi.name,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        poi.formattedDistance,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onPressed: () {
                                    final newPoint = LatLng(poi.latitude, poi.longitude);
                                    setState(() {
                                      _pickedPosition = newPoint;
                                      _placeName = poi.name;
                                      _inferredCategory = poi.category;
                                    });
                                    _mapController.move(newPoint, 16.0);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop(
                            LocationDetails(
                              latitude: _pickedPosition.latitude,
                              longitude: _pickedPosition.longitude,
                              placeName: _placeName,
                              address: _address,
                              category: _inferredCategory,
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: const Text('Confirm This Location', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
