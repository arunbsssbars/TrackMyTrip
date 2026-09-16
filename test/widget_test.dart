import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trip_tracker_app/core/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_tracker_app/core/services/local_storage_service.dart';
import 'package:trip_tracker_app/main.dart';
import 'package:trip_tracker_app/models/auth_user.dart';
import 'package:trip_tracker_app/providers/trip_provider.dart';

void main() {
  testWidgets('Trip Tracker launches LoginScreen when unauthenticated', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final storage = await LocalStorageService.init(prefs: prefs, database: await AppDatabase.open(customPath: inMemoryDatabasePath));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
        ],
        child: const TripStopsApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Trip Tracker'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Continue with Google (Gmail)'), findsOneWidget);
  });

  testWidgets('Trip Tracker launches HomeScreen when authenticated', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final storage = await LocalStorageService.init(prefs: prefs, database: await AppDatabase.open(customPath: inMemoryDatabasePath));

    await storage.saveAuthSession(
      AuthUser(
        id: 'usr_me_001',
        username: 'arun_explorer',
        displayName: 'Arun V (Trip Lead)',
        email: 'arun@example.com',
        provider: AuthProviderType.email,
        createdAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
        ],
        child: const TripStopsApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Trip Tracker'), findsOneWidget);
    expect(find.text('New Trip'), findsOneWidget);
  });
}
