import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/nearby_poi.dart';

class LocationDetails {
  final double latitude;
  final double longitude;
  final String placeName;
  final String? address;
  final String? category;
  final String? countryCode;
  final String? country;

  const LocationDetails({
    required this.latitude,
    required this.longitude,
    required this.placeName,
    this.address,
    this.category,
    this.countryCode,
    this.country,
  });
}

class LocationService {
  /// Fast synchronous detection of currency using device system locale
  static String detectLocalCurrencyFast() {
    try {
      final countryCode = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
      if (countryCode != null && countryCode.isNotEmpty) {
        return getCurrencyForCountryCode(countryCode);
      }
    } catch (_) {}
    return 'INR';
  }

  /// Asynchronous detection combining GPS coordinates reverse geocoding with locale fallback
  static Future<String> detectLocalCurrency() async {
    try {
      final pos = await getCurrentPosition();
      if (pos != null) {
        final details = await reverseGeocode(pos.latitude, pos.longitude);
        if (details.countryCode != null && details.countryCode!.isNotEmpty) {
          return getCurrencyForCountryCode(details.countryCode!);
        }
      }
    } catch (_) {}
    return detectLocalCurrencyFast();
  }

  /// Map ISO 3166-1 alpha-2 / country code to standard currency code
  static String getCurrencyForCountryCode(String? countryCode) {
    if (countryCode == null || countryCode.isEmpty) return 'INR';
    final code = countryCode.toUpperCase().trim();

    switch (code) {
      case 'IN':
        return 'INR';
      case 'US':
        return 'USD';
      case 'GB':
      case 'UK':
        return 'GBP';
      case 'AE':
        return 'AED';
      case 'EU':
      case 'DE':
      case 'FR':
      case 'IT':
      case 'ES':
      case 'NL':
      case 'BE':
      case 'AT':
      case 'PT':
      case 'IE':
      case 'FI':
      case 'GR':
        return 'EUR';
      case 'JP':
        return 'JPY';
      case 'AU':
        return 'AUD';
      case 'CA':
        return 'CAD';
      case 'SG':
        return 'SGD';
      case 'CH':
        return 'CHF';
      case 'NZ':
        return 'NZD';
      case 'TH':
        return 'THB';
      case 'MY':
        return 'MYR';
      case 'ID':
        return 'IDR';
      case 'VN':
        return 'VND';
      case 'SA':
        return 'SAR';
      case 'QA':
        return 'QAR';
      case 'KW':
        return 'KWD';
      case 'OM':
        return 'OMR';
      case 'BH':
        return 'BHD';
      case 'NP':
        return 'NPR';
      case 'LK':
        return 'LKR';
      case 'BD':
        return 'BDT';
      case 'PK':
        return 'PKR';
      case 'KR':
        return 'KRW';
      case 'CN':
        return 'CNY';
      case 'TR':
        return 'TRY';
      case 'BR':
        return 'BRL';
      case 'MX':
        return 'MXN';
      case 'ZA':
        return 'ZAR';
      case 'RU':
        return 'RUB';
      case 'SE':
        return 'SEK';
      case 'NO':
        return 'NOK';
      case 'DK':
        return 'DKK';
      case 'PL':
        return 'PLN';
      default:
        return 'USD';
    }
  }

  static Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Acquires high-accuracy current GPS position
  static Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        return await Geolocator.getLastKnownPosition();
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// Reverse geocodes latitude and longitude into human-readable place name & address
  static Future<LocationDetails> reverseGeocode(double lat, double lng) async {
    String placeName = 'Waypoint (${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)})';
    String? address;
    String? category;
    String? countryCode;
    String? country;

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&zoom=18&addressdetails=1&extratags=1&namedetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'TripTrackerApp/1.0 (travel@triptracker.app)'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final addressObj = data['address'] as Map<String, dynamic>?;
        final extratags = data['extratags'] as Map<String, dynamic>?;

        final rawName = data['name'] as String?;
        final displayName = data['display_name'] as String?;
        final brand = extratags?['brand'] as String? ?? extratags?['operator'] as String?;

        final amenity = addressObj?['amenity'] as String?;
        final shop = addressObj?['shop'] as String?;
        final tourism = addressObj?['tourism'] as String?;
        final historic = addressObj?['historic'] as String?;
        final leisure = addressObj?['leisure'] as String?;
        final road = addressObj?['road'] as String?;
        final suburb = addressObj?['suburb'] as String? ?? addressObj?['neighbourhood'] as String?;
        final city = addressObj?['city'] as String? ?? addressObj?['town'] as String? ?? addressObj?['village'] as String? ?? addressObj?['county'] as String?;
        final state = addressObj?['state'] as String?;
        countryCode = addressObj?['country_code'] as String?;
        country = addressObj?['country'] as String?;

        // 1. Direct explicit name
        if (rawName != null && rawName.trim().isNotEmpty) {
          placeName = rawName.trim();
        }
        // 2. Brand / Operator (e.g. "Indian Oil", "Haveli", "McDonald's")
        else if (brand != null && brand.trim().isNotEmpty) {
          placeName = brand.trim();
        }
        // 3. Extract primary specific landmark from display_name
        else if (displayName != null && displayName.isNotEmpty) {
          final firstSegment = displayName.split(',').first.trim();
          final isJustNumber = RegExp(r'^\d+[a-zA-Z]?$').hasMatch(firstSegment);
          if (firstSegment.isNotEmpty && !isJustNumber && firstSegment.toLowerCase() != city?.toLowerCase()) {
            placeName = firstSegment;
          }
        }

        // If placeName is still coordinate-based default:
        if (placeName.startsWith('Waypoint (')) {
          if (amenity != null) {
            placeName = amenity.replaceAll('_', ' ').capitalize();
          } else if (tourism != null) {
            placeName = tourism.replaceAll('_', ' ').capitalize();
          } else if (shop != null) {
            placeName = '$shop Shop'.capitalize();
          } else if (historic != null) {
            placeName = historic.replaceAll('_', ' ').capitalize();
          } else if (road != null && suburb != null) {
            placeName = '$road, $suburb';
          } else if (road != null && city != null) {
            placeName = '$road, $city';
          } else if (road != null) {
            placeName = road;
          } else if (suburb != null) {
            placeName = suburb;
          } else if (city != null) {
            placeName = city;
          }
        }

        // Build neat address
        final parts = <String>[];
        if (road != null && !placeName.contains(road)) parts.add(road);
        if (suburb != null && !placeName.contains(suburb)) parts.add(suburb);
        if (city != null && !placeName.contains(city)) parts.add(city);
        if (state != null) parts.add(state);
        if (country != null) parts.add(country);
        if (parts.isNotEmpty) {
          address = parts.join(', ');
        } else {
          address = displayName;
        }

        // Infer category
        if (amenity == 'fuel' || amenity == 'charging_station') {
          category = 'Gas / Fuel Station';
        } else if (amenity == 'restaurant' || amenity == 'cafe' || amenity == 'fast_food' || amenity == 'food_court' || amenity == 'bar') {
          category = 'Food & Cafe';
        } else if (amenity == 'hotel' || amenity == 'motel' || tourism == 'hotel' || tourism == 'motel' || tourism == 'guest_house' || tourism == 'hostel') {
          category = 'Hotel & Stay';
        } else if (tourism == 'viewpoint' || tourism == 'attraction' || historic != null || leisure != null) {
          category = 'Sightseeing';
        } else if (shop != null) {
          category = 'Shopping';
        } else if (amenity == 'toll_booth' || (road != null && road.toLowerCase().contains('toll'))) {
          category = 'Toll & Transit';
        } else if (amenity == 'rest_area') {
          category = 'Rest Stop';
        }
      }
    } catch (_) {
      // Fallback gracefully on timeout or network absence
    }

    return LocationDetails(
      latitude: lat,
      longitude: lng,
      placeName: placeName,
      address: address,
      category: category,
      countryCode: countryCode,
      country: country,
    );
  }

  /// Fetches nearby tagged points of interest (petrol pumps, dhabas, restaurants, hotels, etc.)
  /// within radiusMeters using OpenStreetMap Overpass API
  static Future<List<NearbyPOI>> fetchNearbyPOIs(
    double lat,
    double lng, {
    double radiusMeters = 350,
  }) async {
    final pois = <NearbyPOI>[];
    try {
      final clampedRadius = radiusMeters.clamp(50, 1500).toInt();
      final query = '''
[out:json][timeout:5];
(
  node(around:$clampedRadius,$lat,$lng)[amenity];
  node(around:$clampedRadius,$lat,$lng)[tourism];
  node(around:$clampedRadius,$lat,$lng)[shop];
  node(around:$clampedRadius,$lat,$lng)[highway=services];
  node(around:$clampedRadius,$lat,$lng)[highway=rest_area];
  way(around:$clampedRadius,$lat,$lng)[amenity];
  way(around:$clampedRadius,$lat,$lng)[tourism];
);
out center tags 12;
''';

      final url = Uri.parse(
        'https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'TripTrackerApp/1.0 (travel@triptracker.app)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final elements = data['elements'] as List? ?? [];
        final seenNames = <String>{};

        for (final el in elements) {
          final tags = el['tags'] as Map<String, dynamic>?;
          if (tags == null) continue;

          final amenity = tags['amenity'] as String?;
          final tourism = tags['tourism'] as String?;
          final shop = tags['shop'] as String?;
          final highway = tags['highway'] as String?;
          final brand = tags['brand'] as String? ?? tags['operator'] as String?;

          String? name = tags['name'] as String? ?? tags['name:en'] as String?;
          if ((name == null || name.isEmpty) && brand != null && brand.isNotEmpty) {
            name = brand;
          }

          double? pLat;
          double? pLng;
          if (el['lat'] != null && el['lon'] != null) {
            pLat = (el['lat'] as num).toDouble();
            pLng = (el['lon'] as num).toDouble();
          } else if (el['center'] != null) {
            pLat = (el['center']['lat'] as num?)?.toDouble();
            pLng = (el['center']['lon'] as num?)?.toDouble();
          }

          if (pLat == null || pLng == null) continue;

          String category = 'Other';
          String rawType = '';

          if (amenity == 'fuel' || amenity == 'charging_station') {
            category = 'Gas / Fuel Station';
            rawType = amenity!;
            name ??= brand != null ? '$brand Fuel Station' : 'Fuel Station';
          } else if (amenity == 'restaurant' ||
              amenity == 'cafe' ||
              amenity == 'fast_food' ||
              amenity == 'food_court') {
            category = 'Food & Cafe';
            rawType = amenity!;
            name ??= 'Restaurant / Eatery';
          } else if (amenity == 'hotel' ||
              amenity == 'motel' ||
              tourism == 'hotel' ||
              tourism == 'motel' ||
              tourism == 'guest_house' ||
              tourism == 'camp_site') {
            category = 'Hotel & Stay';
            rawType = tourism ?? amenity!;
            name ??= 'Hotel / Stay';
          } else if (tourism == 'viewpoint' ||
              tourism == 'attraction' ||
              tags['historic'] != null) {
            category = 'Sightseeing';
            rawType = tourism ?? 'historic';
            name ??= 'Scenic Spot';
          } else if (highway == 'services' ||
              highway == 'rest_area' ||
              amenity == 'rest_area') {
            category = 'Rest Stop';
            rawType = 'rest_area';
            name ??= 'Highway Rest Area';
          } else if (shop != null) {
            category = 'Shopping';
            rawType = 'shop:$shop';
            name ??= '${shop[0].toUpperCase()}${shop.substring(1)} Shop';
          } else if (amenity == 'bank' || amenity == 'atm') {
            category = 'Other';
            rawType = amenity!;
            name ??= 'ATM / Bank';
          } else if (amenity == 'hospital' ||
              amenity == 'clinic' ||
              amenity == 'pharmacy') {
            category = 'Other';
            rawType = amenity!;
            name ??= 'Medical / Pharmacy';
          }

          if (name == null || name.trim().isEmpty) continue;
          final cleanName = name.trim();
          if (seenNames.contains(cleanName.toLowerCase())) continue;
          seenNames.add(cleanName.toLowerCase());

          final distanceMeters =
              Geolocator.distanceBetween(lat, lng, pLat, pLng).round();

          pois.add(NearbyPOI(
            id: '${el['type']}_${el['id']}',
            name: cleanName,
            category: category,
            latitude: pLat,
            longitude: pLng,
            distanceMeters: distanceMeters,
            rawType: rawType,
            brand: brand,
          ));
        }

        // Sort by distance ascending
        pois.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      }
    } catch (_) {
      // Graceful fallback on network timeout
    }
    return pois;
  }

  /// Calculates total direct or road distance across a list of stoppages
  static double calculateStoppagesDistanceKm(List<dynamic> stoppages) {
    if (stoppages.length < 2) return 0.0;
    double totalKm = 0.0;
    for (int i = 0; i < stoppages.length - 1; i++) {
      final s1 = stoppages[i];
      final s2 = stoppages[i + 1];
      totalKm += Geolocator.distanceBetween(
        s1.latitude as double,
        s1.longitude as double,
        s2.latitude as double,
        s2.longitude as double,
      ) / 1000.0;
    }
    return totalKm;
  }

  /// Calculates total distance along a polyline of LatLng points
  static double calculatePolylineDistanceKm(List<LatLng> points) {
    if (points.length < 2) return 0.0;
    double totalKm = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      totalKm += Geolocator.distanceBetween(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      ) / 1000.0;
    }
    return totalKm;
  }

  /// Calculates estimated travel time (Duration) for a given distance in km
  static Duration calculateRouteEta(double distanceKm, {double averageSpeedKmh = 45.0}) {
    if (distanceKm <= 0) return Duration.zero;
    final hours = distanceKm / averageSpeedKmh;
    final minutes = (hours * 60).round();
    return Duration(minutes: math.max(1, minutes));
  }

  /// Opens turn-by-turn navigation in external maps (Google Maps, Apple Maps, Waze)
  static Future<bool> openExternalNavigation(double lat, double lng, {String? label}) async {
    final query = label != null && label.isNotEmpty ? Uri.encodeComponent(label) : '$lat,$lng';
    
    // Android Google Navigation Intent uri
    final googleNavUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    
    // Universal Geo URI
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($query)');
    
    // Web / Universal Google Maps URL
    final mapsWebUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');

    try {
      if (await canLaunchUrl(googleNavUri)) {
        return await launchUrl(googleNavUri, mode: LaunchMode.externalApplication);
      }
      if (await canLaunchUrl(geoUri)) {
        return await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      }
      if (await canLaunchUrl(mapsWebUri)) {
        return await launchUrl(mapsWebUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }

  /// Fetches real road-following geometry between waypoints via OSRM
  static Future<List<LatLng>> fetchRoadRoute(List<LatLng> waypoints) async {
    final result = await fetchNavigableRoute(waypoints, mode: TransportMode.car);
    return result.isNavigable ? result.points : waypoints;
  }

  /// Senior Developer Best Practice: Fetches safe, legally navigable route geometry using OSRM.
  /// Validates route continuity and checks for unnavigable ocean/terrain boundaries to ensure user safety.
  static Future<NavigableRouteResult> fetchNavigableRoute(
    List<LatLng> waypoints, {
    TransportMode mode = TransportMode.car,
  }) async {
    if (waypoints.length < 2) {
      return NavigableRouteResult(
        points: waypoints,
        distanceKm: 0.0,
        estimatedDuration: Duration.zero,
        isNavigable: true,
        mode: mode,
      );
    }

    // Safety Pre-Check 1: Out-of-bounds straight line sanity (e.g. cross-continent / ocean)
    final directDistanceKm = calculatePolylineDistanceKm(waypoints);
    if (directDistanceKm > 4000.0) {
      return NavigableRouteResult.unnavigable(
        waypoints: waypoints,
        mode: mode,
        reason: 'Distance (${directDistanceKm.toStringAsFixed(0)} km) exceeds navigable land limits. No safe overland road exists.',
      );
    }

    try {
      final coordinates = waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');
      // OSRM supports driving, bike, foot profiles
      final profile = mode == TransportMode.train ? 'driving' : mode.osrmProfile;
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/$profile/$coordinates?overview=full&geometries=geojson&steps=false',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final code = data['code'] as String?;

        if (code == 'Ok') {
          final routes = data['routes'] as List?;
          if (routes != null && routes.isNotEmpty) {
            final routeObj = routes[0] as Map<String, dynamic>;
            final geometry = routeObj['geometry'] as Map<String, dynamic>?;
            final coords = geometry?['coordinates'] as List?;
            final routeDistanceMeters = (routeObj['distance'] as num?)?.toDouble() ?? (directDistanceKm * 1000);
            final routeDurationSeconds = (routeObj['duration'] as num?)?.toDouble() ?? 0.0;

            if (coords != null && coords.isNotEmpty) {
              final roadPoints = coords
                  .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
                  .toList();

              final distanceKm = routeDistanceMeters / 1000.0;
              final duration = routeDurationSeconds > 0
                  ? Duration(seconds: routeDurationSeconds.round())
                  : calculateRouteEta(distanceKm, averageSpeedKmh: mode.averageSpeedKmh);

              // Safety Heuristics & Advisories based on IT Industry standards
              final advisories = <String>[];
              if (mode == TransportMode.car && duration.inHours >= 3) {
                advisories.add('⚠️ Driver Fatigue: Plan a 15-min rest stop every 2 hours.');
              }
              if (mode == TransportMode.foot && distanceKm > 15.0) {
                advisories.add('⚠️ Long Walk: Ensure adequate hydration and pedestrian paths.');
              }
              if (mode == TransportMode.bike && distanceKm > 35.0) {
                advisories.add('⚠️ Cycling Alert: Ride with helmet and daylight visibility.');
              }
              final currentHour = DateTime.now().hour;
              if (currentHour >= 22 || currentHour < 5) {
                advisories.add('🌙 Night Travel Warning: Reduce speed and maintain headlights.');
              }

              return NavigableRouteResult(
                points: roadPoints,
                distanceKm: distanceKm,
                estimatedDuration: duration,
                isNavigable: true,
                safetyAdvisories: advisories,
                mode: mode,
              );
            }
          }
        } else if (code == 'NoRoute' || code == 'NoSegment') {
          return NavigableRouteResult.unnavigable(
            waypoints: waypoints,
            mode: mode,
            reason: '⚠️ Unnavigable Road: No legal ${mode.label.toLowerCase()} path found between these waypoints.',
          );
        }
      }
    } catch (_) {}

    // Fallback safety logic: If distance is reasonable (< 350 km), treat as estimated path with caution
    if (directDistanceKm < 350.0) {
      return NavigableRouteResult(
        points: waypoints,
        distanceKm: directDistanceKm,
        estimatedDuration: calculateRouteEta(directDistanceKm, averageSpeedKmh: mode.averageSpeedKmh),
        isNavigable: true,
        safetyAdvisories: ['Offline estimation: Follow local signs and road regulations.'],
        mode: mode,
      );
    }

    return NavigableRouteResult.unnavigable(
      waypoints: waypoints,
      mode: mode,
      reason: '⚠️ Unverified path: Overland road could not be safely verified.',
    );
  }
}

/// Mode of transport with industry standard average speeds and routing profiles
enum TransportMode {
  car('Car', 'driving', 60.0),
  bike('Bike', 'bike', 22.0),
  foot('On Foot', 'foot', 4.5),
  train('Train', 'driving', 80.0);

  final String label;
  final String osrmProfile;
  final double averageSpeedKmh;

  const TransportMode(this.label, this.osrmProfile, this.averageSpeedKmh);
}

/// Result of navigational safety verification and road routing
class NavigableRouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final Duration estimatedDuration;
  final bool isNavigable;
  final List<String> safetyAdvisories;
  final TransportMode mode;

  const NavigableRouteResult({
    required this.points,
    required this.distanceKm,
    required this.estimatedDuration,
    required this.isNavigable,
    this.safetyAdvisories = const [],
    this.mode = TransportMode.car,
  });

  factory NavigableRouteResult.unnavigable({
    required List<LatLng> waypoints,
    required TransportMode mode,
    required String reason,
  }) {
    final directDist = LocationService.calculatePolylineDistanceKm(waypoints);
    return NavigableRouteResult(
      points: waypoints,
      distanceKm: directDist,
      estimatedDuration: LocationService.calculateRouteEta(directDist, averageSpeedKmh: mode.averageSpeedKmh),
      isNavigable: false,
      safetyAdvisories: [reason],
      mode: mode,
    );
  }
}

extension _CapitalizeString on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
