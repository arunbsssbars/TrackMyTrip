enum InvitationStatus {
  pending,
  accepted,
  declined,
  rejected,
}

class TripInvitation {
  final String id;
  final String tripId;
  final String tripTitle;
  final String inviterId;
  final String inviterName;
  final String? inviteeId;
  final String inviteeUsername;
  final String? inviteeEmail;
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
    this.inviteeId,
    required this.inviteeUsername,
    this.inviteeEmail,
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
    String? inviteeId,
    String? inviteeUsername,
    String? inviteeEmail,
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
      inviteeId: inviteeId ?? this.inviteeId,
      inviteeUsername: inviteeUsername ?? this.inviteeUsername,
      inviteeEmail: inviteeEmail ?? this.inviteeEmail,
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
      'inviteeId': inviteeId,
      'inviteeUsername': inviteeUsername,
      'inviteeEmail': inviteeEmail,
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
      inviteeId: json['inviteeId'] as String?,
      inviteeUsername: json['inviteeUsername'] as String? ?? 'Traveler',
      inviteeEmail: json['inviteeEmail'] as String?,
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
