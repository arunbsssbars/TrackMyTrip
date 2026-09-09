enum AuthProviderType {
  email,
  google,
  guest,
}

class AuthUser {
  final String id;
  final String username;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String? phone;
  final String? bio;
  final String? colorHex;
  final AuthProviderType provider;
  final DateTime createdAt;
  final String? token;

  const AuthUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.phone,
    this.bio,
    this.colorHex,
    required this.provider,
    required this.createdAt,
    this.token,
  });

  String get handle => username.startsWith('@') ? username : '@$username';

  AuthUser copyWith({
    String? id,
    String? username,
    String? displayName,
    String? email,
    String? photoUrl,
    String? phone,
    String? bio,
    String? colorHex,
    AuthProviderType? provider,
    DateTime? createdAt,
    String? token,
  }) {
    return AuthUser(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      colorHex: colorHex ?? this.colorHex,
      provider: provider ?? this.provider,
      createdAt: createdAt ?? this.createdAt,
      token: token ?? this.token,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'phone': phone,
      'bio': bio,
      'colorHex': colorHex,
      'provider': provider.name,
      'createdAt': createdAt.toIso8601String(),
      'token': token,
    };
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String,
      photoUrl: json['photoUrl'] as String?,
      phone: json['phone'] as String?,
      bio: json['bio'] as String?,
      colorHex: json['colorHex'] as String?,
      provider: AuthProviderType.values.firstWhere(
        (e) => e.name == json['provider'],
        orElse: () => AuthProviderType.email,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      token: json['token'] as String?,
    );
  }
}
