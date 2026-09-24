import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';
import '../../models/auth_user.dart';
import '../../models/user_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'local_storage_service.dart';
import 'push_notification_service.dart';
import 'user_service.dart';

import 'security_service.dart';
import '../utils/security_sanitizer.dart';

class AuthService {
  final LocalStorageService _storage;
  final PushNotificationService _pushService;
  final SecurityService _securityService;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AuthService(
    this._storage,
    this._pushService, {
    SecurityService? securityService,
  }) : _securityService = securityService ?? SecurityService();

  FirebaseAuth? get _firebaseAuth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  AuthUser? get currentSession {
    final local = _storage.getAuthSession();
    if (local != null) return local;

    // Fallback: If Firebase user is authenticated, synthesize AuthUser
    final fbUser = _firebaseAuth?.currentUser;
    if (fbUser != null && fbUser.email != null) {
      final email = fbUser.email!.trim().toLowerCase();
      final displayName = fbUser.displayName?.isNotEmpty == true
          ? fbUser.displayName!
          : email.split('@').first;
      final isGoogle = fbUser.providerData.any((p) => p.providerId == 'google.com');
      final authUser = AuthUser(
        id: fbUser.uid,
        email: email,
        displayName: displayName,
        username: email.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_'),
        photoUrl: fbUser.photoURL,
        colorHex: '0xFF0D9488',
        provider: isGoogle ? AuthProviderType.google : AuthProviderType.email,
        createdAt: DateTime.now(),
      );
      _storage.saveAuthSession(authUser);
      return authUser;
    }
    return null;
  }
  bool get isAuthenticated => currentSession != null;
  bool get isEmailVerified => _firebaseAuth?.currentUser?.emailVerified ?? true;
  User? get firebaseUser => _firebaseAuth?.currentUser;
  SecurityService get securityService => _securityService;

  Future<AuthUser> signUpWithEmail({
    required String email,
    required String password,
    String? name,
    String? username,
    String? phone,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!SecuritySanitizer.isValidEmail(cleanEmail)) {
      throw Exception('Please enter a valid email address');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }

    // Derive or sanitize full name
    String cleanName = SecuritySanitizer.sanitizeText(name);
    if (cleanName.isEmpty) {
      final emailPrefix = cleanEmail.split('@').first;
      final parts = emailPrefix.split(RegExp(r'[._-]'));
      final formatted = parts
          .where((p) => p.isNotEmpty)
          .map((p) => p.length > 1 ? '${p[0].toUpperCase()}${p.substring(1)}' : p.toUpperCase())
          .join(' ');
      cleanName = formatted.isNotEmpty ? formatted : 'Traveler';
    }

    // Derive or sanitize username handle
    String cleanUsername = (username ?? '').trim().toLowerCase().replaceAll('@', '');
    if (cleanUsername.isEmpty || !SecuritySanitizer.isValidUsername(cleanUsername)) {
      final emailPrefix = cleanEmail.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      cleanUsername = emailPrefix.length >= 3
          ? (emailPrefix.length > 20 ? emailPrefix.substring(0, 20) : emailPrefix)
          : 'user_${emailPrefix}_${const Uuid().v4().substring(0, 4)}';
      if (!SecuritySanitizer.isValidUsername(cleanUsername)) {
        cleanUsername = 'traveler_${const Uuid().v4().substring(0, 6)}';
      }
    }
    
    final fb = _firebaseAuth;
    if (fb != null) {
      try {
        final credential = await fb.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );
        
        await credential.user?.updateDisplayName(cleanName);
        // Dispatch built-in free Firebase email verification link
        await credential.user?.sendEmailVerification();
        
        final newUser = AuthUser(
          id: credential.user!.uid,
          username: cleanUsername,
          displayName: cleanName,
          email: credential.user!.email!,
          phone: phone,
          provider: AuthProviderType.email,
          createdAt: DateTime.now(),
          colorHex: '0xFF0D9488',
          token: 'firebase_token',
        );
        
        await _storage.switchUser(newUser.id);
        await _storage.saveAuthSession(newUser);
        _syncToUserProfile(newUser);
        return newUser;
      } on FirebaseAuthException catch (e) {
        throw Exception(e.message ?? e.toString());
      } catch (e) {
        throw Exception(e.toString());
      }
    } else {
      // Local fallback for unit testing without Firebase
      final existing = _storage.getRegisteredUsers();
      if (existing.any((u) => (u['email'] as String).toLowerCase() == cleanEmail)) {
        throw Exception('An account with this email already exists.');
      }
      if (username != null && username.trim().isNotEmpty &&
          existing.any((u) => (u['username'] as String).toLowerCase() == cleanUsername)) {
        throw Exception('This username is already taken. Please choose another.');
      } else if (existing.any((u) => (u['username'] as String).toLowerCase() == cleanUsername)) {
        cleanUsername = 'u_${const Uuid().v4().substring(0, 8)}';
      }

      final userId = 'usr_${const Uuid().v4().substring(0, 8)}';
      final newUser = AuthUser(
        id: userId,
        username: cleanUsername,
        displayName: cleanName,
        email: cleanEmail,
        phone: phone,
        provider: AuthProviderType.email,
        createdAt: DateTime.now(),
        colorHex: '0xFF0D9488',
        token: 'local_token',
      );

      await _storage.saveRegisteredUser({
        'id': userId,
        'name': cleanName,
        'username': cleanUsername,
        'email': cleanEmail,
        'password': password,
        'phone': phone,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await _storage.switchUser(newUser.id);
      await _storage.saveAuthSession(newUser);
      _syncToUserProfile(newUser);
      return newUser;
    }
  }

  Future<AuthUser> signInWithEmail({
    required String emailOrUsername,
    required String password,
  }) async {
    final identifier = emailOrUsername.trim().toLowerCase();
    if (identifier.isEmpty) throw Exception('Please enter your email or @username');
    if (password.isEmpty) throw Exception('Please enter your password');

    final fb = _firebaseAuth;
    if (fb != null) {
      try {
        final credential = await fb.signInWithEmailAndPassword(
          email: identifier,
          password: password,
        );
        
        String displayName = credential.user!.displayName ?? '';
        String username = identifier.split('@').first;
        String? phone;
        String? bio;
        String colorHex = '0xFF0D9488';
        String? photoUrl = credential.user!.photoURL;

        try {
          final fs = _firestore;
          if (fs != null) {
            final doc = await fs.collection('users').doc(credential.user!.uid).get();
            if (doc.exists && doc.data() != null) {
              final data = doc.data()!;
              final fsName = (data['displayName'] as String? ?? data['name'] as String?)?.trim();
              if (fsName != null && fsName.isNotEmpty) displayName = fsName;
              final fsUser = (data['username'] as String?)?.trim();
              if (fsUser != null && fsUser.isNotEmpty) username = fsUser;
              phone = data['phone'] as String?;
              bio = data['bio'] as String?;
              final fsColor = data['colorHex'] as String?;
              if (fsColor != null && fsColor.isNotEmpty) colorHex = fsColor;
              final fsAvatar = data['avatarUrl'] as String?;
              if (fsAvatar != null && fsAvatar.isNotEmpty) photoUrl = fsAvatar;
            }
          }
        } catch (_) {}

        if (displayName.isEmpty) {
          displayName = username.isNotEmpty ? username : 'Explorer';
        }

        final user = AuthUser(
          id: credential.user!.uid,
          username: username,
          displayName: displayName,
          email: credential.user!.email!,
          phone: phone,
          bio: bio,
          photoUrl: photoUrl,
          provider: AuthProviderType.email,
          createdAt: DateTime.now(),
          colorHex: colorHex,
          token: 'firebase_token',
        );

        await _storage.switchUser(user.id);
        await _storage.saveAuthSession(user);
        _syncToUserProfile(user);
        return user;
      } on FirebaseAuthException catch (e) {
        throw Exception(e.message ?? e.toString());
      } catch (e) {
        throw Exception(e.toString());
      }
    } else {
      // Local fallback for unit testing
      final registered = _storage.getRegisteredUsers();
      final cleanHandle = identifier.replaceAll('@', '');
      final match = registered.firstWhere(
        (u) => (u['email'] as String).toLowerCase() == identifier ||
            (u['username'] as String).toLowerCase() == identifier ||
            (u['username'] as String).toLowerCase() == cleanHandle,
        orElse: () => {},
      );

      if (match.isEmpty) {
        throw Exception('No account found with that email or @username.');
      }

      if (match['password'] != password) {
        throw Exception('Incorrect password. Please try again or tap "Forgot Password".');
      }

      final user = AuthUser(
        id: match['id'] as String? ?? 'usr_local',
        username: match['username'] as String,
        displayName: match['name'] as String,
        email: match['email'] as String,
        provider: AuthProviderType.email,
        createdAt: DateTime.tryParse(match['createdAt'] as String? ?? '') ?? DateTime.now(),
        colorHex: '0xFF0D9488',
        token: 'local_token',
      );

      await _storage.switchUser(user.id);
      await _storage.saveAuthSession(user);
      _syncToUserProfile(user);
      return user;
    }
  }

  Future<AuthUser> signInWithGoogle({String? googleEmail, String? googleName}) async {
    final fb = _firebaseAuth;
    if (fb != null) {
      try {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw Exception('Google Sign-In aborted');
        }
        
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        
        final UserCredential userCredential = await fb.signInWithCredential(credential);
        
        final googleAuthUser = AuthUser(
          id: userCredential.user!.uid,
          username: userCredential.user!.email!.split('@').first,
          displayName: userCredential.user!.displayName ?? 'Google User',
          email: userCredential.user!.email!,
          photoUrl: userCredential.user!.photoURL,
          provider: AuthProviderType.google,
          createdAt: DateTime.now(),
          colorHex: '0xFF4285F4',
          token: 'google_token',
        );
        
        await _storage.switchUser(googleAuthUser.id);
        await _storage.saveAuthSession(googleAuthUser);
        _syncToUserProfile(googleAuthUser);
        return googleAuthUser;
      } on FirebaseAuthException catch (e) {
        throw Exception(e.message ?? e.toString());
      } catch (e) {
        throw Exception(e.toString());
      }
    } else {
      // Local fallback for unit testing
      final email = googleEmail ?? 'arun.travels@gmail.com';
      final name = googleName ?? 'Arun Google';
      final username = email.split('@').first.replaceAll('.', '_');
      const userId = 'usr_g_local';

      final googleUser = AuthUser(
        id: userId,
        username: username,
        displayName: name,
        email: email,
        provider: AuthProviderType.google,
        createdAt: DateTime.now(),
        colorHex: '0xFF4285F4',
        token: 'google_local_token',
      );

      await _storage.switchUser(googleUser.id);
      await _storage.saveAuthSession(googleUser);
      _syncToUserProfile(googleUser);
      return googleUser;
    }
  }

  Future<bool> resetPassword({required String email, required String newPassword}) async {
    final fb = _firebaseAuth;
    if (fb != null) {
      try {
        await fb.sendPasswordResetEmail(email: email);
        return true;
      } on FirebaseAuthException catch (e) {
        throw Exception(e.message ?? e.toString());
      } catch (e) {
        throw Exception(e.toString());
      }
    } else {
      final cleanEmail = email.trim().toLowerCase();
      if (newPassword.length < 6) throw Exception('New password must be at least 6 characters');
      final updated = await _storage.updateRegisteredUserPassword(cleanEmail, newPassword);
      if (!updated) {
        throw Exception('No registered account found with that email address.');
      }
      return true;
    }
  }

  Future<void> signOut() async {
    try {
      await _firebaseAuth?.signOut();
      await _googleSignIn.signOut();
    } catch (_) {}
    await _securityService.wipeAllSensitiveData(db: null);
    await _storage.clearAuthSession();
    await _storage.switchUser(null);
    UserService.resetCurrentUser();
  }

  /// Forensic Account & Local Data Purge (MASVS-STORAGE / GDPR Right to be Forgotten)
  Future<void> forensicWipeAccount() async {
    await signOut();
    await _securityService.wipeAllSensitiveData(db: _storage.db);
  }

  /// Syncs the current or provided user to Firestore users collection with full search tokens
  Future<void> syncCurrentUserToFirestore([AuthUser? authUser]) async {
    final user = authUser ?? currentSession;
    if (user == null) return;
    _syncToUserProfile(user);
  }

  void _syncToUserProfile(AuthUser authUser) async {
    final profile = UserProfile(
      id: authUser.id,
      username: authUser.username,
      displayName: authUser.displayName,
      email: authUser.email,
      phone: authUser.phone,
      bio: (authUser.bio != null && authUser.bio!.trim().isNotEmpty) ? authUser.bio!.trim() : null,
      colorHex: authUser.colorHex ?? '0xFF0D9488',
      avatarUrl: authUser.photoUrl,
    );
    UserService.updateCurrentUser(profile);
    UserService.registerUser(profile);

    // Save User Document and FCM Token to Firestore only if user is actively authenticated
    try {
      final currentUser = _firebaseAuth?.currentUser;
      final fs = _firestore;
      if (currentUser != null && fs != null) {
        String? token;
        try {
          token = await _pushService.getToken();
        } catch (_) {}

        final searchTokens = UserService.generateSearchTokens(
          username: authUser.username,
          displayName: authUser.displayName,
          email: authUser.email,
          phone: authUser.phone,
        );

        await fs.collection('users').doc(currentUser.uid).set({
          'id': currentUser.uid,
          'username': authUser.username.toLowerCase(),
          'displayName': authUser.displayName,
          'email': authUser.email.toLowerCase(),
          'phone': authUser.phone,
          'bio': (authUser.bio != null && authUser.bio!.trim().isNotEmpty) ? authUser.bio!.trim() : null,
          'colorHex': authUser.colorHex ?? '0xFF0D9488',
          'searchTokens': searchTokens.toList(),
          if (token != null) 'fcmToken': token,
          'lastActive': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (kDebugMode) {
          debugPrint('[AuthService] Successfully synced user ${currentUser.uid} (${authUser.username}) to Firestore');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthService] Error syncing user to Firestore: $e');
      }
    }
  }
}
