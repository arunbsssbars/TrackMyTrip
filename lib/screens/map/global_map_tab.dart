import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/services/live_companion_tracker_service.dart';
import '../../core/services/live_location_tracker_service.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/stoppage.dart';
import '../../models/trip_member.dart';
import '../../providers/trip_provider.dart';
import '../trip_detail/trip_detail_screen.dart';

class GlobalMapTab extends ConsumerStatefulWidget {
  const GlobalMapTab({super.key});

  @override
  ConsumerState<GlobalMapTab> createState() => _GlobalMapTabState();
}

class _GlobalMapTabState extends ConsumerState<GlobalMapTab> {
  final MapController _mapController = MapController();
  LatLng? _currentGpsPos;
  TripMember? _selectedCompanion;
  String? _selectedCompanionTripTitle;
  bool _hasCenteredInitial = false;

  // Default fallback center: New Delhi, India instead of San Francisco / US
  static const LatLng _defaultFallbackCenter = LatLng(28.6139, 77.2090);

  @override
  void initState() {
    super.initState();
    _fetchInitialGps();
  }

  void _fetchInitialGps() async {
    final pos = await LocationService.getCurrentPosition();
    if (pos != null && mounted) {
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentGpsPos = latLng;
      });
      if (!_hasCenteredInitial) {
        _hasCenteredInitial = true;
        _mapController.move(latLng, 12.0);
      }
    }
  }

  void _fitBounds(List<LatLng> points) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 13.0);
      return;
    }

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

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _mapController.move(center, 7.0);
  }

  void _centerOnUser() async {
    if (_currentGpsPos != null) {
      _mapController.move(_currentGpsPos!, 14.0);
      return;
    }
    final pos = await LocationService.getCurrentPosition();
    if (pos != null && mounted) {
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentGpsPos = latLng;
      });
      _mapController.move(latLng, 14.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(tripListProvider);
    final trackingState = ref.watch(liveLocationTrackerProvider);
    final companionLiveMap = ref.watch(liveCompanionTrackerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use live GPS position from tracker if available
    if (trackingState.currentPosition != null) {
      _currentGpsPos = LatLng(
        trackingState.currentPosition!.latitude,
        trackingState.currentPosition!.longitude,
      );
    }

    // Retrieve real stoppages
    List<Stoppage> allStoppages = [];
    try {
      allStoppages = ref.read(localStorageServiceProvider).getAllStoppages();
    } catch (_) {}

    final List<Marker> markers = [];
    final List<LatLng> allPoints = [];
    final List<Polyline> polylines = [];

    // 1. Add User's Live Location Marker
    if (_currentGpsPos != null) {
      allPoints.add(_currentGpsPos!);
      markers.add(
        Marker(
          point: _currentGpsPos!,
          width: 50,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withAlpha(50),
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Add Trip & Stoppage Markers
    for (final trip in trips) {
      final tripStoppages = allStoppages.where((s) => s.tripId == trip.id).toList();

      if (tripStoppages.isNotEmpty) {
        final tripPoints = tripStoppages.map((s) => LatLng(s.latitude, s.longitude)).toList();
        allPoints.addAll(tripPoints);

        // Add Route Polyline
        if (tripPoints.length > 1) {
          polylines.add(
            Polyline(
              points: tripPoints,
              strokeWidth: 3.5,
              color: AppTheme.primary.withAlpha(160),
            ),
          );
        }

        // Add Marker for latest stoppage
        final latest = tripStoppages.last;
        markers.add(
          Marker(
            point: LatLng(latest.latitude, latest.longitude),
            width: 70,
            height: 60,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => TripDetailScreen(tripId: trip.id)),
                );
              },
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black87 : Colors.white.withAlpha(230),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      trip.title,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppTheme.textMainLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 9.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // 3. Add Live Broadcast Companion Markers
      for (final member in trip.members) {
        if (member.isCurrentUser) continue;

        // Check if member has real broadcast coordinates
        double? lat = member.latitude;
        double? lng = member.longitude;

        if (companionLiveMap.containsKey(member.id)) {
          final compLoc = companionLiveMap[member.id]!;
          lat = compLoc.latitude;
          lng = compLoc.longitude;
        }

        if (lat != null && lng != null) {
          final companionPt = LatLng(lat, lng);
          allPoints.add(companionPt);

          final memberColor = member.colorHex != null
              ? Color(int.parse(member.colorHex!))
              : Colors.orange;

          markers.add(
            Marker(
              point: companionPt,
              width: 52,
              height: 52,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCompanion = member.copyWith(latitude: lat, longitude: lng);
                    _selectedCompanionTripTitle = trip.title;
                  });
                },
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: memberColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.2),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                          child: Center(
                            child: Text(
                              member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      member.name,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      }
    }

    // Determine initial center
    final initialCenter = _currentGpsPos ??
        (allPoints.isNotEmpty ? allPoints.first : _defaultFallbackCenter);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Route Map', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_center_focus_rounded),
            tooltip: 'Fit All Points',
            onPressed: allPoints.isNotEmpty ? () => _fitBounds(allPoints) : null,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: _currentGpsPos != null ? 12.0 : 5.0,
              onTap: (_, __) {
                if (_selectedCompanion != null) {
                  setState(() => _selectedCompanion = null);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.antigravity.triptracker',
              ),
              if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
              MarkerLayer(markers: markers),
            ],
          ),

          // Top Info Banner
          Positioned(
            top: 14,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark.withAlpha(235) : Colors.white.withAlpha(235),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
                border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
              ),
              child: Row(
                children: [
                  const Icon(Icons.explore_rounded, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      trips.isEmpty
                          ? 'No trips created yet. Your current GPS position is centered.'
                          : 'Showing all active routes & live companions. Tap a companion to navigate.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Companion Action Card (Navigate to broadcasted companion)
          if (_selectedCompanion != null && _selectedCompanion!.latitude != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 50 : 25),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: AppTheme.primary.withAlpha(90), width: 1.2),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _selectedCompanion!.colorHex != null
                          ? Color(int.parse(_selectedCompanion!.colorHex!))
                          : AppTheme.primary,
                      radius: 20,
                      child: Text(
                        _selectedCompanion!.name.isNotEmpty
                            ? _selectedCompanion!.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                _selectedCompanion!.name,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.green.withAlpha(25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'LIVE',
                                  style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedCompanionTripTitle ?? 'Live Companion',
                            style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        LocationService.openExternalNavigation(
                          _selectedCompanion!.latitude!,
                          _selectedCompanion!.longitude!,
                          label: _selectedCompanion!.name,
                        );
                      },
                      icon: const Icon(Icons.navigation_rounded, size: 16),
                      label: const Text('Navigate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _selectedCompanion == null
          ? FloatingActionButton(
              onPressed: _centerOnUser,
              backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
              tooltip: 'My Location',
              child: const Icon(Icons.my_location_rounded, color: AppTheme.primary),
            )
          : null,
    );
  }
}
