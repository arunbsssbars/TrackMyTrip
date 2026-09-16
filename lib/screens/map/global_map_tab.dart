import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_theme.dart';
import '../../models/trip.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';
import '../trip_detail/trip_detail_screen.dart';

class GlobalMapTab extends ConsumerStatefulWidget {
  const GlobalMapTab({super.key});

  @override
  ConsumerState<GlobalMapTab> createState() => _GlobalMapTabState();
}

class _GlobalMapTabState extends ConsumerState<GlobalMapTab> {
  final MapController _mapController = MapController();

  void _fitBounds(List<LatLng> points) {
    if (points.isEmpty) return;
    
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
    _mapController.move(center, 5.0); // Default zoomed out view
  }

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(tripListProvider);

    // Let's gather all stoppages from all trips for the global view
    // Since we might not have a direct provider for ALL stoppages, we can just use the ones loaded
    // For this prototype, let's assume we render mock routes or the start locations of trips
    
    List<Marker> markers = [];
    List<LatLng> allPoints = [];

    for (final trip in trips) {
      // Mock some locations for the global map if no stoppages are loaded
      final defaultPoint = LatLng(37.7749 + (trips.indexOf(trip) * 0.1), -122.4194 + (trips.indexOf(trip) * 0.1));
      allPoints.add(defaultPoint);
      
      markers.add(
        Marker(
          point: defaultPoint,
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => TripDetailScreen(tripId: trip.id),
                ),
              );
            },
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: const Icon(Icons.explore_rounded, color: Colors.white, size: 20),
                ),
                Text(
                  trip.title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    backgroundColor: Colors.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );

      // Add mock companion locations around the trip
      for (int i = 0; i < trip.members.length; i++) {
        final member = trip.members[i];
        if (member.isCurrentUser) continue;
        
        final companionPoint = LatLng(
          defaultPoint.latitude + (i % 2 == 0 ? 0.02 : -0.02),
          defaultPoint.longitude + (i % 3 == 0 ? 0.02 : -0.02),
        );
        allPoints.add(companionPoint);
        
        markers.add(
          Marker(
            point: companionPoint,
            width: 40,
            height: 40,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: Center(
                child: Text(
                  member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ),
        );
      }
    }

    if (allPoints.isNotEmpty && _mapController.camera.zoom == 1.0) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
         _fitBounds(allPoints);
       });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Route Map'),
        elevation: 0,
      ),
      body: trips.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Create a trip to see your routes!', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: allPoints.isNotEmpty ? allPoints.first : const LatLng(37.7749, -122.4194),
                    initialZoom: 5.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.antigravity.triptracker',
                    ),
                    MarkerLayer(markers: markers),
                  ],
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(240),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppTheme.primary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Showing all active journeys and companion locations. Tap a trip to view detailed routes.',
                            style: TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (allPoints.isNotEmpty) {
            _fitBounds(allPoints);
          }
        },
        backgroundColor: Colors.white,
        child: const Icon(Icons.my_location_rounded, color: AppTheme.primary),
      ),
    );
  }
}
