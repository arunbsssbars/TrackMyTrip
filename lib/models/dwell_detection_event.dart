class DwellDetectionEvent {
  final double latitude;
  final double longitude;
  final DateTime startTime;
  final DateTime lastPingTime;
  final double radiusMeters;
  final bool isConfirmedStoppage;

  const DwellDetectionEvent({
    required this.latitude,
    required this.longitude,
    required this.startTime,
    required this.lastPingTime,
    this.radiusMeters = 50.0,
    this.isConfirmedStoppage = false,
  });

  Duration get dwellDuration => lastPingTime.difference(startTime);
  int get dwellDurationMinutes => dwellDuration.inMinutes;

  bool get isEligibleForPrompt => dwellDurationMinutes >= 5;

  String get formattedDuration {
    final mins = dwellDuration.inMinutes;
    if (mins < 60) return '$mins mins';
    final hours = mins ~/ 60;
    final remainingMins = mins % 60;
    return '${hours}h ${remainingMins}m';
  }

  DwellDetectionEvent copyWith({
    double? latitude,
    double? longitude,
    DateTime? startTime,
    DateTime? lastPingTime,
    double? radiusMeters,
    bool? isConfirmedStoppage,
  }) {
    return DwellDetectionEvent(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      startTime: startTime ?? this.startTime,
      lastPingTime: lastPingTime ?? this.lastPingTime,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      isConfirmedStoppage: isConfirmedStoppage ?? this.isConfirmedStoppage,
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'startTime': startTime.toIso8601String(),
        'lastPingTime': lastPingTime.toIso8601String(),
        'radiusMeters': radiusMeters,
        'isConfirmedStoppage': isConfirmedStoppage,
      };

  factory DwellDetectionEvent.fromJson(Map<String, dynamic> json) {
    return DwellDetectionEvent(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      startTime: json['startTime'] != null
          ? DateTime.tryParse(json['startTime'] as String) ?? DateTime.now()
          : DateTime.now(),
      lastPingTime: json['lastPingTime'] != null
          ? DateTime.tryParse(json['lastPingTime'] as String) ?? DateTime.now()
          : DateTime.now(),
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 50.0,
      isConfirmedStoppage: json['isConfirmedStoppage'] as bool? ?? false,
    );
  }
}
