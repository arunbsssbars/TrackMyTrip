import '../../models/voice_journal_memo.dart';

class AudioJournalService {
  static final AudioJournalService _instance = AudioJournalService._internal();
  factory AudioJournalService() => _instance;
  AudioJournalService._internal();

  /// Formats seconds to mm:ss player duration label
  String formatSeconds(int totalSeconds) {
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Calculates playback progress ratio
  double calculateProgressRatio(Duration position, Duration total) {
    if (total.inMilliseconds <= 0) return 0.0;
    return (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Creates a voice journal memo template with metadata
  VoiceJournalMemo createVoiceMemo({
    required String tripId,
    required String title,
    required Duration duration,
    required String audioUri,
    String? transcriptSummary,
    String authorName = 'Expedition Member',
  }) {
    return VoiceJournalMemo(
      id: 'memo_${DateTime.now().millisecondsSinceEpoch}',
      tripId: tripId,
      title: title.trim(),
      duration: duration,
      audioUri: audioUri.trim(),
      recordedAt: DateTime.now(),
      transcriptSummary: transcriptSummary?.trim(),
      authorName: authorName.trim(),
    );
  }
}
