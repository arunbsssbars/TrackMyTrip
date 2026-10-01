class UserProfile {
  final String id;
  final String username;
  final String displayName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? colorHex;
  final String? bio;
  final double? latitude;
  final double? longitude;
  final DateTime? lastSeen;

  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.colorHex,
    this.bio,
    this.latitude,
    this.longitude,
    this.lastSeen,
  });

  String get handle => username.startsWith('@') ? username : '@$username';

  String get initials {
    final clean = displayName.trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clean[0].toUpperCase();
  }

  UserProfile copyWith({
    String? id,
    String? username,
    String? displayName,
    String? email,
    String? phone,
    String? avatarUrl,
    String? colorHex,
    String? bio,
    double? latitude,
    double? longitude,
    DateTime? lastSeen,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      colorHex: colorHex ?? this.colorHex,
      bio: bio ?? this.bio,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'colorHex': colorHex,
      'bio': bio,
      'latitude': latitude,
      'longitude': longitude,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      colorHex: json['colorHex'] as String?,
      bio: json['bio'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      lastSeen: json['lastSeen'] != null ? DateTime.tryParse(json['lastSeen'] as String) : null,
    );
  }
}
