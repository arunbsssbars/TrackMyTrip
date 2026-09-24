import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_tracker_app/core/database/app_database.dart';
import 'package:trip_tracker_app/core/services/auth_service.dart';
import 'package:trip_tracker_app/core/services/local_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trip_tracker_app/core/services/push_notification_service.dart';
import 'package:trip_tracker_app/models/auth_user.dart';
import 'package:trip_tracker_app/models/trip.dart';
import 'package:trip_tracker_app/models/trip_member.dart';
import 'package:trip_tracker_app/models/expense.dart';
import 'package:trip_tracker_app/models/expense_split.dart';
import 'package:trip_tracker_app/providers/auth_provider.dart';
import 'package:trip_tracker_app/providers/trip_provider.dart';
import 'package:trip_tracker_app/providers/expense_provider.dart';

class MockPushNotificationService extends PushNotificationService {
  @override
  Future<String?> getToken() async => 'mock_token';
  
  @override
  Future<void> init() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('AuthUser Model Tests', () {
    test('AuthUser serializes and deserializes correctly', () {
      final user = AuthUser(
        id: 'usr_100',
        username: 'traveler_sam',
        displayName: 'Sam Wilson',
        email: 'sam@example.com',
        provider: AuthProviderType.google,
        createdAt: DateTime(2026, 9, 4, 12, 0),
        token: 'test_token',
      );

      expect(user.handle, equals('@traveler_sam'));

      final json = user.toJson();
      expect(json['username'], equals('traveler_sam'));
      expect(json['provider'], equals('google'));

      final revived = AuthUser.fromJson(json);
      expect(revived.id, equals('usr_100'));
      expect(revived.displayName, equals('Sam Wilson'));
      expect(revived.provider, equals(AuthProviderType.google));
    });
  });

  group('AuthService Sign Up & Login Tests', () {
    late LocalStorageService storage;
    late AuthService authService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = await LocalStorageService.init(prefs: prefs, database: await AppDatabase.open(customPath: inMemoryDatabasePath));
      final mockPushService = MockPushNotificationService();
      authService = AuthService(storage, mockPushService);
    });

    test('Sign up with valid email & password registers user and saves session', () async {
      expect(authService.isAuthenticated, isFalse);

      final user = await authService.signUpWithEmail(
        name: 'Arun Kumar',
        username: 'arun_k',
        email: 'arun.k@example.com',
        password: 'securePassword123',
      );

      expect(user.displayName, equals('Arun Kumar'));
      expect(user.username, equals('arun_k'));
      expect(user.email, equals('arun.k@example.com'));
      expect(authService.isAuthenticated, isTrue);
      expect(authService.currentSession?.email, equals('arun.k@example.com'));
    });

    test('Minimal sign up with email and password only derives friendly display name and handle', () async {
      final user = await authService.signUpWithEmail(
        email: 'priya.sharma@example.com',
        password: 'safePassword789',
      );

      expect(user.displayName, equals('Priya Sharma'));
      expect(user.username, startsWith('priya_sharma'));
      expect(user.email, equals('priya.sharma@example.com'));
      expect(authService.isAuthenticated, isTrue);
    });

    test('Sign up rejects invalid email or short password', () async {
      // Invalid email
      expect(
        () => authService.signUpWithEmail(
          name: 'Test',
          username: 'testuser',
          email: 'invalid-email',
          password: '123456Password',
        ),
        throwsException,
      );

      // Short password (< 6 chars)
      expect(
        () => authService.signUpWithEmail(
          name: 'Test',
          username: 'testuser',
          email: 'test@example.com',
          password: '123',
        ),
        throwsException,
      );
    });

    test('Sign up rejects duplicate email and duplicate username', () async {
      await authService.signUpWithEmail(
        name: 'User One',
        username: 'unique_handle',
        email: 'user1@example.com',
        password: 'password123',
      );

      // Duplicate email
      expect(
        () => authService.signUpWithEmail(
          name: 'User Two',
          username: 'different_handle',
          email: 'user1@example.com',
          password: 'password123',
        ),
        throwsException,
      );

      // Duplicate username
      expect(
        () => authService.signUpWithEmail(
          name: 'User Three',
          username: 'unique_handle',
          email: 'user3@example.com',
          password: 'password123',
        ),
        throwsException,
      );
    });

    test('Sign in with correct credentials succeeds and restores session', () async {
      await authService.signUpWithEmail(
        name: 'Elena Rostova',
        username: 'elena_r',
        email: 'elena@travel.org',
        password: 'secretPassword',
      );

      // Sign out
      await authService.signOut();
      expect(authService.isAuthenticated, isFalse);

      // Sign in by email
      final loggedInByEmail = await authService.signInWithEmail(
        emailOrUsername: 'elena@travel.org',
        password: 'secretPassword',
      );
      expect(loggedInByEmail.username, equals('elena_r'));
      expect(authService.isAuthenticated, isTrue);

      await authService.signOut();

      // Sign in by @username
      final loggedInByUsername = await authService.signInWithEmail(
        emailOrUsername: '@elena_r',
        password: 'secretPassword',
      );
      expect(loggedInByUsername.email, equals('elena@travel.org'));
      expect(authService.isAuthenticated, isTrue);
    });

    test('Sign in with wrong password fails with descriptive exception', () async {
      await authService.signUpWithEmail(
        name: 'Mike',
        username: 'mike_t',
        email: 'mike@example.com',
        password: 'correctPassword',
      );

      await authService.signOut();

      expect(
        () => authService.signInWithEmail(
          emailOrUsername: 'mike@example.com',
          password: 'wrongPassword',
        ),
        throwsException,
      );
    });
  });

  group('AuthService Google & Password Reset Tests', () {
    late LocalStorageService storage;
    late AuthService authService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = await LocalStorageService.init(prefs: prefs, database: await AppDatabase.open(customPath: inMemoryDatabasePath));
      
      final mockPushService = MockPushNotificationService();
      authService = AuthService(storage, mockPushService);
    });

    test('Sign in with Google creates Google account session', () async {
      final googleUser = await authService.signInWithGoogle(
        googleEmail: 'traveler.alex@gmail.com',
        googleName: 'Alex Traveler',
      );

      expect(googleUser.provider, equals(AuthProviderType.google));
      expect(googleUser.email, equals('traveler.alex@gmail.com'));
      expect(authService.isAuthenticated, isTrue);
    });

    test('Password reset updates password and allows login with new password', () async {
      await authService.signUpWithEmail(
        name: 'Sarah',
        username: 'sarah_j',
        email: 'sarah@example.com',
        password: 'oldPassword123',
      );

      await authService.signOut();

      // Reset password
      final resetSuccess = await authService.resetPassword(
        email: 'sarah@example.com',
        newPassword: 'brandNewPassword999',
      );
      expect(resetSuccess, isTrue);

      // Old password should now fail
      expect(
        () => authService.signInWithEmail(
          emailOrUsername: 'sarah@example.com',
          password: 'oldPassword123',
        ),
        throwsException,
      );

      // New password succeeds
      final user = await authService.signInWithEmail(
        emailOrUsername: 'sarah@example.com',
        password: 'brandNewPassword999',
      );
      expect(user.username, equals('sarah_j'));
      expect(authService.isAuthenticated, isTrue);
    });
  });

  group('Multi-User Privacy & Data Isolation Tests', () {
    late LocalStorageService storage;
    late AuthService authService;
    late ProviderContainer container;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = await LocalStorageService.init(
        prefs: prefs,
        database: await AppDatabase.open(customPath: inMemoryDatabasePath),
      );
      final mockPushService = MockPushNotificationService();
      authService = AuthService(storage, mockPushService);

      container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          authServiceProvider.overrideWithValue(authService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('User B logging in on same device cannot see User A unshared trip or expenses', () async {
      // 1. User A ("Arun") signs up and logs in
      await container.read(authNotifierProvider.notifier).signUp(
        email: 'arun@example.com',
        password: 'password123',
        name: 'Arun',
        username: 'arun_lead',
      );
      final userA = container.read(authNotifierProvider).valueOrNull!;

      // 2. Arun creates Trip A with an expense of 250 Rs
      final tripA = Trip(
        id: 'trip_arun_101',
        title: 'Arun Solo Expedition',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 3)),
        createdByMemberId: userA.id,
        createdAt: DateTime.now(),
        members: [
          TripMember(
            id: userA.id,
            name: userA.displayName,
            email: userA.email,
            isCurrentUser: true,
            colorHex: '0xFF0D9488',
          ),
        ],
        defaultCurrency: 'INR',
      );
      await container.read(tripListProvider.notifier).addTrip(tripA);

      final expenseA = Expense(
        id: 'exp_arun_250',
        tripId: tripA.id,
        title: 'Fuel Refill',
        totalAmount: 250.0,
        currency: 'INR',
        category: 'Transport',
        paidByMemberId: userA.id,
        splitType: SplitType.equal,
        splits: [
          ExpenseSplit(memberId: userA.id, allocatedAmount: 250.0),
        ],
        createdAt: DateTime.now(),
      );
      await container.read(allExpensesProvider.notifier).addExpense(expenseA);

      // Verify Arun sees Trip A and 250 Rs
      expect(container.read(tripListProvider).length, equals(1));
      expect(container.read(userScopedTotalSpentProvider), equals(250.0));

      // 3. Arun logs out
      await container.read(authNotifierProvider.notifier).logout();
      expect(container.read(tripListProvider), isEmpty);
      expect(container.read(userScopedTotalSpentProvider), equals(0.0));

      // 4. User B ("EMTD") signs up and logs in on the SAME device
      await container.read(authNotifierProvider.notifier).signUp(
        email: 'emtd@example.com',
        password: 'password456',
        name: 'EMTD',
        username: 'emtd_user',
      );

      // 5. Verify EMTD sees ZERO trips and ZERO expenses (Strict isolation!)
      expect(container.read(tripListProvider), isEmpty);
      expect(container.read(userScopedTotalSpentProvider), equals(0.0));
      expect(container.read(userScopedExpensesProvider), isEmpty);
    });
  });
}
