class TimelinePlaybackState {
  final int currentIndex;
  final int totalWaypoints;
  final bool isPlaying;
  final double speedMultiplier;
  final String currentWaypointTitle;
  final DateTime? currentTimestamp;

  const TimelinePlaybackState({
    this.currentIndex = 0,
    required this.totalWaypoints,
    this.isPlaying = false,
    this.speedMultiplier = 1.0,
    this.currentWaypointTitle = '',
    this.currentTimestamp,
  });

  double get progressRatio =>
      totalWaypoints > 1 ? (currentIndex / (totalWaypoints - 1)).clamp(0.0, 1.0) : 0.0;

  bool get isAtStart => currentIndex == 0;
  bool get isAtEnd => totalWaypoints > 0 && currentIndex >= totalWaypoints - 1;

  TimelinePlaybackState copyWith({
    int? currentIndex,
    int? totalWaypoints,
    bool? isPlaying,
    double? speedMultiplier,
    String? currentWaypointTitle,
    DateTime? currentTimestamp,
  }) {
    return TimelinePlaybackState(
      currentIndex: currentIndex ?? this.currentIndex,
      totalWaypoints: totalWaypoints ?? this.totalWaypoints,
      isPlaying: isPlaying ?? this.isPlaying,
      speedMultiplier: speedMultiplier ?? this.speedMultiplier,
      currentWaypointTitle: currentWaypointTitle ?? this.currentWaypointTitle,
      currentTimestamp: currentTimestamp ?? this.currentTimestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'currentIndex': currentIndex,
        'totalWaypoints': totalWaypoints,
        'isPlaying': isPlaying,
        'speedMultiplier': speedMultiplier,
        'currentWaypointTitle': currentWaypointTitle,
        'currentTimestamp': currentTimestamp?.toIso8601String(),
      };

  factory TimelinePlaybackState.fromJson(Map<String, dynamic> json) {
    return TimelinePlaybackState(
      currentIndex: (json['currentIndex'] as num?)?.toInt() ?? 0,
      totalWaypoints: (json['totalWaypoints'] as num?)?.toInt() ?? 0,
      isPlaying: json['isPlaying'] as bool? ?? false,
      speedMultiplier: (json['speedMultiplier'] as num?)?.toDouble() ?? 1.0,
      currentWaypointTitle: json['currentWaypointTitle'] as String? ?? '',
      currentTimestamp: json['currentTimestamp'] != null
          ? DateTime.tryParse(json['currentTimestamp'] as String)
          : null,
    );
  }
}
