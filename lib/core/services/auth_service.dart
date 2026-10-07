import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';
import '../../models/auth_user.dart';
import '../../models/user_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'local_storage_service.dart';
import 'push_notification_service.dart';
import 'user_service.dart';

import 'security_service.dart';
import '../utils/security_sanitizer.dart';
import 'cloud_trip_sync_service.dart';
import 'media_cache_service.dart';
import 'map_tile_cache_service.dart';
import 'tombstone_service.dart';

class AuthService {
  final LocalStorageService _storage;
  final PushNotificationService _pushService;
  final SecurityService _securityService;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '731719697818-ljfrslc4gbqucih5n6qfnt01v5ct3nsj.apps.googleusercontent.com',
    clientId: (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
        ? '731719697818-l1okiq2d45hp9bkepcjb3c5tof6sdsuh.apps.googleusercontent.com'
        : null,
  );

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
        username: (match['username'] as String?) ?? identifier,
        displayName: (match['displayName'] as String?) ?? (match['name'] as String?) ?? 'Traveler',
        email: (match['email'] as String?) ?? identifier,
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
        
        String displayName = userCredential.user!.displayName ?? 'Google User';
        String username = userCredential.user!.email!.split('@').first;
        String? phone;
        String? bio;
        String colorHex = '0xFF4285F4';
        String? photoUrl = userCredential.user!.photoURL;

        try {
          final fs = _firestore;
          if (fs != null) {
            final doc = await fs.collection('users').doc(userCredential.user!.uid).get();
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

        final googleAuthUser = AuthUser(
          id: userCredential.user!.uid,
          username: username,
          displayName: displayName,
          email: userCredential.user!.email!,
          photoUrl: photoUrl,
          phone: phone,
          bio: bio,
          provider: AuthProviderType.google,
          createdAt: DateTime.now(),
          colorHex: colorHex,
          token: 'google_token',
        );
        
        await _storage.switchUser(googleAuthUser.id);
        await _storage.saveAuthSession(googleAuthUser);
        _syncToUserProfile(googleAuthUser);
        return googleAuthUser;
      } on FirebaseAuthException catch (e) {
        if (kDebugMode) debugPrint('[AuthService] Firebase Auth error: ${e.code} - ${e.message}');
        throw Exception(e.message ?? 'Authentication failed (${e.code})');
      } catch (e) {
        if (kDebugMode) debugPrint('[AuthService] Google Sign-In error: $e');
        if (e.toString().contains('Google Sign-In aborted')) {
          rethrow;
        }
        throw Exception(e.toString().replaceAll('Exception: ', ''));
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
    // 1. Immediately clear local auth session & state so UI logout is instantaneous
    await _storage.clearAuthSession();
    await _storage.switchUser(null);
    UserService.resetCurrentUser();

    // 2. Perform remote Firebase and Google sign-out in parallel with 2s timeout
    try {
      await Future.wait([
        if (_firebaseAuth != null) _firebaseAuth!.signOut(),
        _googleSignIn.signOut(),
      ]).timeout(const Duration(seconds: 2), onTimeout: () => []);
    } catch (_) {}
  }

  /// Forensic Account & Local Data Purge (MASVS-STORAGE / GDPR Right to be Forgotten)
  Future<void> forensicWipeAccount() async {
    await signOut();
    await TombstoneService.wipeAll();
    await _securityService.wipeAllSensitiveData(db: _storage.db);
  }

  /// Permanently Deletes User Account and Wipes All Associated Local & Cloud Data
  /// Mandated by Apple App Store Guideline 5.1.1(v) & Google Play Data Safety & GDPR Article 17
  Future<void> deleteAccountAndData({String? userId, String? userEmail}) async {
    final uid = userId ?? _firebaseAuth?.currentUser?.uid ?? currentSession?.id;
    final email = userEmail ?? _firebaseAuth?.currentUser?.email ?? currentSession?.email;
    final fbUser = _firebaseAuth?.currentUser;

    // 1. Clean up user's data from Cloud Firestore & Realtime Database while user is still authenticated!
    // (If fbUser.delete() runs first, request.auth becomes null and Firestore/RTDB reject deletes with permission-denied)
    if (uid != null && uid.isNotEmpty && _firestore != null) {
      try {
        final cleanEmail = email?.trim().toLowerCase();

        // A. Delete trips authored by this user from 'trips' collection
        final q1 = await _firestore!
            .collection('trips')
            .where('creatorId', isEqualTo: uid)
            .get();
        final q2 = await _firestore!
            .collection('trips')
            .where('createdByMemberId', isEqualTo: uid)
            .get();

        final authoredDocs = <String, DocumentSnapshot>{};
        for (final doc in q1.docs) {
          authoredDocs[doc.id] = doc;
        }
        for (final doc in q2.docs) {
          authoredDocs[doc.id] = doc;
        }

        for (final doc in authoredDocs.values) {
          final tripId = doc.id;
          final subcollections = [
            'stoppages',
            'expenses',
            'memories',
            'settlements',
            'audit_logs',
            'proximity_alerts',
            'member_locations',
            'invitations',
          ];
          for (final sub in subcollections) {
            try {
              final subSnap = await _firestore!.collection('trips').doc(tripId).collection(sub).get();
              for (final subDoc in subSnap.docs) {
                await subDoc.reference.delete();
              }
            } catch (_) {}
          }
          // Delete live rooms & RTDB nodes
          try {
            await CloudTripSyncService.deleteRoom(tripId);
          } catch (_) {}
          try {
            await FirebaseDatabase.instance.ref('trips/$tripId').remove();
          } catch (_) {}
          // Delete trip doc
          await doc.reference.delete();
        }

        // B. Purge and delete rooms from 'rooms' collection
        try {
          final roomsSnap = await _firestore!.collection('rooms').get();
          for (final roomDoc in roomsSnap.docs) {
            try {
              final rData = roomDoc.data();
              final pkg = rData['package'] as Map<String, dynamic>?;
              final tripMap = pkg?['trip'] as Map<String, dynamic>?;
              if (tripMap != null) {
                final creatorId = tripMap['creatorId'] ?? tripMap['createdByMemberId'];
                final creatorEmail = (tripMap['creatorEmail'] as String?)?.toLowerCase();
                final tripId = tripMap['id'] as String? ?? roomDoc.id;

                final isCreator = creatorId == uid || (cleanEmail != null && creatorEmail == cleanEmail);
                if (isCreator) {
                  try {
                    await FirebaseDatabase.instance.ref('trips/$tripId').remove();
                  } catch (_) {}
                  try {
                    await FirebaseDatabase.instance.ref('rooms/${roomDoc.id}').remove();
                  } catch (_) {}
                  await roomDoc.reference.delete();
                } else {
                  // User was a member: remove from room package
                  final members = (tripMap['members'] as List?)?.whereType<Map<String, dynamic>>().toList();
                  if (members != null) {
                    final originalLen = members.length;
                    members.removeWhere((m) =>
                        m['id'] == uid ||
                        (cleanEmail != null && (m['email'] as String?)?.toLowerCase() == cleanEmail));
                    if (members.length != originalLen) {
                      tripMap['members'] = members;
                      await roomDoc.reference.update({'package.trip.members': members});
                    }
                  }
                }
              }
            } catch (_) {}
          }
        } catch (_) {}

        // C. Remove user from trips where they were a companion
        final companionTrips = await _firestore!
            .collection('trips')
            .where('memberIds', arrayContains: uid)
            .get();
        for (final doc in companionTrips.docs) {
          try {
            await doc.reference.update({
              'memberIds': FieldValue.arrayRemove([uid]),
              if (cleanEmail != null && cleanEmail.isNotEmpty)
                'memberEmails': FieldValue.arrayRemove([cleanEmail]),
            });
          } catch (_) {}
        }

        if (cleanEmail != null && cleanEmail.isNotEmpty) {
          final emailCompanionTrips = await _firestore!
              .collection('trips')
              .where('memberEmails', arrayContains: cleanEmail)
              .get();
          for (final doc in emailCompanionTrips.docs) {
            try {
              await doc.reference.update({
                'memberIds': FieldValue.arrayRemove([uid]),
                'memberEmails': FieldValue.arrayRemove([cleanEmail]),
              });
            } catch (_) {}
          }
        }

        // D. Purge invitations sent or received by this user
        try {
          final inv1 = await _firestore!.collection('invitations').where('inviterId', isEqualTo: uid).get();
          for (final d in inv1.docs) {
            await d.reference.delete();
          }
          final inv2 = await _firestore!.collection('invitations').where('inviteeId', isEqualTo: uid).get();
          for (final d in inv2.docs) {
            await d.reference.delete();
          }
          if (cleanEmail != null && cleanEmail.isNotEmpty) {
            final inv3 = await _firestore!.collection('invitations').where('inviteeEmail', isEqualTo: cleanEmail).get();
            for (final d in inv3.docs) {
              await d.reference.delete();
            }
          }
        } catch (_) {}

        // E. Purge proximity alerts created by this user
        try {
          final alerts = await _firestore!.collection('proximity_alerts').where('senderMemberId', isEqualTo: uid).get();
          for (final d in alerts.docs) {
            await d.reference.delete();
          }
        } catch (_) {}

        // F. Delete user profile doc from users collection
        await _firestore!.collection('users').doc(uid).delete();

        // G. Clean up RTDB user node and push tokens
        try {
          await FirebaseDatabase.instance.ref('users/$uid').remove();
          await FirebaseDatabase.instance.ref('push_tokens/$uid').remove();
        } catch (_) {}
      } catch (e) {
        if (kDebugMode) debugPrint('[AuthService] Cloud Firestore user purge error: $e');
      }
    }

    // 2. If Firebase Auth is active, delete the Firebase Auth user now
    if (fbUser != null) {
      try {
        await fbUser.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          throw Exception('Please sign out and sign in again before deleting your account for security verification.');
        }
        throw Exception(e.message ?? 'Failed to delete authentication account.');
      } catch (e) {
        throw Exception('Account deletion error: $e');
      }
    }

    // 3. Clear local storage, database tables, and auth session cleanly BEFORE unlinking DB file
    try {
      await _storage.clearAuthSession();
      await _storage.db.wipeDatabase();
      await MediaCacheService.wipeAllMediaCache();
      await MapTileCacheService.clearCache();
      if (uid != null && uid.isNotEmpty) {
        await _storage.deleteRegisteredUser(uid);
      }
      if (email != null && email.isNotEmpty) {
        await _storage.deleteRegisteredUser(email);
      }
      await _storage.switchUser(null);
      UserService.resetCurrentUser();
      // Wipe tombstone memory + SharedPreferences so a newly registered / re-logging
      // user on this same device does NOT inherit the previous session's tombstones,
      // which caused the "ghost deletion" bug where all their trips showed a deletion
      // banner on first click and then disappeared.
      await TombstoneService.wipeAll();
      await _securityService.wipeAllSensitiveData(db: _storage.db);
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] Local data wipe error: $e');
    }

    // 4. Remote Google Sign-Out
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  /// Syncs the current or provided user to Firestore users collection with full search tokens
  Future<void> syncCurrentUserToFirestore([AuthUser? authUser]) async {
    final user = authUser ?? currentSession;
    if (user == null) return;
    await _syncToUserProfile(user);
  }

  Future<void> _syncToUserProfile(AuthUser authUser) async {
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

    // 1. Sync to local SQLite storage & session
    try {
      await _storage.saveAuthSession(authUser);
      await _storage.db.saveRegisteredUser({
        'id': authUser.id,
        'email': authUser.email,
        'username': authUser.username,
        'displayName': authUser.displayName,
        'phone': authUser.phone,
        'bio': authUser.bio,
        'colorHex': authUser.colorHex,
      });
    } catch (_) {}

    // 2. Save User Document and FCM Token to Firestore with merge: true
    try {
      final docId = _firebaseAuth?.currentUser?.uid ?? authUser.id;
      final fs = _firestore;
      if (fs != null && docId.isNotEmpty) {
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

        final updateData = <String, dynamic>{
          'id': docId,
          'username': authUser.username.toLowerCase(),
          'displayName': authUser.displayName,
          'email': authUser.email.toLowerCase(),
          'colorHex': authUser.colorHex ?? '0xFF0D9488',
          'searchTokens': searchTokens.toList(),
          if (token != null) 'fcmToken': token,
          'lastActive': FieldValue.serverTimestamp(),
        };

        if (authUser.phone != null && authUser.phone!.trim().isNotEmpty) {
          updateData['phone'] = authUser.phone!.trim();
        }
        if (authUser.bio != null && authUser.bio!.trim().isNotEmpty) {
          updateData['bio'] = authUser.bio!.trim();
        }

        await fs.collection('users').doc(docId).set(updateData, SetOptions(merge: true));

        if (kDebugMode) {
          debugPrint('[AuthService] Successfully synced user $docId (${authUser.username}) to Firestore with merge: true');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthService] Error syncing user to Firestore: $e');
      }
    }
  }
}
