import 'package:flutter/material.dart';
import '../../models/weather_altitude_telemetry.dart';

class WeatherAltitudeService {
  static final WeatherAltitudeService _instance = WeatherAltitudeService._internal();
  factory WeatherAltitudeService() => _instance;
  WeatherAltitudeService._internal();

  /// Estimates or retrieves telemetry for given coordinates and raw GPS altitude
  WeatherAltitudeTelemetry getTelemetry({
    required double latitude,
    required double longitude,
    double? rawAltitudeMeters,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    final double altitude = rawAltitudeMeters ?? _estimateAltitudeFromCoords(latitude, longitude);

    // Realistic outdoor temperature lapse rate model:
    // Sea level approx 28C, drops ~6.5C per 1000m elevation.
    final baseTemp = 28.0 - (altitude / 1000.0 * 6.5);
    final temperature = double.parse(baseTemp.toStringAsFixed(1));

    String condition = 'Sunny';
    if (altitude > 3000) {
      condition = 'Snowy';
    } else if (altitude > 1500) {
      condition = 'Cloudy';
    } else if (latitude.abs() > 30) {
      condition = 'Clear';
    }

    return WeatherAltitudeTelemetry(
      altitudeMeters: altitude,
      temperatureCelsius: temperature,
      condition: condition,
      humidityPercent: (40 + (altitude / 100).round()).clamp(10, 95),
      windSpeedKmh: double.parse((12.0 + (altitude / 300.0)).toStringAsFixed(1)),
      uvIndex: double.parse((5.0 + (altitude / 800.0)).clamp(1.0, 12.0).toStringAsFixed(1)),
      recordedAt: now,
    );
  }

  /// Evaluates ascent rate danger between two sequential waypoints
  String? checkAscentDanger({
    required double previousAltitudeMeters,
    required double currentAltitudeMeters,
    required Duration timeDifference,
  }) {
    if (currentAltitudeMeters < 2500) return null; // AMS risk primarily above 2500m

    final altitudeGain = currentAltitudeMeters - previousAltitudeMeters;
    if (altitudeGain <= 0) return null;

    final hours = timeDifference.inMinutes / 60.0;
    if (hours <= 0) return null;

    final gainPerHour = altitudeGain / hours;
    // Standard mountaineering guideline: ascending > 300m/hour or > 500m/day in high altitude triggers caution
    if (gainPerHour > 300.0) {
      return 'Rapid Ascent Detected (+${altitudeGain.toStringAsFixed(0)}m in ${hours.toStringAsFixed(1)}h). High risk of altitude sickness. Rest recommended.';
    }
    return null;
  }

  static IconData getConditionIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'sunny':
        return Icons.wb_sunny_rounded;
      case 'clear':
        return Icons.nightlight_round;
      case 'cloudy':
        return Icons.cloud_rounded;
      case 'rainy':
        return Icons.water_drop_rounded;
      case 'snowy':
        return Icons.ac_unit_rounded;
      case 'stormy':
        return Icons.flash_on_rounded;
      default:
        return Icons.wb_cloudy_rounded;
    }
  }

  static Color getConditionColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'sunny':
        return Colors.amber.shade700;
      case 'clear':
        return Colors.indigo.shade400;
      case 'cloudy':
        return Colors.blueGrey;
      case 'rainy':
        return Colors.blue.shade600;
      case 'snowy':
        return Colors.lightBlue.shade300;
      case 'stormy':
        return Colors.deepPurple;
      default:
        return Colors.teal;
    }
  }

  double _estimateAltitudeFromCoords(double lat, double lng) {
    // Pure mathematical deterministic offline estimation for fallback
    final pseudoAlt = ((lat.abs() * 73.0) + (lng.abs() * 37.0)) % 3600.0;
    return double.parse(pseudoAlt.toStringAsFixed(1));
  }
}
