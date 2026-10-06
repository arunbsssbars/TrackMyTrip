import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackmytrip/core/database/app_database.dart';
import 'package:trackmytrip/core/services/local_storage_service.dart';
import 'package:trackmytrip/core/services/push_notification_service.dart';
import 'package:trackmytrip/models/auth_user.dart';
import 'package:trackmytrip/models/trip.dart';
import 'package:trackmytrip/models/trip_member.dart';
import 'package:trackmytrip/providers/trip_provider.dart';
import 'package:trackmytrip/screens/home/create_trip_sheet.dart';
import 'package:trackmytrip/screens/home/join_trip_sheet.dart';
import 'package:trackmytrip/screens/home/qr_scanner_screen.dart';
import 'package:trackmytrip/screens/trip_detail/edit_trip_dialog.dart';
import 'package:trackmytrip/screens/auth/login_screen.dart';
import 'package:trackmytrip/screens/auth/signup_screen.dart';

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

  late LocalStorageService storage;

  final testUser = AuthUser(
    id: 'user_master_test_1',
    email: 'alex@trackmytrip.app',
    displayName: 'Alex Explorer',
    username: 'alex_explorer',
    provider: AuthProviderType.email,
    createdAt: DateTime(2026, 1, 1),
  );

  final mockTrip = Trip(
    id: 'test_trip_1',
    title: 'Manali Expedition',
    startDate: DateTime.now(),
    endDate: DateTime.now().add(const Duration(days: 3)),
    defaultCurrency: 'INR',
    createdByMemberId: 'm1',
    members: const [
      TripMember(id: 'm1', name: 'Arun', isCurrentUser: true),
    ],
    createdAt: DateTime.now(),
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final appDb = await AppDatabase.open(customPath: inMemoryDatabasePath);
    storage = await LocalStorageService.init(prefs: prefs, database: appDb);
    await storage.saveAuthSession(testUser);
    await storage.saveTrip(mockTrip);
  });

  Widget buildTestBed(Widget child, {Size size = const Size(393, 852)}) {
    return ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        pushNotificationServiceProvider.overrideWithValue(MockPushNotificationService()),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: const EdgeInsets.only(top: 44, bottom: 34),
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: child),
        ),
      ),
    );
  }

  group('Loops 131–150: UI Best Practices & AQIL Touch-Target Verification', () {
    testWidgets('CreateTripSheet renders cleanly with accessible close touch target', (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      await tester.pumpWidget(buildTestBed(const CreateTripSheet()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Plan a New Trip'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      final closeButton = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close));
      expect(closeButton.constraints?.minWidth, greaterThanOrEqualTo(44.0));
      expect(closeButton.constraints?.minHeight, greaterThanOrEqualTo(44.0));
    });

    testWidgets('JoinTripSheet renders with accessible close button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      await tester.pumpWidget(buildTestBed(const JoinTripSheet()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 12));

      expect(find.text("Join Friends' & Family Journey"), findsOneWidget);
      final closeButton = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close_rounded));
      expect(closeButton.constraints?.minWidth, greaterThanOrEqualTo(44.0));
      expect(closeButton.constraints?.minHeight, greaterThanOrEqualTo(44.0));
    });

    testWidgets('QrScannerScreen action buttons have accessible touch targets', (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      await tester.pumpWidget(buildTestBed(const QrScannerScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final switchCamBtn = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.cameraswitch_rounded));
      expect(switchCamBtn.constraints?.minWidth, greaterThanOrEqualTo(48.0));
      expect(switchCamBtn.constraints?.minHeight, greaterThanOrEqualTo(48.0));
    });

    testWidgets('EditTripDialog close button has accessible touch targets', (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      await tester.pumpWidget(buildTestBed(EditTripDialog(trip: mockTrip)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Edit Trip Details'), findsOneWidget);
      final closeButton = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close));
      expect(closeButton.constraints?.minWidth, greaterThanOrEqualTo(44.0));
      expect(closeButton.constraints?.minHeight, greaterThanOrEqualTo(44.0));
    });

    testWidgets('LoginScreen password visibility toggle has accessible target', (tester) async {
      await tester.runAsync(() async => await storage.clearAuthSession());
      await tester.binding.setSurfaceSize(const Size(393, 852));
      await tester.pumpWidget(buildTestBed(const LoginScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LoginScreen), findsOneWidget);
      final toggleBtn = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.visibility_off));
      expect(toggleBtn.constraints?.minWidth, greaterThanOrEqualTo(44.0));
      expect(toggleBtn.constraints?.minHeight, greaterThanOrEqualTo(44.0));
    });

    testWidgets('SignUpScreen password visibility toggle has accessible targets', (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      await tester.pumpWidget(buildTestBed(const SignUpScreen()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 12));

      expect(find.byType(SignUpScreen), findsOneWidget);
      final toggleBtns = tester.widgetList<IconButton>(find.widgetWithIcon(IconButton, Icons.visibility_off)).toList();
      expect(toggleBtns.length, greaterThanOrEqualTo(2));
      for (final btn in toggleBtns) {
        expect(btn.constraints?.minWidth, greaterThanOrEqualTo(44.0));
        expect(btn.constraints?.minHeight, greaterThanOrEqualTo(44.0));
      }
    });
  });
}

