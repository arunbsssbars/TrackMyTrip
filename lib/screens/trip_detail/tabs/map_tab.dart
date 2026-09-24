import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/firestore_sync_service.dart';
import '../../../core/services/live_companion_tracker_service.dart';
import '../../../core/services/live_location_tracker_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/realtime_sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/stoppage.dart';
import '../../../models/trip.dart';
import '../../../models/trip_member.dart';
import '../../../providers/stoppage_provider.dart';
import '../../../providers/trip_provider.dart';
import '../../stoppage/add_stoppage_dialog.dart';
import '../../stoppage/stoppage_detail_screen.dart';
import '../../../core/services/map_tile_cache_service.dart';
import '../widgets/offline_map_download_sheet.dart';
import '../../notifications/notification_center_sheet.dart';

class MapTab extends ConsumerStatefulWidget {
  final Trip trip;

  const MapTab({super.key, required this.trip});

  @override
  ConsumerState<MapTab> createState() => _MapTabState();
}

class _MapTabState extends ConsumerState<MapTab> with TickerProviderStateMixin {
  late final MapController _mapController;
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  bool _isMapReady = false;
  String? _offlineCachePath;

  // Selected entities for interaction and navigation
  Stoppage? _selectedMarkerStoppage;
  TripMember? _selectedCompanion;

  // In-app verified navigation routing states
  bool _isNavigatingToCompanion = false;
  List<LatLng> _companionNavRoute = [];
  double _companionNavDistanceKm = 0.0;
  Duration _companionNavEta = Duration.zero;
  TransportMode _activeNavMode = TransportMode.car;
  bool _isCompanionRouteNavigable = true;
  List<String> _companionNavSafetyAdvisories = [];

  // Cached calculated road geometry between stoppages
  List<LatLng> _roadGeometry = [];
  String? _lastStoppagesHash;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    MapTileCacheService.getCacheDirectory().then((dir) {
      if (mounted) setState(() => _offlineCachePath = dir.path);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Connect to Firestore & WebSocket rooms for real-time multi-device sync
      ref.read(firestoreSyncServiceProvider).connectTripRoom(widget.trip.id);
      ref.read(realtimeSyncServiceProvider).connectTripRoom(widget.trip.id);

      final trackingState = ref.read(liveLocationTrackerProvider);
      if (!trackingState.isTracking && !widget.trip.isCompleted) {
        ref.read(liveLocationTrackerProvider.notifier).startTracking(widget.trip.id);
      }

      _syncCompanionSimulation();
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
    // Save 100% battery & CPU by stopping companion movement simulation when leaving Route tab
    ref.read(liveCompanionTrackerProvider.notifier).stopConvoySimulation();
    super.dispose();
  }

  void _syncCompanionSimulation() {
    final liveTrip = ref.read(tripListProvider).firstWhere((t) => t.id == widget.trip.id, orElse: () => widget.trip);
    final companions = liveTrip.members.where((m) => !m.isCurrentUser).toList();
    final stoppages = ref.read(currentTripStoppagesProvider);
    final trackingState = ref.read(liveLocationTrackerProvider);
    final userPos = trackingState.currentPosition != null
        ? LatLng(trackingState.currentPosition!.latitude, trackingState.currentPosition!.longitude)
        : null;

    ref.read(liveCompanionTrackerProvider.notifier).startConvoySimulation(
      tripId: widget.trip.id,
      companions: companions,
      roadRoute: _roadGeometry,
      stoppages: stoppages,
      userPos: userPos,
    );
  }

  void _updateRoadRoute(List<Stoppage> stoppages) async {
    final hash = stoppages.map((s) => '${s.latitude},${s.longitude}').join(';');
    if (hash == _lastStoppagesHash || stoppages.length < 2) return;
    _lastStoppagesHash = hash;

    final waypoints = stoppages.map((s) => LatLng(s.latitude, s.longitude)).toList();
    final roadPoints = await LocationService.fetchRoadRoute(waypoints);
    if (mounted && roadPoints.isNotEmpty) {
      setState(() => _roadGeometry = roadPoints);
      _syncCompanionSimulation();
    }
  }

  void _locateAndCenterUser() async {
    if (!_isMapReady) return;
    final trackingState = ref.read(liveLocationTrackerProvider);
    if (trackingState.currentPosition != null) {
      _mapController.move(
        LatLng(trackingState.currentPosition!.latitude, trackingState.currentPosition!.longitude),
        14.5,
      );
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition();
      final userLatLng = LatLng(pos.latitude, pos.longitude);
      if (_isMapReady) {
        _mapController.move(userLatLng, 14.5);
      }
    } catch (_) {
      final stoppages = ref.read(currentTripStoppagesProvider);
      if (stoppages.isNotEmpty && _isMapReady) {
        _mapController.move(LatLng(stoppages.first.latitude, stoppages.first.longitude), 12.0);
      }
    }
  }

  void _fitAllStoppagesAndRoute(List<Stoppage> stoppages, List<LatLng> breadcrumbs, {List<LatLng>? extraPoints}) {
    if (!_isMapReady) return;
    final points = <LatLng>[];
    for (final s in stoppages) {
      points.add(LatLng(s.latitude, s.longitude));
    }
    points.addAll(breadcrumbs);
    if (extraPoints != null) {
      points.addAll(extraPoints);
    }

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
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = math.max(latDiff, lngDiff);

    double zoom = 12.0;
    if (maxDiff > 5.0) {
      zoom = 6.0;
    } else if (maxDiff > 2.0) {
      zoom = 8.0;
    } else if (maxDiff > 1.0) {
      zoom = 9.5;
    } else if (maxDiff > 0.4) {
      zoom = 11.0;
    } else if (maxDiff > 0.1) {
      zoom = 13.0;
    } else {
      zoom = 14.5;
    }

    if (_isMapReady) {
      _mapController.move(center, zoom);
    }
  }

  void _focusStoppageInVisibleViewport(Stoppage stop) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMarkerStoppage = stop;
      _selectedCompanion = null;
    });

    // Retract shutter to reveal the map with smooth easeOutCubic curve
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.16,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }

    // Offset the center south so the stoppage marker is vertically centered
    // in the visible gap between top speed bar and the collapsed bottom sheet.
    if (_isMapReady) {
      const double latOffset = 0.0035;
      _mapController.move(LatLng(stop.latitude - latOffset, stop.longitude), 14.5);
    }
  }

  void _selectCompanion(TripMember companion) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCompanion = companion;
      _selectedMarkerStoppage = null;
    });

    if (companion.latitude != null && companion.longitude != null && _isMapReady) {
      _mapController.move(LatLng(companion.latitude!, companion.longitude!), 14.5);
    }

    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.44,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showTagGpsStoppageDialog(BuildContext context, LatLng? currentPos) {
    AddStoppageDialog.show(
      context,
      tripId: widget.trip.id,
      initialPosition: currentPos,
      autoDetectGps: currentPos == null,
    );
  }

  /// Calculates or reads live dynamic positions for verified companions around the trip route
  List<TripMember> _getCompanionsWithLocation(
    LatLng userPos,
    List<Stoppage> stoppages,
    Map<String, CompanionLivePosition> liveMap,
    Trip currentTrip,
  ) {
    // Solo trips do not have companions
    if (currentTrip.isSolo) return [];

    final companions = currentTrip.members.where((m) => !m.isCurrentUser).toList();
    final result = <TripMember>[];

    for (int i = 0; i < companions.length; i++) {
      final m = companions[i];
      final livePos = liveMap[m.id];
      if (livePos != null) {
        result.add(
          m.copyWith(
            latitude: livePos.latitude,
            longitude: livePos.longitude,
            lastSeen: livePos.lastUpdated,
          ),
        );
      } else if (m.hasLocation) {
        result.add(m);
      }
    }
    return result;
  }

  IconData _getTransportIcon(TransportMode mode) {
    switch (mode) {
      case TransportMode.car:
        return Icons.directions_car_rounded;
      case TransportMode.bike:
        return Icons.two_wheeler_rounded;
      case TransportMode.foot:
        return Icons.directions_walk_rounded;
      case TransportMode.train:
        return Icons.train_rounded;
    }
  }

  /// Initiates in-app verified navigable route navigation to a companion
  Future<void> _startNavigationToCompanion(
    TripMember companion,
    LatLng userPos, {
    TransportMode? mode,
  }) async {
    HapticFeedback.mediumImpact();
    if (!companion.hasLocation && companion.latitude == null) return;

    final targetPos = LatLng(companion.latitude!, companion.longitude!);
    final selectedMode = mode ?? _activeNavMode;
    final navResult = await LocationService.fetchNavigableRoute([userPos, targetPos], mode: selectedMode);

    if (mounted) {
      setState(() {
        _selectedCompanion = companion;
        _selectedMarkerStoppage = null;
        _isNavigatingToCompanion = true;
        _activeNavMode = selectedMode;
        _companionNavRoute = navResult.isNavigable ? navResult.points : [userPos, targetPos];
        _companionNavDistanceKm = navResult.distanceKm;
        _companionNavEta = navResult.estimatedDuration;
        _isCompanionRouteNavigable = navResult.isNavigable;
        _companionNavSafetyAdvisories = navResult.safetyAdvisories;
      });

      _fitAllStoppagesAndRoute([], [], extraPoints: [userPos, targetPos]);
    }
  }

  void _changeNavMode(TransportMode newMode, LatLng userPos) {
    HapticFeedback.selectionClick();
    if (_selectedCompanion == null || _selectedCompanion!.latitude == null) return;
    _startNavigationToCompanion(_selectedCompanion!, userPos, mode: newMode);
  }

  void _stopNavigationToCompanion() {
    HapticFeedback.lightImpact();
    setState(() {
      _isNavigatingToCompanion = false;
      _companionNavRoute = [];
      _companionNavDistanceKm = 0.0;
      _companionNavEta = Duration.zero;
      _companionNavSafetyAdvisories = [];
      _isCompanionRouteNavigable = true;
    });
  }

  String _formatRemaining(Duration? rem) {
    if (rem == null) return 'Live';
    if (rem.inHours > 0) return '${rem.inHours}h ${rem.inMinutes % 60}m';
    return '${rem.inMinutes}m';
  }

  void _showBroadcastDurationSheet(BuildContext context) {
    final trackingNotifier = ref.read(liveLocationTrackerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_location_rounded, color: Color(0xFF10B981), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Share Live Location',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Select duration to broadcast to companions',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDurationOption(
                  ctx,
                  title: '15 Minutes',
                  subtitle: 'Ideal for stops & quick meetups',
                  icon: Icons.timer_rounded,
                  duration: const Duration(minutes: 15),
                  onTap: () {
                    trackingNotifier.startLocationBroadcast(widget.trip.id, const Duration(minutes: 15));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🟢 Live location broadcast active for 15 minutes!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                _buildDurationOption(
                  ctx,
                  title: '4 Hours',
                  subtitle: 'Ideal for half-day travel legs & excursions',
                  icon: Icons.access_time_rounded,
                  duration: const Duration(hours: 4),
                  onTap: () {
                    trackingNotifier.startLocationBroadcast(widget.trip.id, const Duration(hours: 4));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🟢 Live location broadcast active for 4 hours!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                _buildDurationOption(
                  ctx,
                  title: '8 Hours',
                  subtitle: 'Recommended for full-day convoy driving',
                  icon: Icons.schedule_rounded,
                  duration: const Duration(hours: 8),
                  onTap: () {
                    trackingNotifier.startLocationBroadcast(widget.trip.id, const Duration(hours: 8));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🟢 Live location broadcast active for 8 hours!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                _buildDurationOption(
                  ctx,
                  title: 'Full Day (24 Hours)',
                  subtitle: 'Continuous tracking for overnight expeditions',
                  icon: Icons.wb_sunny_rounded,
                  duration: const Duration(hours: 24),
                  onTap: () {
                    trackingNotifier.startLocationBroadcast(widget.trip.id, const Duration(hours: 24));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🟢 Live location broadcast active for 24 hours!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                if (ref.read(liveLocationTrackerProvider).broadcastExpiresAt != null) ...[
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        trackingNotifier.stopLocationBroadcast();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🔒 Live location broadcast stopped. Location private.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
                      label: const Text('Stop Sharing Location', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDurationOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Duration duration,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentBroadcast = ref.watch(liveLocationTrackerProvider).broadcastDuration;
    final isSelected = currentBroadcast == duration;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: isSelected
            ? const Color(0xFF10B981).withAlpha(isDark ? 35 : 20)
            : (isDark ? Colors.white.withAlpha(8) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: isSelected ? const Color(0xFF10B981) : Colors.grey, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? const Color(0xFF10B981) : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20)
                else
                  const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stoppages = ref.watch(currentTripStoppagesProvider);
    final trackingState = ref.watch(liveLocationTrackerProvider);
    final liveTrip = ref.watch(tripListProvider).firstWhere((t) => t.id == widget.trip.id, orElse: () => widget.trip);
    final companionLiveMap = ref.watch(liveCompanionTrackerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (stoppages.length >= 2) {
      _updateRoadRoute(stoppages);
    }

    final LatLng userOrCenterPos = trackingState.currentPosition != null
        ? LatLng(trackingState.currentPosition!.latitude, trackingState.currentPosition!.longitude)
        : (stoppages.isNotEmpty
            ? LatLng(stoppages.first.latitude, stoppages.first.longitude)
            : const LatLng(28.6139, 77.2090));

    // Live Recorded Trajectory Breadcrumbs (Actual path travelled)
    final liveBreadcrumbs = trackingState.routePoints;

    final double roadDist = _roadGeometry.isNotEmpty
        ? LocationService.calculatePolylineDistanceKm(_roadGeometry)
        : (stoppages.length >= 2 ? LocationService.calculateStoppagesDistanceKm(stoppages) : 0.0);
    final double displayDistanceKm = trackingState.totalDistanceKm > 0.05
        ? trackingState.totalDistanceKm
        : roadDist;

    // Auto stop tracking if trip is completed
    final isCompleted = widget.trip.isCompleted;
    if (isCompleted && trackingState.isTracking) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(liveLocationTrackerProvider.notifier).stopTracking();
      });
    }

    // Dynamically recalculate route/distance/ETA if navigating to a moving companion
    if (_isNavigatingToCompanion && _selectedCompanion != null) {
      final livePos = companionLiveMap[_selectedCompanion!.id];
      final targetLat = livePos?.latitude ?? _selectedCompanion!.latitude;
      final targetLng = livePos?.longitude ?? _selectedCompanion!.longitude;
      if (targetLat != null && targetLng != null) {
        final currentTarget = LatLng(targetLat, targetLng);
        _companionNavDistanceKm = LocationService.calculatePolylineDistanceKm([userOrCenterPos, currentTarget]);
        _companionNavEta = LocationService.calculateRouteEta(_companionNavDistanceKm, averageSpeedKmh: _activeNavMode.averageSpeedKmh);
        if (_companionNavRoute.length <= 2) {
          _companionNavRoute = [userOrCenterPos, currentTarget];
        }
      }
    }

    // Companion List with Active Locations
    final companionsWithLoc = _getCompanionsWithLocation(userOrCenterPos, stoppages, companionLiveMap, liveTrip);

    return Column(
      children: [
        // Pinned Top Trip Route Distance & GPS Controller Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 30 : 8),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Distance / Route Icon
              Container(
                padding: const EdgeInsets.all(7.5),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.amber.withAlpha(25)
                      : AppTheme.primary.withAlpha(18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCompleted ? Icons.flag_circle_rounded : Icons.alt_route_rounded,
                  color: isCompleted ? Colors.amber[800] : AppTheme.primary,
                  size: 19,
                ),
              ),
              const SizedBox(width: 8),

              // Distance, Speed & Status Metrics
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayDistanceKm >= 100
                                ? '${displayDistanceKm.toStringAsFixed(0)} km'
                                : '${displayDistanceKm.toStringAsFixed(2)} km',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, letterSpacing: -0.3),
                          ),
                          const SizedBox(width: 5),
                          if (isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.amber.withAlpha(25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.amber.withAlpha(60), width: 0.8),
                              ),
                              child: const Text(
                                'FINISHED',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            )
                          else if (trackingState.isTracking)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 4.5,
                                    height: 4.5,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${trackingState.currentSpeedKmh.toStringAsFixed(0)} km/h',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.orange.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'PAUSED',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isCompleted
                            ? '${stoppages.length} stops • Route'
                            : (stoppages.isEmpty
                                ? (trackingState.isTracking ? 'GPS live' : 'GPS paused')
                                : '${stoppages.length} ${stoppages.length == 1 ? "stop" : "stops"} • ${trackingState.isTracking ? "Live GPS" : "Paused"}'),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Action Buttons (Completed vs Active Trip)
              if (isCompleted) ...[
                // Fit Route Button for completed trip
                FilledButton.tonalIcon(
                  onPressed: () => _fitAllStoppagesAndRoute(stoppages, liveBreadcrumbs),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                  icon: const Icon(Icons.fit_screen_rounded, size: 14),
                  label: const Text('Fit Route', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ] else ...[
                // Pause / Resume GPS Button (Ultra-compact, overflow safe)
                if (trackingState.isTracking)
                  Material(
                    color: Colors.orange.withAlpha(20),
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      onTap: () {
                        ref.read(liveLocationTrackerProvider.notifier).stopTracking();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('⏸️ GPS Route Tracking Paused.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.orange.withAlpha(70), width: 0.9),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pause_rounded, size: 13, color: Colors.orange),
                            SizedBox(width: 2.5),
                            Text(
                              'Pause',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Material(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      onTap: () {
                        ref.read(liveLocationTrackerProvider.notifier).startTracking(widget.trip.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('▶️ Live GPS Route Tracking Resumed!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded, size: 13, color: Colors.white),
                            SizedBox(width: 2.5),
                            Text(
                              'Resume',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 5),

                // Tag Stop Button
                FilledButton(
                  onPressed: () => _showTagGpsStoppageDialog(context, userOrCenterPos),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_location_alt_rounded, size: 13),
                      SizedBox(width: 2.5),
                      Text('Stop', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(width: 5),

                // Broadcast Live Location Pill (15m / 4h / 8h / Full Day)
                Material(
                  color: trackingState.isBroadcasting
                      ? const Color(0xFF10B981).withAlpha(isDark ? 30 : 20)
                      : (isDark ? Colors.white.withAlpha(12) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    onTap: () => _showBroadcastDurationSheet(context),
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: trackingState.isBroadcasting
                              ? const Color(0xFF10B981).withAlpha(80)
                              : (isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1)),
                          width: 0.9,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.share_location_rounded,
                            size: 13,
                            color: trackingState.isBroadcasting ? const Color(0xFF10B981) : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 2.5),
                          Text(
                            trackingState.isBroadcasting
                                ? _formatRemaining(trackingState.broadcastRemaining)
                                : 'Share',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: trackingState.isBroadcasting ? const Color(0xFF10B981) : (isDark ? Colors.white70 : const Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Unobstructed OpenStreetMap Interactive Canvas
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: userOrCenterPos,
                  initialZoom: stoppages.isNotEmpty ? 11.5 : 13.0,
                  onMapReady: () {
                    if (mounted) setState(() => _isMapReady = true);
                  },
                  onTap: (_, __) {
                    setState(() {
                      _selectedMarkerStoppage = null;
                      _selectedCompanion = null;
                    });
                  },
                ),
                children: [
                  TileLayer(
                    key: ValueKey('tiles_${_offlineCachePath ?? "init"}_$isDark'),
                    urlTemplate: AppConstants.getMapTileUrl(isDark: isDark),
                    userAgentPackageName: 'com.triptracker.trip_tracker_app',
                    tileProvider: OfflineCachedTileProvider(localCachePath: _offlineCachePath),
                  ),

                  // Road-following highway connecting stoppages
                  if (_roadGeometry.length > 1)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _roadGeometry,
                          strokeWidth: 4.5,
                          color: AppTheme.primary.withAlpha(160),
                        ),
                      ],
                    ),

                  // Live Automatic Recorded Journey Route (Actual path travelled by user)
                  if (liveBreadcrumbs.length > 1)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: liveBreadcrumbs,
                          strokeWidth: 5.5,
                          color: const Color(0xFFF59E0B),
                        ),
                      ],
                    ),

                  // Active Turn-by-Turn In-App Route to Selected Companion
                  if (_isNavigatingToCompanion && _companionNavRoute.length > 1)
                    PolylineLayer(
                      polylines: [
                        // Outer white glow border
                        Polyline(
                          points: _companionNavRoute,
                          strokeWidth: 8.0,
                          color: Colors.white.withAlpha(200),
                        ),
                        // Inner vibrant navigation cyan polyline
                        Polyline(
                          points: _companionNavRoute,
                          strokeWidth: 5.5,
                          color: const Color(0xFF06B6D4),
                        ),
                      ],
                    ),

                  // Live User GPS Location Marker with Pulsing Radar
                  if (trackingState.currentPosition != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(trackingState.currentPosition!.latitude, trackingState.currentPosition!.longitude),
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
                                  color: Colors.blue.withAlpha(35),
                                ),
                              ),
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black38, blurRadius: 5, offset: Offset(0, 2)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                  // Stoppage Markers with Numbers & Badges
                  MarkerLayer(
                    markers: stoppages.asMap().entries.map((entry) {
                      final stopIndex = entry.key + 1;
                      final stop = entry.value;
                      final isSelected = _selectedMarkerStoppage?.id == stop.id;

                      return Marker(
                        point: LatLng(stop.latitude, stop.longitude),
                        width: 44,
                        height: 44,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () => _focusStoppageInVisibleViewport(stop),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.secondary
                                      : (stop.isOngoing ? Colors.green : AppTheme.primary),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(70),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2.5),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    AppConstants.getStoppageIcon(stop.category),
                                    color: Colors.white,
                                    size: 17,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 1,
                                child: Container(
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: const BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$stopIndex',
                                    style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // LIVE COMPANION MARKERS ON MAP
                  MarkerLayer(
                    markers: companionsWithLoc.map((companion) {
                      final isSelected = _selectedCompanion?.id == companion.id;
                      final isNavigatingToThis = _isNavigatingToCompanion && isSelected;
                      final colorInt = int.tryParse(companion.colorHex ?? '0xFFF97316') ?? 0xFFF97316;
                      final color = isNavigatingToThis ? const Color(0xFF06B6D4) : Color(colorInt);
                      final initial = companion.name.isNotEmpty ? companion.name[0].toUpperCase() : '?';
                      final livePos = companionLiveMap[companion.id];
                      final speedKmh = livePos?.speedKmh ?? 0.0;

                      return Marker(
                        point: LatLng(companion.latitude!, companion.longitude!),
                        width: 84,
                        height: 72,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () => _selectCompanion(companion),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Name Label Pill with Live / Navigation Indicator
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isNavigatingToThis ? const Color(0xFF06B6D4) : color,
                                    width: isNavigatingToThis ? 1.5 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isNavigatingToThis ? const Color(0xFF06B6D4).withAlpha(120) : Colors.black26,
                                      blurRadius: isNavigatingToThis ? 6 : 4,
                                      offset: const Offset(0, 1.5),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isNavigatingToThis)
                                      Icon(
                                        _getTransportIcon(_activeNavMode),
                                        size: 11,
                                        color: const Color(0xFF06B6D4),
                                      )
                                    else
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        isNavigatingToThis ? '${companion.name} (${_activeNavMode.label})' : companion.name,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          color: isNavigatingToThis ? const Color(0xFF06B6D4) : color,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Avatar Pin
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: isNavigatingToThis ? const Color(0xFF06B6D4) : color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isNavigatingToThis
                                        ? Colors.white
                                        : (isSelected ? Colors.cyanAccent : Colors.white),
                                    width: isNavigatingToThis ? 3 : (isSelected ? 3 : 2),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isNavigatingToThis ? const Color(0xFF06B6D4).withAlpha(180) : color.withAlpha(120),
                                      blurRadius: isNavigatingToThis ? 10 : 7,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: isNavigatingToThis
                                      ? Icon(_getTransportIcon(_activeNavMode), color: Colors.white, size: 18)
                                      : Text(
                                          initial,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                          ),
                                        ),
                                ),
                              ),
                              if (speedKmh > 5.0) ...[
                                const SizedBox(height: 1),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.white24, width: 0.5),
                                  ),
                                  child: Text(
                                    '${speedKmh.toStringAsFixed(0)} km/h',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              // Floating Camera Actions (Center on GPS, Fit Route, Download Offline)
              Positioned(
                top: 12,
                right: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'map_sos_btn',
                      onPressed: () => NotificationCenterSheet.show(context),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 5,
                      tooltip: 'Emergency SOS & Safety',
                      child: const Icon(Icons.sos_rounded, size: 22, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'map_center_btn',
                      onPressed: _locateAndCenterUser,
                      backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
                      foregroundColor: AppTheme.primary,
                      elevation: 4,
                      tooltip: 'Center on My GPS Location',
                      child: const Icon(Icons.my_location_rounded, size: 20),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'map_fit_btn',
                      onPressed: () => _fitAllStoppagesAndRoute(
                        stoppages,
                        liveBreadcrumbs,
                        extraPoints: companionsWithLoc
                            .where((c) => c.latitude != null && c.longitude != null)
                            .map((c) => LatLng(c.latitude!, c.longitude!))
                            .toList(),
                      ),
                      backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
                      foregroundColor: AppTheme.secondary,
                      elevation: 4,
                      tooltip: 'Fit Entire Route in View',
                      child: const Icon(Icons.route_rounded, size: 20),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'map_offline_btn',
                      onPressed: () {
                        final points = [
                          ...stoppages.map((s) => LatLng(s.latitude, s.longitude)),
                          ...liveBreadcrumbs,
                          ..._roadGeometry,
                        ];
                        OfflineMapDownloadSheet.show(
                          context,
                          routePoints: points.isNotEmpty ? points : [userOrCenterPos],
                          tripTitle: widget.trip.title,
                        ).then((_) {
                          MapTileCacheService.getCacheDirectory().then((dir) {
                            if (mounted) setState(() => _offlineCachePath = dir.path);
                          });
                        });
                      },
                      backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
                      foregroundColor: const Color(0xFF0F766E),
                      elevation: 4,
                      tooltip: 'Download Offline Map',
                      child: const Icon(Icons.download_for_offline_rounded, size: 20),
                    ),
                  ],
                ),
              ),

              // Focused Stoppage Floating Overlay Badge
              if (_selectedMarkerStoppage != null)
                Positioned(
                  top: 12,
                  left: 14,
                  right: 64,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A).withAlpha(230) : Colors.white.withAlpha(240),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.primary.withAlpha(120), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            AppConstants.getStoppageIcon(_selectedMarkerStoppage!.category),
                            size: 14,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedMarkerStoppage!.name,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Viewing location in map focus',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _selectedMarkerStoppage = null),
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Expandable Bottom Sheet (Apple Maps / Google Maps Pattern)
              DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: 0.16,
                minChildSize: 0.12,
                maxChildSize: 0.72,
                snap: true,
                snapSizes: const [0.16, 0.44, 0.72],
                builder: (sheetCtx, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 90 : 40),
                          blurRadius: 16,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        // Drag Handle
                        Center(
                          child: Container(
                            width: 38,
                            height: 4.5,
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[700] : Colors.grey[300],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),

                        // Peek Header Bar
                        if (_isNavigatingToCompanion && _selectedCompanion != null)
                          _buildNavigatingPeekHeader(isDark)
                        else if (_selectedMarkerStoppage != null)
                          _buildStoppagePeekHeader(isDark)
                        else if (_selectedCompanion != null)
                          _buildCompanionPeekHeader(isDark, userOrCenterPos)
                        else
                          _buildDefaultPeekHeader(isDark, displayDistanceKm, trackingState, companionsWithLoc),

                        const SizedBox(height: 12),
                        Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), height: 1),
                        const SizedBox(height: 14),

                        // Section 1: Selected Stoppage Card (if a stoppage was selected)
                        if (_selectedMarkerStoppage != null) ...[
                          _buildSelectedStoppageSection(isDark),
                          const SizedBox(height: 16),
                        ],

                        // Section 2: Convoy Radar (Live companions carousel)
                        if (!widget.trip.isSolo) ...[
                          _buildConvoyRadarSection(isDark, companionsWithLoc, companionLiveMap, userOrCenterPos),
                          const SizedBox(height: 14),

                          // Section 3: Selected Companion Card & Direct Navigation (Placed directly BELOW Convoy Radar)
                          if (_selectedCompanion != null && _selectedCompanion!.latitude != null) ...[
                            _buildSelectedCompanionSection(isDark, userOrCenterPos, companionLiveMap),
                            const SizedBox(height: 16),
                          ],
                        ],

                        // Section 4: Route Stoppages
                        if (stoppages.isNotEmpty) ...[
                          _buildRouteStoppagesSection(isDark, stoppages),
                          const SizedBox(height: 18),
                        ],

                        // Section 5: Map Tools & Offline Download
                        _buildMapToolsSection(isDark, trackingState, stoppages, liveBreadcrumbs, userOrCenterPos),

                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavigatingPeekHeader(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: (_isCompanionRouteNavigable ? const Color(0xFF06B6D4) : Colors.red).withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getTransportIcon(_activeNavMode),
            color: _isCompanionRouteNavigable ? const Color(0xFF06B6D4) : Colors.red,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Navigating to ${_selectedCompanion!.name}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _isCompanionRouteNavigable
                    ? '${_companionNavDistanceKm.toStringAsFixed(1)} km • ~${_companionNavEta.inMinutes} mins (${_activeNavMode.label})'
                    : 'Unnavigable route (${_companionNavDistanceKm.toStringAsFixed(0)} km)',
                style: TextStyle(
                  fontSize: 11,
                  color: _isCompanionRouteNavigable ? const Color(0xFF0891B2) : Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 20),
          tooltip: 'End Navigation',
          onPressed: _stopNavigationToCompanion,
        ),
      ],
    );
  }

  Widget _buildStoppagePeekHeader(bool isDark) {
    final stop = _selectedMarkerStoppage!;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppTheme.primary.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(
            AppConstants.getStoppageIcon(stop.category),
            color: AppTheme.primary,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                stop.name,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                stop.address?.isNotEmpty == true
                    ? stop.address!
                    : '${stop.latitude.toStringAsFixed(4)}, ${stop.longitude.toStringAsFixed(4)}',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : AppTheme.textMutedLight),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 20),
          tooltip: 'Deselect',
          onPressed: () => setState(() => _selectedMarkerStoppage = null),
        ),
      ],
    );
  }

  Widget _buildCompanionPeekHeader(bool isDark, LatLng userPos) {
    final c = _selectedCompanion!;
    final color = Color(int.tryParse(c.colorHex ?? '0xFFF97316') ?? 0xFFF97316);
    final dist = (c.latitude != null && c.longitude != null)
        ? Geolocator.distanceBetween(userPos.latitude, userPos.longitude, c.latitude!, c.longitude!) / 1000.0
        : 0.0;

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color,
          child: Text(
            c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      c.name,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Convoy', style: TextStyle(fontSize: 8.5, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              Text(
                '${dist.toStringAsFixed(1)} km away',
                style: TextStyle(fontSize: 10.5, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        if (c.latitude != null && c.longitude != null) ...[
          FilledButton.tonalIcon(
            onPressed: () => _startNavigationToCompanion(c, userPos, mode: _activeNavMode),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0891B2).withAlpha(isDark ? 50 : 25),
              foregroundColor: const Color(0xFF0891B2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: Icon(_getTransportIcon(_activeNavMode), size: 13),
            label: const Text('Nav', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.map_rounded, size: 18, color: AppTheme.secondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Google Maps',
            onPressed: () {
              LocationService.openExternalNavigation(
                c.latitude!,
                c.longitude!,
                label: 'Meet ${c.name}',
              );
            },
          ),
        ],
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          tooltip: 'Deselect',
          onPressed: () => setState(() => _selectedCompanion = null),
        ),
      ],
    );
  }

  Widget _buildDefaultPeekHeader(
    bool isDark,
    double displayDistanceKm,
    LiveTrackingState trackingState,
    List<TripMember> companions,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7.5),
          decoration: BoxDecoration(
            color: AppTheme.primary.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.explore_rounded, color: AppTheme.primary, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    '${displayDistanceKm.toStringAsFixed(1)} km',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
                  ),
                  const SizedBox(width: 6),
                  if (trackingState.isTracking)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${trackingState.currentSpeedKmh.toStringAsFixed(0)} km/h',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                      ),
                    ),
                ],
              ),
              Text(
                companions.isNotEmpty
                    ? '${companions.length} companion${companions.length == 1 ? "" : "s"} live • Drag up for radar'
                    : 'Route overview • Drag up for details',
                style: TextStyle(fontSize: 10.5, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        Material(
          color: trackingState.isBroadcasting
              ? const Color(0xFF10B981).withAlpha(25)
              : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => _showBroadcastDurationSheet(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: trackingState.isBroadcasting ? const Color(0xFF10B981) : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.share_location_rounded,
                    size: 13,
                    color: trackingState.isBroadcasting ? const Color(0xFF10B981) : (isDark ? Colors.grey[300] : const Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trackingState.isBroadcasting ? _formatRemaining(trackingState.broadcastRemaining) : 'Share',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: trackingState.isBroadcasting ? const Color(0xFF10B981) : (isDark ? Colors.white70 : const Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildSelectedCompanionSection(
    bool isDark,
    LatLng userPos,
    Map<String, dynamic> companionLiveMap,
  ) {
    final c = _selectedCompanion!;
    final color = Color(int.tryParse(c.colorHex ?? '0xFFF97316') ?? 0xFFF97316);
    final dist = (c.latitude != null && c.longitude != null)
        ? Geolocator.distanceBetween(userPos.latitude, userPos.longitude, c.latitude!, c.longitude!) / 1000.0
        : 0.0;
    final liveSpeed = companionLiveMap[c.id]?.speedKmh ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(120), width: 1.4),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color,
                child: Text(
                  c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            liveSpeed > 5 ? '${liveSpeed.toStringAsFixed(0)} km/h • Moving' : 'Live on Map',
                            style: const TextStyle(fontSize: 9.5, color: Color(0xFF10B981), fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${dist.toStringAsFixed(1)} km away from you',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Direct Navigation Actions or Active Navigation Banner
          if (_isNavigatingToCompanion) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0891B2).withAlpha(isDark ? 35 : 20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0891B2).withAlpha(80)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(_getTransportIcon(_activeNavMode), size: 16, color: const Color(0xFF0891B2)),
                          const SizedBox(width: 6),
                          Text(
                            '${_companionNavDistanceKm.toStringAsFixed(1)} km • ${_companionNavEta.inMinutes}m ETA (${_activeNavMode.label})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0891B2)),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _stopNavigationToCompanion,
                        icon: const Icon(Icons.stop_rounded, size: 14, color: Colors.red),
                        label: const Text('Stop', style: TextStyle(color: Colors.red, fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Quick mode switcher
                  Row(
                    children: [
                      _buildQuickModePill(TransportMode.car, userPos, isDark),
                      const SizedBox(width: 6),
                      _buildQuickModePill(TransportMode.bike, userPos, isDark),
                      const SizedBox(width: 6),
                      _buildQuickModePill(TransportMode.foot, userPos, isDark),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => LocationService.openExternalNavigation(c.latitude!, c.longitude!, label: 'Meet ${c.name}'),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white12 : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.map_rounded, size: 12),
                              SizedBox(width: 3),
                              Text('Maps', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_companionNavSafetyAdvisories.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _companionNavSafetyAdvisories.first,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.amber[300] : const Color(0xFFB45309),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            // Senior Developer Navigation Control UI
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(8) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SELECT NAVIGATION MODE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        '${dist.toStringAsFixed(1)} km direct',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildModeSelectionChip(
                        mode: TransportMode.car,
                        isSelected: _activeNavMode == TransportMode.car,
                        onTap: () => setState(() => _activeNavMode = TransportMode.car),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildModeSelectionChip(
                        mode: TransportMode.bike,
                        isSelected: _activeNavMode == TransportMode.bike,
                        onTap: () => setState(() => _activeNavMode = TransportMode.bike),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildModeSelectionChip(
                        mode: TransportMode.foot,
                        isSelected: _activeNavMode == TransportMode.foot,
                        onTap: () => setState(() => _activeNavMode = TransportMode.foot),
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => _startNavigationToCompanion(c, userPos, mode: _activeNavMode),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: Icon(_getTransportIcon(_activeNavMode), size: 16),
                    label: Text(
                      'Start In-App Navigation (${_activeNavMode.label})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () {
                      LocationService.openExternalNavigation(
                        c.latitude!,
                        c.longitude!,
                        label: 'Meet ${c.name}',
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(
                        color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    label: const Text(
                      'Open in External Google Maps',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeSelectionChip({
    required TransportMode mode,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary.withAlpha(isDark ? 50 : 25)
                : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primary : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getTransportIcon(mode),
                size: 18,
                color: isSelected ? AppTheme.primary : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 4),
              Text(
                mode.label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppTheme.primary : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickModePill(TransportMode mode, LatLng userPos, bool isDark) {
    final isSelected = _activeNavMode == mode;
    return InkWell(
      onTap: () => _changeNavMode(mode, userPos),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0891B2) : (isDark ? Colors.white12 : Colors.grey[200]),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(_getTransportIcon(mode), size: 12, color: isSelected ? Colors.white : null),
            const SizedBox(width: 3),
            Text(
              mode.label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                color: isSelected ? Colors.white : null,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSelectedStoppageSection(bool isDark) {
    final stop = _selectedMarkerStoppage!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withAlpha(120), width: 1.4),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              AppConstants.getStoppageIcon(stop.category),
              color: AppTheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stop.name,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (stop.address != null && stop.address!.isNotEmpty)
                  Text(
                    stop.address!,
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : AppTheme.textMutedLight),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  '${stop.latitude.toStringAsFixed(4)}, ${_stopMarkerCoords(stop)}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => StoppageDetailScreen(
                    stoppageId: stop.id,
                    tripId: widget.trip.id,
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _stopMarkerCoords(Stoppage stop) => stop.longitude.toStringAsFixed(4);

  Widget _buildConvoyRadarSection(
    bool isDark,
    List<TripMember> companionsWithLoc,
    Map<String, dynamic> companionLiveMap,
    LatLng userPos,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.radar_rounded, color: Color(0xFF06B6D4), size: 18),
                SizedBox(width: 6),
                Text(
                  'Companion Convoy Radar',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${companionsWithLoc.length} Online',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (companionsWithLoc.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'No active companions on radar yet. Share trip code to invite companions.',
              style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: companionsWithLoc.map((c) {
                final dist = (c.latitude != null && c.longitude != null)
                    ? Geolocator.distanceBetween(
                        userPos.latitude,
                        userPos.longitude,
                        c.latitude!,
                        c.longitude!,
                      ) / 1000.0
                    : 0.0;
                final color = Color(int.tryParse(c.colorHex ?? '0xFFF97316') ?? 0xFFF97316);
                final isSelected = _selectedCompanion?.id == c.id;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: isSelected
                        ? color.withAlpha(isDark ? 40 : 25)
                        : (isDark ? AppTheme.surfaceDark : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => _selectCompanion(c),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? color : (isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: color,
                              child: Text(
                                c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  c.name,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                                ),
                                Text(
                                  '${dist.toStringAsFixed(1)} km away',
                                  style: TextStyle(fontSize: 10.5, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                if (c.latitude != null && c.longitude != null) {
                                  _startNavigationToCompanion(c, userPos, mode: _activeNavMode);
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF06B6D4),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF06B6D4).withAlpha(60),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.navigation_rounded, size: 12, color: Colors.white),
                                    SizedBox(width: 3.5),
                                    Text('Navigate', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildRouteStoppagesSection(bool isDark, List<Stoppage> stoppages) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.place_rounded, color: AppTheme.primary, size: 18),
                SizedBox(width: 6),
                Text(
                  'Route Stoppages',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ],
            ),
            Text(
              '${stoppages.length} tagged',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: stoppages.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final stop = entry.value;
              final isSelected = _selectedMarkerStoppage?.id == stop.id;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: isSelected
                      ? AppTheme.primary.withAlpha(isDark ? 40 : 20)
                      : (isDark ? AppTheme.surfaceDark : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => _focusStoppageInVisibleViewport(stop),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary : (isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
                          width: isSelected ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#$idx',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(AppConstants.getStoppageIcon(stop.category), size: 14, color: AppTheme.primary),
                          const SizedBox(width: 5),
                          Text(
                            stop.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMapToolsSection(
    bool isDark,
    LiveTrackingState trackingState,
    List<Stoppage> stoppages,
    List<LatLng> liveBreadcrumbs,
    LatLng userPos,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.build_circle_outlined, color: Color(0xFF0F766E), size: 18),
            SizedBox(width: 6),
            Text(
              'Map Tools & Offline',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final points = [
                    ...stoppages.map((s) => LatLng(s.latitude, s.longitude)),
                    ...liveBreadcrumbs,
                    ..._roadGeometry,
                  ];
                  OfflineMapDownloadSheet.show(
                    context,
                    routePoints: points.isNotEmpty ? points : [userPos],
                    tripTitle: widget.trip.title,
                  ).then((_) {
                    MapTileCacheService.getCacheDirectory().then((dir) {
                      if (mounted) setState(() => _offlineCachePath = dir.path);
                    });
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.download_for_offline_rounded, size: 16, color: Color(0xFF0F766E)),
                label: const Text('Offline Map', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showBroadcastDurationSheet(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.share_location_rounded, size: 16, color: Color(0xFF10B981)),
                label: Text(
                  trackingState.isBroadcasting ? 'Broadcasting' : 'Share GPS',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
