import 'package:flutter/material.dart';

class NearbyPOI {
  final String id;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final int distanceMeters;
  final String? rawType;
  final String? brand;

  const NearbyPOI({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    this.rawType,
    this.brand,
  });

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '$distanceMeters m';
    }
    final km = (distanceMeters / 1000.0).toStringAsFixed(1);
    return '$km km';
  }

  IconData get icon {
    switch (category) {
      case 'Gas / Fuel Station':
        return Icons.local_gas_station_rounded;
      case 'Food & Cafe':
        return Icons.restaurant_rounded;
      case 'Hotel & Stay':
        return Icons.hotel_rounded;
      case 'Sightseeing':
      case 'Viewpoint':
        return Icons.photo_camera_rounded;
      case 'Shopping':
        return Icons.shopping_bag_rounded;
      case 'Toll & Transit':
        return Icons.directions_bus_rounded;
      case 'Rest Stop':
        return Icons.local_cafe_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'latitude': latitude,
        'longitude': longitude,
        'distanceMeters': distanceMeters,
        'rawType': rawType,
        'brand': brand,
      };

  factory NearbyPOI.fromJson(Map<String, dynamic> json) => NearbyPOI(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        distanceMeters: (json['distanceMeters'] as num).toInt(),
        rawType: json['rawType'] as String?,
        brand: json['brand'] as String?,
      );
}
