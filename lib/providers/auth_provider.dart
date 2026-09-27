import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/push_notification_service.dart';
import '../core/services/auth_service.dart';
import '../core/services/user_service.dart';
import '../core/services/firestore_sync_service.dart';
import '../core/services/realtime_sync_service.dart';
import '../core/services/cloud_trip_sync_service.dart';
import '../models/auth_user.dart';
import 'trip_provider.dart';
import 'expense_provider.dart';
import 'stoppage_provider.dart';
import 'memory_provider.dart';
import 'settlement_provider.dart';
import 'invitation_provider.dart';
import 'audit_log_provider.dart';
import '../main.dart';

class AuthNotifier extends StateNotifier<AsyncValue<AuthUser?>> {
  final AuthService _authService;
  final Ref _ref;

  AuthNotifier(this._authService, this._ref) : super(const AsyncValue.loading()) {
    _initAuthSession();
  }

  Future<void> _onAuthChanged(AuthUser? user) async {
    final storage = _ref.read(localStorageServiceProvider);
    if (user != null) {
      final userProfile = user.toUserProfile();
      UserService.updateCurrentUser(userProfile);
      _ref.read(currentUserProvider.notifier).state = userProfile;

      // Ensure storage is switched to user partition and caches reloaded
      await storage.switchUser(user.id);

      _ref.read(tripListProvider.notifier).reload();
      _ref.read(selectedTripIdProvider.notifier).state = null;
      _ref.read(allExpensesProvider.notifier).reload();
      _ref.read(allStoppagesProvider.notifier).reload();
      _ref.read(allMemoriesProvider.notifier).reload();
      _ref.read(allSettlementsProvider.notifier).reload();
      _ref.read(allAuditLogsProvider.notifier).reload();
      _ref.read(invitationProvider.notifier).refreshListeners();
      _authService.syncCurrentUserToFirestore(user);
    } else {
      // 1. Terminate all background sync listeners immediately
      try {
        _ref.read(firestoreSyncServiceProvider).disconnectAll();
      } catch (_) {}
      try {
        _ref.read(realtimeSyncServiceProvider).disconnect();
      } catch (_) {}
      try {
        CloudTripSyncService.stopGlobalSync();
      } catch (_) {}

      // 2. Switch storage to guest partition and clear memory caches
      await storage.switchUser(null);

      // 3. Reset user and in-memory Riverpod state
      _ref.read(currentUserProvider.notifier).state = UserService.getCurrentUser();
      _ref.read(tripListProvider.notifier).reset();
      _ref.read(selectedTripIdProvider.notifier).state = null;
      _ref.read(allExpensesProvider.notifier).reset();
      _ref.read(allStoppagesProvider.notifier).reset();
      _ref.read(allMemoriesProvider.notifier).reset();
      _ref.read(allSettlementsProvider.notifier).reset();
      _ref.read(allAuditLogsProvider.notifier).reset();
      _ref.read(invitationProvider.notifier).reset();
    }
  }

  Future<void> _initAuthSession() async {
    try {
      final user = _authService.currentSession;
      state = AsyncValue.data(user);
      if (user != null) {
        final userProfile = user.toUserProfile();
        UserService.updateCurrentUser(userProfile);
        _ref.read(currentUserProvider.notifier).state = userProfile;

        // Ensure storage is switched to user partition
        final storage = _ref.read(localStorageServiceProvider);
        await storage.switchUser(user.id);

        _ref.read(tripListProvider.notifier).reload();
        _ref.read(selectedTripIdProvider.notifier).state = null;
        _ref.read(allExpensesProvider.notifier).reload();
        _ref.read(allStoppagesProvider.notifier).reload();
        _ref.read(allMemoriesProvider.notifier).reload();
        _ref.read(allSettlementsProvider.notifier).reload();
        _ref.read(allAuditLogsProvider.notifier).reload();
        _ref.read(invitationProvider.notifier).refreshListeners();
        _authService.syncCurrentUserToFirestore(user);

        // Asynchronously hydrate latest phone, bio, and profile attributes from Firestore
        UserService.fetchUserProfile(user.id, forceRefresh: true).then((cloudProfile) async {
          if (cloudProfile != null && (cloudProfile.phone != null || cloudProfile.bio != null || (cloudProfile.displayName != 'Traveler' && cloudProfile.displayName.isNotEmpty))) {
            final mergedUser = user.copyWith(
              phone: cloudProfile.phone ?? user.phone,
              bio: cloudProfile.bio ?? user.bio,
              displayName: cloudProfile.displayName.isNotEmpty && cloudProfile.displayName != 'Traveler'
                  ? cloudProfile.displayName
                  : user.displayName,
            );
            await storage.saveAuthSession(mergedUser);
            final mergedProfile = mergedUser.toUserProfile();
            UserService.updateCurrentUser(mergedProfile);
            _ref.read(currentUserProvider.notifier).state = mergedProfile;
            state = AsyncValue.data(mergedUser);
          }
        }).catchError((_) {});
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
      await _onAuthChanged(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? name,
    String? username,
    String? phone,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
        username: username,
        phone: phone,
      );
      state = AsyncValue.data(user);
      await _onAuthChanged(user);
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
      await _onAuthChanged(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  bool get isEmailVerified => _authService.isEmailVerified;

  void refreshSession() {
    _initAuthSession();
  }

  Future<bool> resetPassword({required String email, required String newPassword}) async {
    return _authService.resetPassword(email: email, newPassword: newPassword);
  }

  Future<void> updateUser(AuthUser updatedUser) async {
    state = AsyncValue.data(updatedUser);
    final userProfile = updatedUser.toUserProfile();
    UserService.updateCurrentUser(userProfile);
    _ref.read(currentUserProvider.notifier).state = userProfile;

    final storage = _ref.read(localStorageServiceProvider);
    await storage.saveAuthSession(updatedUser);
    await _authService.syncCurrentUserToFirestore(updatedUser);
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      await _authService.signOut();
    } catch (_) {}
    state = const AsyncValue.data(null);
    await _onAuthChanged(null);
    try {
      appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    } catch (_) {}
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  final pushService = ref.watch(pushNotificationServiceProvider);
  return AuthService(storage, pushService);
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<AuthUser?>>((ref) {
  final service = ref.watch(authServiceProvider);
  return AuthNotifier(service, ref);
});
