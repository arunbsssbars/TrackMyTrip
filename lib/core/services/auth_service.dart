import 'package:uuid/uuid.dart';
import '../../models/auth_user.dart';
import '../../models/user_profile.dart';
import 'local_storage_service.dart';
import 'user_service.dart';

class AuthService {
  final LocalStorageService _storage;

  AuthService(this._storage);

  /// Returns current authenticated session if valid
  AuthUser? get currentSession => _storage.getAuthSession();

  bool get isAuthenticated => currentSession != null;

  /// Sign Up with Email & Password
  Future<AuthUser> signUpWithEmail({
    required String name,
    required String username,
    required String email,
    required String password,
    String? phone,
  }) async {
    final cleanName = name.trim();
    final cleanUsername = username.trim().toLowerCase().replaceAll('@', '');
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phone?.trim();

    if (cleanName.isEmpty) throw Exception('Please enter your full name');
    if (cleanUsername.length < 3) throw Exception('Username must be at least 3 characters');
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(cleanEmail)) {
      throw Exception('Please enter a valid email address');
    }
    if (password.length < 6) throw Exception('Password must be at least 6 characters');

    // Check existing
    final existingUsers = _storage.getRegisteredUsers();
    if (existingUsers.any((u) => u['email'] == cleanEmail)) {
      throw Exception('An account with this email already exists. Please log in.');
    }
    if (existingUsers.any((u) => u['username'] == cleanUsername)) {
      throw Exception('Username @$cleanUsername is already taken. Please choose another.');
    }

    final userId = 'usr_${const Uuid().v4().substring(0, 8)}';
    final token = 'jwt_${const Uuid().v4()}';

    final newUser = AuthUser(
      id: userId,
      username: cleanUsername,
      displayName: cleanName,
      email: cleanEmail,
      phone: cleanPhone != null && cleanPhone.isNotEmpty ? cleanPhone : null,
      provider: AuthProviderType.email,
      createdAt: DateTime.now(),
      colorHex: '0xFF0D9488',
      token: token,
    );

    // Save registered record & active session
    await _storage.saveRegisteredUser({
      'id': userId,
      'name': cleanName,
      'username': cleanUsername,
      'email': cleanEmail,
      'phone': cleanPhone,
      'password': password,
      'createdAt': DateTime.now().toIso8601String(),
    });

    await _storage.saveAuthSession(newUser);

    // Sync to UserService
    _syncToUserProfile(newUser);

    return newUser;
  }

  /// Sign In with Email or @username + Password
  Future<AuthUser> signInWithEmail({
    required String emailOrUsername,
    required String password,
  }) async {
    String identifier = emailOrUsername.trim().toLowerCase();
    if (identifier.startsWith('@')) {
      identifier = identifier.substring(1);
    }
    if (identifier.isEmpty) throw Exception('Please enter your email or @username');
    if (password.isEmpty) throw Exception('Please enter your password');

    final registered = _storage.getRegisteredUsers();
    final match = registered.firstWhere(
      (u) => (u['email'] as String).toLowerCase() == identifier ||
          (u['username'] as String).toLowerCase() == identifier,
      orElse: () => {},
    );

    // Check default test credentials if empty
    if (match.isEmpty) {
      if ((identifier == 'arun_explorer' || identifier == 'arun@example.com' || identifier == 'me@triptracker.app') &&
          (password == 'password123' || password == '123456')) {
        final defaultUser = AuthUser(
          id: 'usr_me_001',
          username: 'arun_explorer',
          displayName: 'Arun V (Trip Lead)',
          email: 'arun@example.com',
          provider: AuthProviderType.email,
          createdAt: DateTime.now(),
          colorHex: '0xFF0D9488',
          token: 'token_default_123',
        );
        await _storage.saveAuthSession(defaultUser);
        _syncToUserProfile(defaultUser);
        return defaultUser;
      }
      throw Exception('No account found with that email or @username.');
    }

    if (match['password'] != password) {
      throw Exception('Incorrect password. Please try again or tap "Forgot Password".');
    }

    final user = AuthUser(
      id: match['id'] as String? ?? 'usr_${const Uuid().v4().substring(0, 8)}',
      username: match['username'] as String,
      displayName: match['name'] as String,
      email: match['email'] as String,
      provider: AuthProviderType.email,
      createdAt: DateTime.tryParse(match['createdAt'] as String? ?? '') ?? DateTime.now(),
      colorHex: '0xFF0D9488',
      token: 'jwt_${const Uuid().v4()}',
    );

    await _storage.saveAuthSession(user);
    _syncToUserProfile(user);

    return user;
  }

  /// Sign In with Google (Gmail / Google Account)
  Future<AuthUser> signInWithGoogle({
    String? googleEmail,
    String? googleName,
  }) async {
    // Generates verified Google authenticated identity
    final email = googleEmail ?? 'arun.travels@gmail.com';
    final name = googleName ?? 'Arun Google';
    final username = email.split('@').first.replaceAll('.', '_');
    final userId = 'usr_g_${const Uuid().v4().substring(0, 8)}';

    final googleUser = AuthUser(
      id: userId,
      username: username,
      displayName: name,
      email: email,
      photoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      provider: AuthProviderType.google,
      createdAt: DateTime.now(),
      colorHex: '0xFF4285F4', // Google Blue
      token: 'google_oauth_${const Uuid().v4()}',
    );

    // Record account if not exists
    await _storage.saveRegisteredUser({
      'id': userId,
      'name': name,
      'username': username,
      'email': email,
      'provider': 'google',
      'createdAt': DateTime.now().toIso8601String(),
    });

    await _storage.saveAuthSession(googleUser);
    _syncToUserProfile(googleUser);

    return googleUser;
  }

  /// Continue as Guest Traveler
  Future<AuthUser> signInAsGuest() async {
    final guestUser = AuthUser(
      id: 'usr_guest_${const Uuid().v4().substring(0, 6)}',
      username: 'guest_traveler',
      displayName: 'Guest Explorer',
      email: 'guest@triptracker.app',
      provider: AuthProviderType.guest,
      createdAt: DateTime.now(),
      colorHex: '0xFF64748B',
      token: 'guest_token',
    );

    await _storage.saveAuthSession(guestUser);
    _syncToUserProfile(guestUser);

    return guestUser;
  }

  /// Password Recovery / Reset
  Future<bool> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (newPassword.length < 6) throw Exception('New password must be at least 6 characters');

    final updated = await _storage.updateRegisteredUserPassword(cleanEmail, newPassword);
    if (!updated) {
      throw Exception('No registered account found with that email address.');
    }
    return true;
  }

  /// Sign Out and clear active credentials
  Future<void> signOut() async {
    await _storage.clearAuthSession();
  }

  void _syncToUserProfile(AuthUser authUser) {
    final profile = UserProfile(
      id: authUser.id,
      username: authUser.username,
      displayName: authUser.displayName,
      email: authUser.email,
      phone: authUser.phone,
      bio: authUser.bio ?? 'Road tripper & explorer',
      colorHex: authUser.colorHex ?? '0xFF0D9488',
      avatarUrl: authUser.photoUrl,
    );
    UserService.updateCurrentUser(profile);
    UserService.registerUser(profile);
  }
}
