import '../core/services/media_cache_service.dart';

class Memory {
  final String id;
  final String tripId;
  final String stoppageId;
  final String uploadedByMemberId;
  final String mediaPath;        // Local path OR remote URL (whichever is currently resolved)
  final String? localPath;       // Always points to permanent local copy (null if preset/URL)
  final String? remoteUrl;       // Populated after cloud upload
  final MediaUploadStatus uploadStatus; // local / uploading / uploaded / failed
  final String? caption;
  final DateTime createdAt;
  final List<String> likedByMemberIds;

  const Memory({
    required this.id,
    required this.tripId,
    required this.stoppageId,
    required this.uploadedByMemberId,
    required this.mediaPath,
    this.localPath,
    this.remoteUrl,
    this.uploadStatus = MediaUploadStatus.local,
    this.caption,
    required this.createdAt,
    this.likedByMemberIds = const [],
  });

  /// True if this memory's photo is a user-picked image (not a preset URL)
  bool get isUserPhoto =>
      localPath != null || (mediaPath.isNotEmpty && !mediaPath.startsWith('http'));

  /// The best available display path: remote if uploaded, local otherwise
  String get displayPath => remoteUrl ?? mediaPath;

  Memory copyWith({
    String? id,
    String? tripId,
    String? stoppageId,
    String? uploadedByMemberId,
    String? mediaPath,
    String? localPath,
    String? remoteUrl,
    MediaUploadStatus? uploadStatus,
    String? caption,
    DateTime? createdAt,
    List<String>? likedByMemberIds,
  }) {
    return Memory(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      stoppageId: stoppageId ?? this.stoppageId,
      uploadedByMemberId: uploadedByMemberId ?? this.uploadedByMemberId,
      mediaPath: mediaPath ?? this.mediaPath,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      caption: caption ?? this.caption,
      createdAt: createdAt ?? this.createdAt,
      likedByMemberIds: likedByMemberIds ?? this.likedByMemberIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'stoppageId': stoppageId,
      'uploadedByMemberId': uploadedByMemberId,
      'mediaPath': mediaPath,
      'localPath': localPath,
      'remoteUrl': remoteUrl,
      'uploadStatus': uploadStatus.name,
      'caption': caption,
      'createdAt': createdAt.toIso8601String(),
      'likedByMemberIds': likedByMemberIds,
    };
  }

  factory Memory.fromJson(Map<String, dynamic> json) {
    MediaUploadStatus status = MediaUploadStatus.local;
    try {
      status = MediaUploadStatus.values.firstWhere(
        (e) => e.name == (json['uploadStatus'] as String? ?? 'local'),
        orElse: () => MediaUploadStatus.local,
      );
    } catch (_) {}

    return Memory(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      stoppageId: json['stoppageId'] as String,
      uploadedByMemberId: json['uploadedByMemberId'] as String,
      mediaPath: json['mediaPath'] as String,
      localPath: json['localPath'] as String?,
      remoteUrl: json['remoteUrl'] as String?,
      uploadStatus: status,
      caption: json['caption'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      likedByMemberIds: (json['likedByMemberIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
