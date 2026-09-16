import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:google_sign_in/google_sign_in.dart';
import '../../models/auth_user.dart';
import '../../models/user_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'local_storage_service.dart';
import 'push_notification_service.dart';
import 'user_service.dart';

class AuthService {
  final LocalStorageService _storage;
  final PushNotificationService _pushService;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AuthService(this._storage, this._pushService);

  AuthUser? get currentSession => _storage.getAuthSession();
  bool get isAuthenticated => currentSession != null;

  Future<AuthUser> signUpWithEmail({
    required String name,
    required String username,
    required String email,
    required String password,
    String? phone,
  }) async {
    final cleanName = name.trim();
    final cleanUsername = username.trim().toLowerCase().replaceAll('@', '');
    
    if (cleanName.isEmpty) throw Exception('Please enter your full name');
    if (cleanUsername.length < 3) throw Exception('Username must be at least 3 characters');
    
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      await credential.user?.updateDisplayName(cleanName);
      
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
      
      await _storage.saveAuthSession(newUser);
      _syncToUserProfile(newUser);
      return newUser;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? e.toString());
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<AuthUser> signInWithEmail({
    required String emailOrUsername,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: emailOrUsername,
        password: password,
      );
      
      final user = AuthUser(
        id: credential.user!.uid,
        username: emailOrUsername.split('@').first,
        displayName: credential.user!.displayName ?? 'Explorer',
        email: credential.user!.email!,
        provider: AuthProviderType.email,
        createdAt: DateTime.now(),
        colorHex: '0xFF0D9488',
        token: 'firebase_token',
      );
      
      await _storage.saveAuthSession(user);
      _syncToUserProfile(user);
      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? e.toString());
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<AuthUser> signInWithGoogle({String? googleEmail, String? googleName}) async {
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
      
      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      
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
      
      await _storage.saveAuthSession(googleAuthUser);
      _syncToUserProfile(googleAuthUser);
      return googleAuthUser;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? e.toString());
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<AuthUser> signInAsGuest() async {
     try {
       final credential = await _firebaseAuth.signInAnonymously();
       final guestUser = AuthUser(
          id: credential.user!.uid,
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
     } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? e.toString());
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<bool> resetPassword({required String email, required String newPassword}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? e.toString());
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
    await _storage.clearAuthSession();
  }

  void _syncToUserProfile(AuthUser authUser) async {
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

    // Save FCM Token to Firestore
    try {
      final token = await _pushService.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(authUser.id).set({
          'username': authUser.username,
          'displayName': authUser.displayName,
          'email': authUser.email,
          'fcmToken': token,
          'lastActive': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error saving FCM token to Firestore: $e');
    }
  }
}
