enum InvitationStatus {
  pending,
  accepted,
  declined,
}

class TripInvitation {
  final String id;
  final String tripId;
  final String tripTitle;
  final String inviterId;
  final String inviterName;
  final String inviteeUsername;
  final String? inviteePhone;
  final DateTime createdAt;
  final InvitationStatus status;
  final Map<String, dynamic>? tripJson;

  const TripInvitation({
    required this.id,
    required this.tripId,
    required this.tripTitle,
    required this.inviterId,
    required this.inviterName,
    required this.inviteeUsername,
    this.inviteePhone,
    required this.createdAt,
    this.status = InvitationStatus.pending,
    this.tripJson,
  });

  TripInvitation copyWith({
    String? id,
    String? tripId,
    String? tripTitle,
    String? inviterId,
    String? inviterName,
    String? inviteeUsername,
    String? inviteePhone,
    DateTime? createdAt,
    InvitationStatus? status,
    Map<String, dynamic>? tripJson,
  }) {
    return TripInvitation(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      tripTitle: tripTitle ?? this.tripTitle,
      inviterId: inviterId ?? this.inviterId,
      inviterName: inviterName ?? this.inviterName,
      inviteeUsername: inviteeUsername ?? this.inviteeUsername,
      inviteePhone: inviteePhone ?? this.inviteePhone,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      tripJson: tripJson ?? this.tripJson,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'tripTitle': tripTitle,
      'inviterId': inviterId,
      'inviterName': inviterName,
      'inviteeUsername': inviteeUsername,
      'inviteePhone': inviteePhone,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'tripJson': tripJson,
    };
  }

  factory TripInvitation.fromJson(Map<String, dynamic> json) {
    return TripInvitation(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      tripTitle: json['tripTitle'] as String,
      inviterId: json['inviterId'] as String,
      inviterName: json['inviterName'] as String,
      inviteeUsername: json['inviteeUsername'] as String,
      inviteePhone: json['inviteePhone'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      status: InvitationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => InvitationStatus.pending,
      ),
      tripJson: json['tripJson'] as Map<String, dynamic>?,
    );
  }
}
