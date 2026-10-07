import 'package:flutter/material.dart';
import '../../models/timeline_playback_state.dart';
import '../../core/services/route_replay_service.dart';

class RoutePlaybackControllerCard extends StatefulWidget {
  final List<String> waypointTitles;
  final ValueChanged<int>? onWaypointSelected;

  const RoutePlaybackControllerCard({
    super.key,
    required this.waypointTitles,
    this.onWaypointSelected,
  });

  @override
  State<RoutePlaybackControllerCard> createState() => _RoutePlaybackControllerCardState();
}

class _RoutePlaybackControllerCardState extends State<RoutePlaybackControllerCard> {
  late TimelinePlaybackState _state;
  final RouteReplayService _service = RouteReplayService();

  @override
  void initState() {
    super.initState();
    _state = TimelinePlaybackState(
      currentIndex: 0,
      totalWaypoints: widget.waypointTitles.length,
      currentWaypointTitle: widget.waypointTitles.isNotEmpty ? widget.waypointTitles.first : '',
    );
  }

  void _stepForward() {
    setState(() {
      _state = _service.stepForward(state: _state, waypointTitles: widget.waypointTitles);
    });
    widget.onWaypointSelected?.call(_state.currentIndex);
  }

  void _stepBackward() {
    setState(() {
      _state = _service.stepBackward(state: _state, waypointTitles: widget.waypointTitles);
    });
    widget.onWaypointSelected?.call(_state.currentIndex);
  }

  void _seek(double val) {
    final idx = val.round();
    setState(() {
      _state = _service.seekTo(state: _state, index: idx, waypointTitles: widget.waypointTitles);
    });
    widget.onWaypointSelected?.call(_state.currentIndex);
  }

  void _togglePlayPause() {
    setState(() {
      if (_state.isAtEnd) {
        _state = _service.seekTo(state: _state, index: 0, waypointTitles: widget.waypointTitles);
      }
      _state = _state.copyWith(isPlaying: !_state.isPlaying);
    });
  }

  void _cycleSpeed() {
    setState(() {
      final nextSpeed = _service.cycleSpeedMultiplier(_state.speedMultiplier);
      _state = _state.copyWith(speedMultiplier: nextSpeed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = widget.waypointTitles.length;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar: Waypoint title & step counter
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(Icons.route_rounded, color: theme.colorScheme.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _state.currentWaypointTitle.isNotEmpty
                            ? _state.currentWaypointTitle
                            : 'Trip Replay',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Waypoint ${_state.currentIndex + 1} of $count',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Speed Chip Button
                TextButton(
                  onPressed: _cycleSpeed,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(44, 44),
                  ),
                  child: Text(
                    '${_state.speedMultiplier.toStringAsFixed(0)}x',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Scrubber Slider
            if (count > 1)
              Slider(
                value: _state.currentIndex.toDouble().clamp(0.0, (count - 1).toDouble()),
                min: 0.0,
                max: (count - 1).toDouble(),
                divisions: count - 1,
                onChanged: _seek,
              ),

            // Playback Transport Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _state.isAtStart ? null : _stepBackward,
                  icon: const Icon(Icons.skip_previous_rounded),
                  tooltip: 'Previous Waypoint',
                  iconSize: 28,
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _togglePlayPause,
                  icon: Icon(_state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  tooltip: _state.isPlaying ? 'Pause' : 'Play',
                  iconSize: 32,
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _state.isAtEnd ? null : _stepForward,
                  icon: const Icon(Icons.skip_next_rounded),
                  tooltip: 'Next Waypoint',
                  iconSize: 28,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
