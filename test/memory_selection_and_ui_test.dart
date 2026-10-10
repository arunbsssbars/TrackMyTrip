import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackmytrip/core/database/app_database.dart';
import 'package:trackmytrip/core/services/local_storage_service.dart';
import 'package:trackmytrip/core/services/push_notification_service.dart';
import 'package:trackmytrip/core/services/tombstone_service.dart';
import 'package:trackmytrip/core/services/user_service.dart';
import 'package:trackmytrip/core/theme/app_theme.dart';
import 'package:trackmytrip/models/auth_user.dart';
import 'package:trackmytrip/models/memory.dart';
import 'package:trackmytrip/models/trip.dart';
import 'package:trackmytrip/models/trip_member.dart';
import 'package:trackmytrip/models/user_profile.dart';
import 'package:trackmytrip/models/stoppage.dart';
import 'package:trackmytrip/providers/trip_provider.dart';
import 'package:trackmytrip/screens/trip_detail/tabs/memories_tab.dart';

class MockPushService extends PushNotificationService {
  @override
  Future<String?> getToken() async => 'mock';
  @override
  Future<void> init() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase appDb;
  late LocalStorageService storage;

  const base64Pixel =
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

  const testUser = UserProfile(
    id: 'user_tester_1',
    username: 'tester',
    displayName: 'Test Traveler',
    email: 'tester@trackmytrip.com',
  );

  final authUser = AuthUser(
    id: 'user_tester_1',
    username: 'tester',
    email: 'tester@trackmytrip.com',
    displayName: 'Test Traveler',
    provider: AuthProviderType.email,
    createdAt: DateTime(2026, 1, 1),
  );

  final testTrip = Trip(
    id: 'trip_ui_1',
    title: 'Goa Holiday',
    startDate: DateTime(2026, 10, 1),
    endDate: DateTime(2026, 10, 5),
    defaultCurrency: 'INR',
    members: [
      const TripMember(
        id: 'user_tester_1',
        name: 'Test Traveler',
        role: 'creator',
        isCurrentUser: true,
      ),
    ],
    createdByMemberId: 'user_tester_1',
    createdAt: DateTime(2026, 10, 1),
  );

  final testStoppage = Stoppage(
    id: 'stp_ui_1',
    tripId: 'trip_ui_1',
    name: 'Baga Beach',
    latitude: 15.55,
    longitude: 73.75,
    arrivedAt: DateTime(2026, 10, 1, 10, 0),
    category: 'beach',
    createdBy: 'user_tester_1',
  );

  final mem1 = Memory(
    id: 'mem_ui_1',
    tripId: 'trip_ui_1',
    stoppageId: 'stp_ui_1',
    uploadedByMemberId: 'user_tester_1',
    mediaPath: base64Pixel,
    caption: 'Sunset at beach',
    createdAt: DateTime(2026, 10, 1, 11, 0),
  );

  final mem2 = Memory(
    id: 'mem_ui_2',
    tripId: 'trip_ui_1',
    stoppageId: 'stp_ui_1',
    uploadedByMemberId: 'user_tester_1',
    mediaPath: base64Pixel,
    caption: 'Waves splashing',
    createdAt: DateTime(2026, 10, 1, 12, 0),
  );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    appDb = await AppDatabase.open(customPath: inMemoryDatabasePath);
    storage = await LocalStorageService.init(prefs: prefs, database: appDb);
    await TombstoneService.init(prefs, appDb);

    UserService.resetCurrentUser();
    UserService.updateCurrentUser(testUser);

    await storage.saveAuthSession(authUser);
    await storage.saveTrip(testTrip);
    await storage.saveStoppage(testStoppage);
    await storage.saveAllMemories([mem1, mem2]);
  });

  tearDown(() async {
    await appDb.close();
  });

  Widget buildTestBed(Widget child, {Size size = const Size(393, 852), double fontScale = 1.0}) {
    return ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        pushNotificationServiceProvider.overrideWithValue(MockPushService()),
        selectedTripIdProvider.overrideWith((ref) => testTrip.id),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(fontScale),
            padding: const EdgeInsets.only(top: 24, bottom: 16),
            viewInsets: EdgeInsets.zero,
          ),
          child: Scaffold(
            body: child,
          ),
        ),
      ),
    );
  }

  group('Loop 2: MemoriesTab Multi-Selection & AQIL Multi-Viewport UI Tests', () {
    testWidgets('MemoriesTab toggles multi-selection mode and displays selection action bar', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(buildTestBed(MemoriesTab(trip: testTrip)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Find the selection mode toggle button by icon
      final selectButton = find.byIcon(Icons.checklist_rounded);
      expect(selectButton, findsOneWidget);

      // Tap select button to enter selection mode
      await tester.tap(selectButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify selection action banner appeared
      expect(find.textContaining('selected'), findsWidgets);
      final selectAllFinder = find.text('All').evaluate().isNotEmpty ? find.text('All') : find.text('Select All');
      expect(selectAllFinder, findsOneWidget);

      // Tap "All" / "Select All"
      await tester.tap(selectAllFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify "Delete (2)" is now rendered on the button
      expect(find.text('Delete (2)'), findsOneWidget);
      expect(find.text('Deselect'), findsOneWidget);

      // Tap Cancel / Exit Selection
      final exitBtn = find.byTooltip('Cancel Selection');
      expect(exitBtn, findsOneWidget);
      await tester.tap(exitBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify selection banner disappeared
      expect(find.byTooltip('Cancel Selection'), findsNothing);

      // Flush any lingering tooltip timers
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('AQIL Multi-Viewport Verification: zero layout overflow across viewports in selection mode', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const viewports = [
        Size(320, 600),  // Compact Mobile
        Size(393, 852),  // Standard Mobile
        Size(800, 1024), // Tablet Portrait
        Size(1280, 800), // Desktop / Landscape
      ];

      for (final vp in viewports) {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(buildTestBed(MemoriesTab(trip: testTrip), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Enter selection mode
        final selectBtn = find.byIcon(Icons.checklist_rounded);
        expect(selectBtn, findsOneWidget);
        await tester.tap(selectBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify zero RenderFlex overflow
        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Cancel Selection'), findsOneWidget);

        // Exit selection mode for next iteration
        await tester.tap(find.byTooltip('Cancel Selection'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Flush any lingering timers
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
