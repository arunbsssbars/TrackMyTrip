import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:trackmytrip/core/database/app_database.dart';
import 'package:trackmytrip/core/services/local_storage_service.dart';
import 'package:trackmytrip/core/services/push_notification_service.dart';
import 'package:trackmytrip/models/auth_user.dart';
import 'package:trackmytrip/models/expense.dart';
import 'package:trackmytrip/models/expense_split.dart';
import 'package:trackmytrip/models/trip.dart';
import 'package:trackmytrip/models/trip_member.dart';
import 'package:trackmytrip/models/stoppage.dart';
import 'package:trackmytrip/models/memory.dart';
import 'package:trackmytrip/models/settlement.dart';
import 'package:trackmytrip/models/trip_audit_log.dart';
import 'package:trackmytrip/providers/trip_provider.dart';

// Screens & Tabs under AQIL Loops 151-160
import 'package:trackmytrip/screens/home/home_screen.dart';
import 'package:trackmytrip/screens/trip/current_trip_tab.dart';
import 'package:trackmytrip/screens/trip_detail/trip_detail_screen.dart';
import 'package:trackmytrip/screens/trip_detail/tabs/timeline_tab.dart';
import 'package:trackmytrip/screens/trip_detail/tabs/expenses_tab.dart';
import 'package:trackmytrip/screens/expenses/add_expense_screen.dart';
import 'package:trackmytrip/screens/trip_detail/tabs/settlement_tab.dart';
import 'package:trackmytrip/screens/trip_detail/tabs/members_tab.dart';
import 'package:trackmytrip/screens/trip_detail/tabs/memories_tab.dart';
import 'package:trackmytrip/screens/activity/activity_hub_tab.dart';
import 'package:trackmytrip/screens/notifications/notification_center_sheet.dart';
import 'package:trackmytrip/screens/trip_detail/audit_log_sheet.dart';

import 'support/ui_glitch_inspector.dart';

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
    id: 'user_aqil_1',
    email: 'alex@trackmytrip.app',
    displayName: 'Alex Explorer',
    username: 'alex_explorer',
    provider: AuthProviderType.email,
    createdAt: DateTime(2026, 1, 1),
  );

  final testTrip = Trip(
    id: 'trip_aqil_101',
    title: 'Himalayan Ridge Expedition 2026',
    description: 'Autonomous exploration from Manali to Leh across high-altitude mountain passes.',
    startDate: DateTime.now().subtract(const Duration(days: 2)),
    endDate: DateTime.now().add(const Duration(days: 5)),
    defaultCurrency: 'USD',
    budget: 5000.0,
    shareCode: 'HIMA-2026',
    tripType: 'group',
    createdByMemberId: 'user_aqil_1',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    members: const [
      TripMember(
        id: 'user_aqil_1',
        name: 'Alex Explorer',
        email: 'alex@trackmytrip.app',
        isCurrentUser: true,
        colorHex: '0xFF0D9488',
        role: 'creator',
      ),
      TripMember(
        id: 'user_aqil_2',
        name: 'Priya Sharma',
        email: 'priya@trackmytrip.app',
        phoneNumber: '+15550192834',
        isCurrentUser: false,
        colorHex: '0xFF3B82F6',
        role: 'editor',
      ),
      TripMember(
        id: 'user_aqil_3',
        name: 'Carlos Mendez',
        email: 'carlos@trackmytrip.app',
        isCurrentUser: false,
        colorHex: '0xFFF59E0B',
        role: 'viewer',
      ),
    ],
  );

  final testExpense = Expense(
    id: 'exp_aqil_1',
    tripId: 'trip_aqil_101',
    title: 'High Altitude Basecamp Fuel & Supplies',
    totalAmount: 145.50,
    currency: 'USD',
    category: 'Fuel',
    paidByMemberId: 'user_aqil_1',
    splitType: SplitType.equal,
    splits: const [
      ExpenseSplit(memberId: 'user_aqil_1', allocatedAmount: 48.50),
      ExpenseSplit(memberId: 'user_aqil_2', allocatedAmount: 48.50),
      ExpenseSplit(memberId: 'user_aqil_3', allocatedAmount: 48.50),
    ],
    createdAt: DateTime.now(),
    isPersonal: false,
  );

  final testStoppage = Stoppage(
    id: 'stop_aqil_1',
    tripId: 'trip_aqil_101',
    name: 'Rohtang Pass Crest',
    latitude: 32.3716,
    longitude: 77.2466,
    category: 'Scenic Viewpoint',
    arrivedAt: DateTime.now().subtract(const Duration(hours: 3)),
    createdBy: 'user_aqil_1',
    notes: 'Panoramic mountain vista at 3980m elevation.',
  );

  final testMemory = Memory(
    id: 'mem_aqil_1',
    tripId: 'trip_aqil_101',
    stoppageId: 'stop_aqil_1',
    uploadedByMemberId: 'user_aqil_1',
    mediaPath: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    caption: 'Glacial peak panorama at sunrise',
    createdAt: DateTime.now(),
  );

  final testSettlement = Settlement(
    id: 'settle_aqil_1',
    tripId: 'trip_aqil_101',
    payerMemberId: 'user_aqil_2',
    receiverMemberId: 'user_aqil_1',
    amount: 48.50,
    currency: 'USD',
    settledAt: DateTime.now(),
    paymentMethod: 'Cash',
    notes: 'Basecamp fuel reimbursement',
  );

  final testAuditLog = TripAuditLog(
    id: 'audit_aqil_1',
    tripId: 'trip_aqil_101',
    actionType: 'create_expense',
    itemTitle: 'High Altitude Basecamp Fuel',
    performedByMemberId: 'user_aqil_1',
    performedByName: 'Alex Explorer',
    timestamp: DateTime.now(),
    amount: 145.50,
    currency: 'USD',
  );

  setUpAll(() async {
    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details, forceReport: true);
    };
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final appDb = await AppDatabase.open(customPath: inMemoryDatabasePath);
    storage = await LocalStorageService.init(prefs: prefs, database: appDb);
    await storage.saveAuthSession(testUser);
    await storage.saveTrip(testTrip);
    await storage.saveExpense(testExpense);
    await storage.saveStoppage(testStoppage);
    await storage.saveMemory(testMemory);
    await storage.saveSettlement(testSettlement);
    await storage.saveAuditLog(testAuditLog);
  });

  Widget buildTestBed(
    Widget child, {
    Size size = const Size(393, 852),
    double fontScale = 1.0,
    bool isDark = false,
  }) {
    return ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        pushNotificationServiceProvider.overrideWithValue(MockPushNotificationService()),
        selectedTripIdProvider.overrideWith((ref) => testTrip.id),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, brightness: isDark ? Brightness.dark : Brightness.light),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(fontScale),
            padding: const EdgeInsets.only(top: 44, bottom: 34),
          ),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: child,
          ),
        ),
      ),
    );
  }

  group('AQIL Loops 151-160 Multi-Viewport Master Verification', () {
    final viewports = [
      DevicePreset.compact.logicalSize,   // 320x568 Compact
      DevicePreset.standard.logicalSize,  // 390x844 Standard
      DevicePreset.tallAndroid.logicalSize, // 412x915 Tall Android
      DevicePreset.tablet.logicalSize,    // 768x1024 Tablet
      const Size(1280, 800),              // 1280x800 Landscape Desktop
    ];

    testWidgets('Loop 151: HomeScreen renders with zero overflow across viewports', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final vp in viewports) {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(buildTestBed(const HomeScreen(), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('Loop 152: CurrentTripTab renders with zero overflow across viewports', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final vp in viewports) {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(buildTestBed(const CurrentTripTab(), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('Loop 153: TripDetailScreen & TimelineTab render with zero overflow across viewports', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final vp in viewports) {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(buildTestBed(TripDetailScreen(tripId: testTrip.id), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('Loop 154: TimelineTab isolated view renders resiliently across viewports', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final vp in viewports) {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(buildTestBed(TimelineTab(trip: testTrip), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('Loop 155: ExpensesTab & AddExpenseScreen render with zero overflow across viewports', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final vp in viewports) {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(buildTestBed(ExpensesTab(trip: testTrip), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(AddExpenseScreen(tripId: testTrip.id), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('Loop 156: SettlementTab renders with zero overflow across viewports', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final vp in viewports) {
        debugPrint('TESTING_VP: ${vp.width}x${vp.height}');
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(buildTestBed(SettlementTab(trip: testTrip), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('Loop 157: MembersTab renders with zero overflow across viewports', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final vp in viewports) {
        debugPrint('TESTING_MEMBERS_VP: ${vp.width}x${vp.height}');
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(buildTestBed(MembersTab(trip: testTrip), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('Loop 158: MemoriesTab renders with zero overflow across viewports', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final vp in viewports) {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(buildTestBed(MemoriesTab(trip: testTrip), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('Loop 159: ActivityHubTab, NotificationCenterSheet & AuditLogSheet render with zero overflow across viewports', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final vp in viewports) {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(buildTestBed(const ActivityHubTab(), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(const NotificationCenterSheet(), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(AuditLogSheet(trip: testTrip), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('Loop 160: Master AQIL Accessibility Font Scaling 1.5x on Mobile', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      const mobileViewport = Size(393, 852);
      tester.view.physicalSize = mobileViewport;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(buildTestBed(const HomeScreen(), size: mobileViewport, fontScale: 1.5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      UiGlitchInspector.assertNoOverflows(tester);

      await tester.pumpWidget(buildTestBed(const CurrentTripTab(), size: mobileViewport, fontScale: 1.5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      UiGlitchInspector.assertNoOverflows(tester);

      await tester.pumpWidget(buildTestBed(TripDetailScreen(tripId: testTrip.id), size: mobileViewport, fontScale: 1.5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      UiGlitchInspector.assertNoOverflows(tester);

      await tester.pumpWidget(buildTestBed(SettlementTab(trip: testTrip), size: mobileViewport, fontScale: 1.5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      UiGlitchInspector.assertNoOverflows(tester);

      await tester.pumpWidget(buildTestBed(const ActivityHubTab(), size: mobileViewport, fontScale: 1.5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      UiGlitchInspector.assertNoOverflows(tester);

      await tester.pump(const Duration(seconds: 12));
    });
  });
}
