class WeatherAltitudeTelemetry {
  final double altitudeMeters;
  final double temperatureCelsius;
  final String condition; // 'Sunny', 'Rainy', 'Cloudy', 'Snowy', 'Stormy', 'Clear'
  final int humidityPercent;
  final double windSpeedKmh;
  final double uvIndex;
  final DateTime recordedAt;

  const WeatherAltitudeTelemetry({
    required this.altitudeMeters,
    required this.temperatureCelsius,
    required this.condition,
    this.humidityPercent = 50,
    this.windSpeedKmh = 10.0,
    this.uvIndex = 3.0,
    required this.recordedAt,
  });

  double get altitudeFeet => altitudeMeters * 3.28084;
  double get temperatureFahrenheit => (temperatureCelsius * 9 / 5) + 32;

  bool get isHighAltitudeRisk => altitudeMeters >= 2500.0;
  bool get isExtremeAltitudeRisk => altitudeMeters >= 3500.0;
  bool get isHighUvRisk => uvIndex >= 8.0;

  String get altitudeRiskAdvice {
    if (isExtremeAltitudeRisk) {
      return 'Extreme Altitude: Risk of Acute Mountain Sickness (AMS). Rest and hydrate.';
    } else if (isHighAltitudeRisk) {
      return 'High Altitude: Maintain steady pace and drink plenty of water.';
    }
    return 'Altitude Normal: Optimal aerobic conditions.';
  }

  Map<String, dynamic> toJson() => {
        'altitudeMeters': altitudeMeters,
        'temperatureCelsius': temperatureCelsius,
        'condition': condition,
        'humidityPercent': humidityPercent,
        'windSpeedKmh': windSpeedKmh,
        'uvIndex': uvIndex,
        'recordedAt': recordedAt.toIso8601String(),
      };

  factory WeatherAltitudeTelemetry.fromJson(Map<String, dynamic> json) {
    return WeatherAltitudeTelemetry(
      altitudeMeters: (json['altitudeMeters'] as num?)?.toDouble() ?? 0.0,
      temperatureCelsius: (json['temperatureCelsius'] as num?)?.toDouble() ?? 20.0,
      condition: json['condition'] as String? ?? 'Clear',
      humidityPercent: (json['humidityPercent'] as num?)?.toInt() ?? 50,
      windSpeedKmh: (json['windSpeedKmh'] as num?)?.toDouble() ?? 10.0,
      uvIndex: (json['uvIndex'] as num?)?.toDouble() ?? 3.0,
      recordedAt: json['recordedAt'] != null
          ? DateTime.tryParse(json['recordedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  WeatherAltitudeTelemetry copyWith({
    double? altitudeMeters,
    double? temperatureCelsius,
    String? condition,
    int? humidityPercent,
    double? windSpeedKmh,
    double? uvIndex,
    DateTime? recordedAt,
  }) {
    return WeatherAltitudeTelemetry(
      altitudeMeters: altitudeMeters ?? this.altitudeMeters,
      temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
      condition: condition ?? this.condition,
      humidityPercent: humidityPercent ?? this.humidityPercent,
      windSpeedKmh: windSpeedKmh ?? this.windSpeedKmh,
      uvIndex: uvIndex ?? this.uvIndex,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }
}
