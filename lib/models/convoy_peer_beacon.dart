class ConvoyPeerBeacon {
  final String peerId;
  final String displayName;
  final String vehiclePlateOrRole;
  final double latitude;
  final double longitude;
  final DateTime lastPingTime;
  final int batteryPercent;
  final bool isSosActive;
  final String? sosMessage;

  const ConvoyPeerBeacon({
    required this.peerId,
    required this.displayName,
    required this.vehiclePlateOrRole,
    required this.latitude,
    required this.longitude,
    required this.lastPingTime,
    this.batteryPercent = 100,
    this.isSosActive = false,
    this.sosMessage,
  });

  bool get isStale => DateTime.now().difference(lastPingTime).inMinutes >= 10;

  ConvoyPeerBeacon copyWith({
    String? peerId,
    String? displayName,
    String? vehiclePlateOrRole,
    double? latitude,
    double? longitude,
    DateTime? lastPingTime,
    int? batteryPercent,
    bool? isSosActive,
    String? sosMessage,
  }) {
    return ConvoyPeerBeacon(
      peerId: peerId ?? this.peerId,
      displayName: displayName ?? this.displayName,
      vehiclePlateOrRole: vehiclePlateOrRole ?? this.vehiclePlateOrRole,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastPingTime: lastPingTime ?? this.lastPingTime,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      isSosActive: isSosActive ?? this.isSosActive,
      sosMessage: sosMessage ?? this.sosMessage,
    );
  }

  Map<String, dynamic> toJson() => {
        'peerId': peerId,
        'displayName': displayName,
        'vehiclePlateOrRole': vehiclePlateOrRole,
        'latitude': latitude,
        'longitude': longitude,
        'lastPingTime': lastPingTime.toIso8601String(),
        'batteryPercent': batteryPercent,
        'isSosActive': isSosActive,
        'sosMessage': sosMessage,
      };

  factory ConvoyPeerBeacon.fromJson(Map<String, dynamic> json) {
    return ConvoyPeerBeacon(
      peerId: json['peerId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Convoy Member',
      vehiclePlateOrRole: json['vehiclePlateOrRole'] as String? ?? 'Vehicle',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      lastPingTime: json['lastPingTime'] != null
          ? DateTime.tryParse(json['lastPingTime'] as String) ?? DateTime.now()
          : DateTime.now(),
      batteryPercent: (json['batteryPercent'] as num?)?.toInt() ?? 100,
      isSosActive: json['isSosActive'] as bool? ?? false,
      sosMessage: json['sosMessage'] as String?,
    );
  }
}
