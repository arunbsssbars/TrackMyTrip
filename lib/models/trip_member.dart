class TripMember {
  final String id;
  final String name;
  final String? email;
  final String? avatarUrl;
  final String? colorHex;
  final String? phoneNumber;
  final bool isCurrentUser;
  final double? latitude;
  final double? longitude;
  final DateTime? lastSeen;

  const TripMember({
    required this.id,
    required this.name,
    this.email,
    this.avatarUrl,
    this.colorHex,
    this.phoneNumber,
    this.isCurrentUser = false,
    this.latitude,
    this.longitude,
    this.lastSeen,
  });

  bool get hasLocation => latitude != null && longitude != null;

  String get initials => name.trim().isNotEmpty
      ? name.trim().split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase()
      : '?';

  TripMember copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    String? colorHex,
    String? phoneNumber,
    bool? isCurrentUser,
    double? latitude,
    double? longitude,
    DateTime? lastSeen,
  }) {
    return TripMember(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      colorHex: colorHex ?? this.colorHex,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'colorHex': colorHex,
      'phoneNumber': phoneNumber,
      'isCurrentUser': isCurrentUser,
      'latitude': latitude,
      'longitude': longitude,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  factory TripMember.fromJson(Map<String, dynamic> json) {
    return TripMember(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      colorHex: json['colorHex'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      isCurrentUser: json['isCurrentUser'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      lastSeen: json['lastSeen'] != null ? DateTime.tryParse(json['lastSeen'] as String) : null,
    );
  }
}
