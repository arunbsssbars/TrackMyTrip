import '../../models/timeline_playback_state.dart';

class RouteReplayService {
  static final RouteReplayService _instance = RouteReplayService._internal();
  factory RouteReplayService() => _instance;
  RouteReplayService._internal();

  /// Steps to next waypoint
  TimelinePlaybackState stepForward({
    required TimelinePlaybackState state,
    required List<String> waypointTitles,
  }) {
    if (state.totalWaypoints <= 0) return state;
    final nextIdx = (state.currentIndex + 1).clamp(0, state.totalWaypoints - 1);
    final isEnd = nextIdx >= state.totalWaypoints - 1;

    return state.copyWith(
      currentIndex: nextIdx,
      isPlaying: !isEnd && state.isPlaying,
      currentWaypointTitle: nextIdx < waypointTitles.length ? waypointTitles[nextIdx] : '',
    );
  }

  /// Steps to previous waypoint
  TimelinePlaybackState stepBackward({
    required TimelinePlaybackState state,
    required List<String> waypointTitles,
  }) {
    if (state.totalWaypoints <= 0) return state;
    final prevIdx = (state.currentIndex - 1).clamp(0, state.totalWaypoints - 1);

    return state.copyWith(
      currentIndex: prevIdx,
      currentWaypointTitle: prevIdx < waypointTitles.length ? waypointTitles[prevIdx] : '',
    );
  }

  /// Jumps directly to an indexed waypoint
  TimelinePlaybackState seekTo({
    required TimelinePlaybackState state,
    required int index,
    required List<String> waypointTitles,
  }) {
    final clampedIdx = index.clamp(0, (state.totalWaypoints - 1).clamp(0, 999999));
    return state.copyWith(
      currentIndex: clampedIdx,
      currentWaypointTitle: clampedIdx < waypointTitles.length ? waypointTitles[clampedIdx] : '',
    );
  }

  /// Cycles speed multiplier: 1.0x -> 2.0x -> 5.0x -> 1.0x
  double cycleSpeedMultiplier(double currentSpeed) {
    if (currentSpeed < 1.5) return 2.0;
    if (currentSpeed < 3.0) return 5.0;
    return 1.0;
  }
}
