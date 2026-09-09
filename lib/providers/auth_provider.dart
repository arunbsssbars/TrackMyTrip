import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/auth_service.dart';
import '../core/services/user_service.dart';
import '../models/auth_user.dart';
import 'trip_provider.dart';

class AuthNotifier extends StateNotifier<AsyncValue<AuthUser?>> {
  final AuthService _authService;
  final Ref _ref;

  AuthNotifier(this._authService, this._ref) : super(const AsyncValue.loading()) {
    _initAuthSession();
  }

  void _initAuthSession() {
    try {
      final user = _authService.currentSession;
      state = AsyncValue.data(user);
      if (user != null) {
        _ref.read(currentUserProvider.notifier).state = UserService.getCurrentUser();
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  bool get isAuthenticated => state.valueOrNull != null;
  AuthUser? get currentUser => state.valueOrNull;

  Future<void> login({
    required String emailOrUsername,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.signInWithEmail(
        emailOrUsername: emailOrUsername,
        password: password,
      );
      state = AsyncValue.data(user);
      _ref.read(currentUserProvider.notifier).state = UserService.getCurrentUser();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
    String? phone,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.signUpWithEmail(
        name: name,
        username: username,
        email: email,
        password: password,
        phone: phone,
      );
      state = AsyncValue.data(user);
      _ref.read(currentUserProvider.notifier).state = UserService.getCurrentUser();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> loginWithGoogle({String? email, String? name}) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.signInWithGoogle(
        googleEmail: email,
        googleName: name,
      );
      state = AsyncValue.data(user);
      _ref.read(currentUserProvider.notifier).state = UserService.getCurrentUser();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> loginAsGuest() async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.signInAsGuest();
      state = AsyncValue.data(user);
      _ref.read(currentUserProvider.notifier).state = UserService.getCurrentUser();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<bool> resetPassword({required String email, required String newPassword}) async {
    return _authService.resetPassword(email: email, newPassword: newPassword);
  }

  Future<void> logout() async {
    await _authService.signOut();
    state = const AsyncValue.data(null);
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return AuthService(storage);
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<AuthUser?>>((ref) {
  final service = ref.watch(authServiceProvider);
  return AuthNotifier(service, ref);
});
