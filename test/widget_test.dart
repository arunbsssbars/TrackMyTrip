import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trip_tracker_app/core/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_tracker_app/core/services/local_storage_service.dart';
import 'package:trip_tracker_app/core/services/push_notification_service.dart';
import 'package:trip_tracker_app/main.dart';
import 'package:trip_tracker_app/models/auth_user.dart';
import 'package:trip_tracker_app/providers/trip_provider.dart';

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

  testWidgets('Trip Tracker launches LoginScreen when unauthenticated', (WidgetTester tester) async {
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

    expect(find.text('Trip Tracker'), findsWidgets);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Continue with Google (Gmail)'), findsOneWidget);
  });

  testWidgets('Trip Tracker launches HomeScreen when authenticated', (WidgetTester tester) async {
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

    expect(find.text('Trip Tracker'), findsWidgets);
    expect(find.text('New Trip'), findsOneWidget);
  });
}
