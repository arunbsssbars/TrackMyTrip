class VoiceJournalMemo {
  final String id;
  final String tripId;
  final String title;
  final Duration duration;
  final String audioUri;
  final DateTime recordedAt;
  final String? transcriptSummary;
  final String authorName;

  const VoiceJournalMemo({
    required this.id,
    required this.tripId,
    required this.title,
    required this.duration,
    required this.audioUri,
    required this.recordedAt,
    this.transcriptSummary,
    this.authorName = 'Expedition Member',
  });

  String get formattedDuration {
    final mins = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  VoiceJournalMemo copyWith({
    String? id,
    String? tripId,
    String? title,
    Duration? duration,
    String? audioUri,
    DateTime? recordedAt,
    String? transcriptSummary,
    String? authorName,
  }) {
    return VoiceJournalMemo(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      audioUri: audioUri ?? this.audioUri,
      recordedAt: recordedAt ?? this.recordedAt,
      transcriptSummary: transcriptSummary ?? this.transcriptSummary,
      authorName: authorName ?? this.authorName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tripId': tripId,
        'title': title,
        'durationMs': duration.inMilliseconds,
        'audioUri': audioUri,
        'recordedAt': recordedAt.toIso8601String(),
        'transcriptSummary': transcriptSummary,
        'authorName': authorName,
      };

  factory VoiceJournalMemo.fromJson(Map<String, dynamic> json) {
    return VoiceJournalMemo(
      id: json['id'] as String? ?? '',
      tripId: json['tripId'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Memo',
      duration: Duration(milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0),
      audioUri: json['audioUri'] as String? ?? '',
      recordedAt: json['recordedAt'] != null
          ? DateTime.tryParse(json['recordedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      transcriptSummary: json['transcriptSummary'] as String?,
      authorName: json['authorName'] as String? ?? 'Expedition Member',
    );
  }
}
