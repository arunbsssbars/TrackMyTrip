enum AlertType {
  stoppageArrival,
  stoppageDeparture,
  companionStray,
  sosEmergency,
  general,
  // Activity notifications
  invitation,
  invitationAccepted,
  invitationRejected,
  memberJoined,
  memberLeft,
  billAdded,
  settlementRecorded,
  memoryAdded,
  stoppageAdded,
  locationShared,
}

enum AlertUrgency {
  low,
  normal,
  high,
  critical,
}

class ProximityAlert {
  final String id;
  final String tripId;
  final AlertType type;
  final String title;
  final String message;
  final String senderMemberId;
  final String senderName;
  final double? latitude;
  final double? longitude;
  final double? distanceMeters;
  final DateTime timestamp;
  final AlertUrgency urgency;
  final bool isRead;
  final String? recipientId;
  final bool isOutgoing;

  const ProximityAlert({
    required this.id,
    required this.tripId,
    required this.type,
    required this.title,
    required this.message,
    required this.senderMemberId,
    required this.senderName,
    this.latitude,
    this.longitude,
    this.distanceMeters,
    required this.timestamp,
    this.urgency = AlertUrgency.normal,
    this.isRead = false,
    this.recipientId,
    this.isOutgoing = false,
  });

  ProximityAlert copyWith({
    String? id,
    String? tripId,
    AlertType? type,
    String? title,
    String? message,
    String? senderMemberId,
    String? senderName,
    double? latitude,
    double? longitude,
    double? distanceMeters,
    DateTime? timestamp,
    AlertUrgency? urgency,
    bool? isRead,
    String? recipientId,
    bool? isOutgoing,
  }) {
    return ProximityAlert(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      senderMemberId: senderMemberId ?? this.senderMemberId,
      senderName: senderName ?? this.senderName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      timestamp: timestamp ?? this.timestamp,
      urgency: urgency ?? this.urgency,
      isRead: isRead ?? this.isRead,
      recipientId: recipientId ?? this.recipientId,
      isOutgoing: isOutgoing ?? this.isOutgoing,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'type': type.name,
      'title': title,
      'message': message,
      'senderMemberId': senderMemberId,
      'senderName': senderName,
      'latitude': latitude,
      'longitude': longitude,
      'distanceMeters': distanceMeters,
      'timestamp': timestamp.toIso8601String(),
      'urgency': urgency.name,
      'isRead': isRead,
      if (recipientId != null) 'recipientId': recipientId,
      'isOutgoing': isOutgoing,
    };
  }

  factory ProximityAlert.fromJson(Map<String, dynamic> json) {
    return ProximityAlert(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      type: AlertType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AlertType.general,
      ),
      title: json['title'] as String,
      message: json['message'] as String,
      senderMemberId: json['senderMemberId'] as String? ?? 'User',
      senderName: json['senderName'] as String? ?? 'Companion',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      urgency: AlertUrgency.values.firstWhere(
        (e) => e.name == json['urgency'],
        orElse: () => AlertUrgency.normal,
      ),
      isRead: json['isRead'] as bool? ?? false,
      recipientId: json['recipientId'] as String?,
      isOutgoing: json['isOutgoing'] as bool? ?? false,
    );
  }
}
