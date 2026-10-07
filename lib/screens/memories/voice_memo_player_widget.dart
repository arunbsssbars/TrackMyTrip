import 'package:flutter/material.dart';
import '../../models/voice_journal_memo.dart';
import '../../core/services/audio_journal_service.dart';

class VoiceMemoPlayerWidget extends StatefulWidget {
  final VoiceJournalMemo memo;
  final VoidCallback? onDelete;

  const VoiceMemoPlayerWidget({
    super.key,
    required this.memo,
    this.onDelete,
  });

  @override
  State<VoiceMemoPlayerWidget> createState() => _VoiceMemoPlayerWidgetState();
}

class _VoiceMemoPlayerWidgetState extends State<VoiceMemoPlayerWidget> {
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying && _currentPosition >= widget.memo.duration) {
        _currentPosition = Duration.zero;
      }
    });
  }

  void _onSeek(double val) {
    setState(() {
      _currentPosition = Duration(milliseconds: val.round());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final memo = widget.memo;
    final totalMs = memo.duration.inMilliseconds.toDouble();
    final currentMs = _currentPosition.inMilliseconds.toDouble().clamp(0.0, totalMs > 0 ? totalMs : 1.0);

    final positionLabel = AudioJournalService().formatSeconds(_currentPosition.inSeconds);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Row
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(Icons.mic_rounded, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memo.title,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'By ${memo.authorName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (widget.onDelete != null)
                  IconButton(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    tooltip: 'Delete Voice Memo',
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Slider Row
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: currentMs,
                min: 0.0,
                max: totalMs > 0 ? totalMs : 1.0,
                onChanged: totalMs > 0 ? _onSeek : null,
              ),
            ),

            // Controls & Duration Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.filled(
                  onPressed: _togglePlayPause,
                  icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  tooltip: _isPlaying ? 'Pause' : 'Play',
                  iconSize: 22,
                ),
                Flexible(
                  child: Text(
                    '$positionLabel / ${memo.formattedDuration}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Transcript text block if present
            if (memo.transcriptSummary != null && memo.transcriptSummary!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        memo.transcriptSummary!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
