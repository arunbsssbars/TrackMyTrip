import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bridges Firebase Email/Password Auth with the local [AuthUser] model.
///
/// Every sign-up / sign-in call creates or retrieves a Firebase Auth user,
/// returning the stable Firebase UID that is used in Firestore security rules.
/// The raw Firebase credential is never stored locally — only the UID is kept
/// alongside the session in SQLite via [LocalStorageService].
class FirebaseAuthService {
  final fb.FirebaseAuth _auth;

  FirebaseAuthService({fb.FirebaseAuth? auth})
      : _auth = auth ?? fb.FirebaseAuth.instance;

  /// The currently signed-in Firebase user, or null if not authenticated.
  fb.User? get currentFirebaseUser => _auth.currentUser;

  /// The stable Firebase UID for the current user, used as the Firestore
  /// document owner key in security rules.
  String? get currentUid => _auth.currentUser?.uid;

  /// Whether a Firebase Auth session is active.
  bool get isFirebaseAuthenticated => _auth.currentUser != null;

  // ---------------------------------------------------------------------------
  // Sign-Up
  // ---------------------------------------------------------------------------

  /// Creates a new Firebase Auth account with [email] and [password].
  ///
  /// Returns the Firebase [UserCredential] on success.
  /// Throws a [FirebaseAuthServiceException] with a human-readable message on
  /// failure (e.g. email-already-in-use, weak-password).
  Future<fb.UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      // Update Firebase profile display name
      await credential.user?.updateDisplayName(displayName.trim());
      return credential;
    } on fb.FirebaseAuthException catch (e) {
      throw FirebaseAuthServiceException(_mapFirebaseError(e.code));
    }
  }

  // ---------------------------------------------------------------------------
  // Sign-In
  // ---------------------------------------------------------------------------

  /// Signs in an existing Firebase Auth user with [email] and [password].
  Future<fb.UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on fb.FirebaseAuthException catch (e) {
      throw FirebaseAuthServiceException(_mapFirebaseError(e.code));
    }
  }

  // ---------------------------------------------------------------------------
  // Sign-Out
  // ---------------------------------------------------------------------------

  /// Signs out the current Firebase Auth user.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // Password Reset
  // ---------------------------------------------------------------------------

  /// Sends a Firebase password-reset email to [email].
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(
        email: email.trim().toLowerCase(),
      );
    } on fb.FirebaseAuthException catch (e) {
      throw FirebaseAuthServiceException(_mapFirebaseError(e.code));
    }
  }

  // ---------------------------------------------------------------------------
  // Auth State Stream
  // ---------------------------------------------------------------------------

  /// Emits the Firebase [User] whenever the auth state changes.
  Stream<fb.User?> get authStateChanges => _auth.authStateChanges();

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Maps Firebase error codes to user-facing English messages.
  String _mapFirebaseError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email already exists. Please log in.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
        return 'No account found with that email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a moment and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return 'Authentication error ($code). Please try again.';
    }
  }
}

/// Typed exception thrown by [FirebaseAuthService] with a user-readable message.
class FirebaseAuthServiceException implements Exception {
  final String message;
  const FirebaseAuthServiceException(this.message);

  @override
  String toString() => 'FirebaseAuthServiceException: $message';
}

// ---------------------------------------------------------------------------
// Riverpod Provider
// ---------------------------------------------------------------------------

final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) {
  return FirebaseAuthService();
});

/// Exposes the current Firebase UID as a Riverpod provider.
/// Returns null when not signed in — useful for gating Firestore operations.
final currentFirebaseUidProvider = Provider<String?>((ref) {
  return fb.FirebaseAuth.instance.currentUser?.uid;
});
