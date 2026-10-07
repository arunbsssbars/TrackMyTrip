import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackmytrip/core/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackmytrip/core/services/local_storage_service.dart';
import 'package:trackmytrip/core/services/push_notification_service.dart';
import 'package:trackmytrip/main.dart';
import 'package:trackmytrip/models/auth_user.dart';
import 'package:trackmytrip/providers/trip_provider.dart';

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

  testWidgets('TrackMyTrip launches LoginScreen when unauthenticated', (WidgetTester tester) async {
    late LocalStorageService storage;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final appDb = await AppDatabase.open(customPath: inMemoryDatabasePath);
      storage = await LocalStorageService.init(prefs: prefs, database: appDb);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          pushNotificationServiceProvider.overrideWithValue(MockPushNotificationService()),
        ],
        child: const TripStopsApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('TrackMyTrip'), findsWidgets);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Continue with Google (Gmail)'), findsOneWidget);
  });

  testWidgets('TrackMyTrip launches HomeScreen when authenticated', (WidgetTester tester) async {
    late LocalStorageService storage;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final appDb = await AppDatabase.open(customPath: inMemoryDatabasePath);
      storage = await LocalStorageService.init(prefs: prefs, database: appDb);

      await storage.saveAuthSession(
        AuthUser(
          id: 'usr_me_001',
          username: 'arun_explorer',
          displayName: 'Arun V (Trip Lead)',
          email: 'arun@example.com',
          provider: AuthProviderType.google,
          createdAt: DateTime.now(),
        ),
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          pushNotificationServiceProvider.overrideWithValue(MockPushNotificationService()),
        ],
        child: const TripStopsApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('TrackMyTrip'), findsWidgets);
    expect(find.text('New Trip'), findsOneWidget);
  });
}
