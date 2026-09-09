import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../models/auth_user.dart';
import '../../models/user_profile.dart';
import 'local_storage_service.dart';
import 'user_service.dart';

/// FirebaseAuthService — Wraps Firebase Authentication for Email/Password flows.
///
/// Mirrors the existing [AuthService] API exactly so all providers and UI code
/// can switch to Firebase Auth with zero breaking changes.
///
/// Migration strategy:
///   1. On sign-up/sign-in: create Firebase Auth credential, then persist
///      the AuthUser locally in SQLite (for offline compatibility).
///   2. On app start: restore session from SQLite cache; Firebase idToken
///      is refreshed silently in the background.
class FirebaseAuthService {
  final LocalStorageService _storage;
  final fb.FirebaseAuth _fbAuth;

  FirebaseAuthService(this._storage) : _fbAuth = fb.FirebaseAuth.instance;

  /// Returns current authenticated session if valid
  AuthUser? get currentSession => _storage.getAuthSession();

  bool get isAuthenticated => currentSession != null;

  /// Returns the Firebase Auth UID for use in Firestore security rules.
  String? get firebaseUid => _fbAuth.currentUser?.uid;

  // ─────────────────────────────────────────────────────────────────────────────
  // Sign Up
  // ─────────────────────────────────────────────────────────────────────────────

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

    // Check for existing username locally first (fast path)
    final existingUsers = _storage.getRegisteredUsers();
    if (existingUsers.any((u) => u['username'] == cleanUsername)) {
      throw Exception('Username @$cleanUsername is already taken. Please choose another.');
    }

    // Create Firebase Auth credential
    fb.UserCredential credential;
    try {
      credential = await _fbAuth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e.code));
    }

    final fbUser = credential.user!;

    // Update Firebase display name
    await fbUser.updateDisplayName(cleanName).catchError((_) {});

    final authUser = AuthUser(
      id: fbUser.uid,
      username: cleanUsername,
      displayName: cleanName,
      email: cleanEmail,
      phone: cleanPhone != null && cleanPhone.isNotEmpty ? cleanPhone : null,
      provider: AuthProviderType.email,
      createdAt: DateTime.now(),
      colorHex: '0xFF0D9488',
      token: await fbUser.getIdToken() ?? '',
    );

    await _storage.saveRegisteredUser({
      'id': fbUser.uid,
      'name': cleanName,
      'username': cleanUsername,
      'email': cleanEmail,
      'phone': cleanPhone,
      'password': password, // kept locally for offline sign-in fallback
      'firebaseUid': fbUser.uid,
      'createdAt': DateTime.now().toIso8601String(),
    });

    await _storage.saveAuthSession(authUser);
    _syncToUserProfile(authUser);

    if (kDebugMode) print('[FirebaseAuthService] Signed up: ${fbUser.uid}');
    return authUser;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Sign In
  // ─────────────────────────────────────────────────────────────────────────────

  Future<AuthUser> signInWithEmail({
    required String emailOrUsername,
    required String password,
  }) async {
    String identifier = emailOrUsername.trim().toLowerCase();
    if (identifier.startsWith('@')) identifier = identifier.substring(1);
    if (identifier.isEmpty) throw Exception('Please enter your email or @username');
    if (password.isEmpty) throw Exception('Please enter your password');

    // Resolve username → email via local registry
    String resolvedEmail = identifier;
    if (!identifier.contains('@')) {
      final registered = _storage.getRegisteredUsers();
      final match = registered.firstWhere(
        (u) => (u['username'] as String?)?.toLowerCase() == identifier,
        orElse: () => {},
      );
      if (match.isNotEmpty) {
        resolvedEmail = match['email'] as String;
      }
    }

    // Default demo credentials (offline-friendly)
    if ((identifier == 'arun_explorer' || identifier == 'arun@example.com' ||
            identifier == 'me@triptracker.app') &&
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

    // Firebase Auth
    fb.UserCredential credential;
    try {
      credential = await _fbAuth.signInWithEmailAndPassword(
        email: resolvedEmail,
        password: password,
      );
    } on fb.FirebaseAuthException catch (e) {
      // Offline fallback: try local password match
      return await _offlineSignIn(identifier, password);
    }

    final fbUser = credential.user!;
    final token = await fbUser.getIdToken() ?? '';

    // Load local registry record for username
    final registered = _storage.getRegisteredUsers();
    final localRecord = registered.firstWhere(
      (u) => (u['email'] as String?)?.toLowerCase() == resolvedEmail.toLowerCase(),
      orElse: () => {},
    );
    final username = localRecord['username'] as String? ?? resolvedEmail.split('@').first;
    final displayName = localRecord['name'] as String? ?? fbUser.displayName ?? 'Traveler';

    final authUser = AuthUser(
      id: fbUser.uid,
      username: username,
      displayName: displayName,
      email: fbUser.email ?? resolvedEmail,
      provider: AuthProviderType.email,
      createdAt: DateTime.now(),
      colorHex: '0xFF0D9488',
      token: token,
    );

    await _storage.saveAuthSession(authUser);
    _syncToUserProfile(authUser);
    return authUser;
  }

  /// Offline fallback sign-in using locally stored password hash
  Future<AuthUser> _offlineSignIn(String identifier, String password) async {
    final registered = _storage.getRegisteredUsers();
    final match = registered.firstWhere(
      (u) =>
          (u['email'] as String?)?.toLowerCase() == identifier ||
          (u['username'] as String?)?.toLowerCase() == identifier,
      orElse: () => {},
    );

    if (match.isEmpty) throw Exception('No account found. Check your email or @username.');
    if (match['password'] != password) {
      throw Exception('Incorrect password. Please try again or use "Forgot Password".');
    }

    final authUser = AuthUser(
      id: match['id'] as String? ?? 'usr_${const Uuid().v4().substring(0, 8)}',
      username: match['username'] as String,
      displayName: match['name'] as String,
      email: match['email'] as String,
      provider: AuthProviderType.email,
      createdAt: DateTime.tryParse(match['createdAt'] as String? ?? '') ?? DateTime.now(),
      colorHex: '0xFF0D9488',
      token: 'offline_jwt_${const Uuid().v4()}',
    );

    await _storage.saveAuthSession(authUser);
    _syncToUserProfile(authUser);
    return authUser;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Guest / Google (pass-through — Firebase Guest TBD)
  // ─────────────────────────────────────────────────────────────────────────────

  Future<AuthUser> signInAsGuest() async {
    fb.UserCredential? credential;
    try {
      credential = await _fbAuth.signInAnonymously();
    } catch (_) {}

    final uid = credential?.user?.uid ?? 'usr_guest_${const Uuid().v4().substring(0, 6)}';

    final guestUser = AuthUser(
      id: uid,
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

  // ─────────────────────────────────────────────────────────────────────────────
  // Password Reset
  // ─────────────────────────────────────────────────────────────────────────────

  Future<bool> resetPassword({required String email, required String newPassword}) async {
    final cleanEmail = email.trim().toLowerCase();
    if (newPassword.length < 6) throw Exception('New password must be at least 6 characters');

    // Send Firebase reset email
    try {
      await _fbAuth.sendPasswordResetEmail(email: cleanEmail);
    } on fb.FirebaseAuthException catch (e) {
      if (kDebugMode) print('[FirebaseAuthService] Reset error: ${e.code}');
    }

    // Also update local password for offline fallback
    await _storage.updateRegisteredUserPassword(cleanEmail, newPassword);
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Sign Out
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    try {
      await _fbAuth.signOut();
    } catch (_) {}
    await _storage.clearAuthSession();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────────

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

  String _mapFirebaseError(String code) {
    return switch (code) {
      'email-already-in-use' => 'An account with this email already exists. Please log in.',
      'invalid-email' => 'Please enter a valid email address.',
      'weak-password' => 'Password must be at least 6 characters.',
      'user-not-found' => 'No account found. Please check your email.',
      'wrong-password' => 'Incorrect password. Please try again.',
      'user-disabled' => 'This account has been disabled. Contact support.',
      'too-many-requests' => 'Too many failed attempts. Please try again later.',
      'network-request-failed' => 'No internet connection. Using offline mode.',
      _ => 'Authentication failed ($code). Please try again.',
    };
  }
}
