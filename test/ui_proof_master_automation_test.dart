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
import 'package:trackmytrip/providers/trip_provider.dart';

// Screens & Tabs
import 'package:trackmytrip/screens/auth/email_verification_screen.dart';
import 'package:trackmytrip/screens/auth/forgot_password_sheet.dart';
import 'package:trackmytrip/screens/auth/login_screen.dart';
import 'package:trackmytrip/screens/auth/signup_screen.dart';
import 'package:trackmytrip/screens/home/create_trip_sheet.dart';
import 'package:trackmytrip/screens/home/home_screen.dart';
import 'package:trackmytrip/screens/home/join_trip_sheet.dart';
import 'package:trackmytrip/screens/home/qr_scanner_screen.dart';
import 'package:trackmytrip/screens/trip/companion_search_dialog.dart';
import 'package:trackmytrip/screens/trip/current_trip_tab.dart';
import 'package:trackmytrip/screens/trip_detail/tabs/expenses_tab.dart';
import 'package:trackmytrip/screens/trip_detail/tabs/members_tab.dart';
import 'package:trackmytrip/screens/trip_detail/tabs/memories_tab.dart';
import 'package:trackmytrip/screens/trip_detail/tabs/settlement_tab.dart';
import 'package:trackmytrip/screens/trip_detail/tabs/timeline_tab.dart';
import 'package:trackmytrip/screens/trip_detail/audit_log_sheet.dart';
import 'package:trackmytrip/screens/trip_detail/edit_trip_dialog.dart';
import 'package:trackmytrip/screens/trip_detail/share_trip_sheet.dart';
import 'package:trackmytrip/screens/expenses/add_expense_screen.dart';
import 'package:trackmytrip/screens/expenses/global_expenses_sheet.dart';
import 'package:trackmytrip/screens/notifications/notification_center_sheet.dart';
import 'package:trackmytrip/screens/profile/profile_tab.dart';
import 'package:trackmytrip/screens/activity/activity_hub_tab.dart';
import 'package:trackmytrip/screens/stats/trip_analytics_screen.dart';
import 'package:trackmytrip/screens/stoppage/stoppage_detail_screen.dart';
import 'package:trackmytrip/screens/memories/add_memory_dialog.dart';
import 'package:trackmytrip/widgets/current_trip_hero_card.dart';

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
    id: 'user_master_test_1',
    email: 'alex@trackmytrip.app',
    displayName: 'Alex Explorer',
    username: 'alex_explorer',
    provider: AuthProviderType.email,
    createdAt: DateTime(2026, 1, 1),
  );

  final testTrip = Trip(
    id: 'trip_master_test_101',
    title: 'Himalayan Ridge Expedition 2026',
    description: 'Autonomous exploration from Manali to Leh via high altitude mountain passes.',
    startDate: DateTime.now().subtract(const Duration(days: 2)),
    endDate: DateTime.now().add(const Duration(days: 5)),
    defaultCurrency: 'USD',
    budget: 4500.0,
    shareCode: 'TRIP-7788',
    tripType: 'group',
    createdByMemberId: 'user_master_test_1',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    members: const [
      TripMember(
        id: 'user_master_test_1',
        name: 'Alex Explorer',
        email: 'alex@trackmytrip.app',
        isCurrentUser: true,
        colorHex: '0xFF0D9488',
      ),
      TripMember(
        id: 'user_master_test_2',
        name: 'Priya Sharma',
        email: 'priya@trackmytrip.app',
        phoneNumber: '+15550192834',
        isCurrentUser: false,
        colorHex: '0xFF3B82F6',
      ),
    ],
  );

  final testExpense = Expense(
    id: 'exp_master_test_1',
    tripId: 'trip_master_test_101',
    title: 'High Altitude Fuel & Supplies',
    totalAmount: 145.50,
    currency: 'USD',
    category: 'Fuel',
    paidByMemberId: 'user_master_test_1',
    splitType: SplitType.equal,
    splits: const [
      ExpenseSplit(memberId: 'user_master_test_1', allocatedAmount: 72.75),
      ExpenseSplit(memberId: 'user_master_test_2', allocatedAmount: 72.75),
    ],
    createdAt: DateTime.now(),
    isPersonal: false,
  );

  final testStoppage = Stoppage(
    id: 'stop_master_test_1',
    tripId: 'trip_master_test_101',
    name: 'Rohtang High Pass Summit',
    latitude: 32.3716,
    longitude: 77.2466,
    category: 'Scenic Checkpoint',
    arrivedAt: DateTime.now().subtract(const Duration(hours: 3)),
    createdBy: 'user_master_test_1',
    notes: 'Scenic checkpoint with panoramic glacier view.',
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
  });

  void applyDeviceSurface(WidgetTester tester, dynamic deviceOrSize) {
    if (deviceOrSize is DevicePreset) {
      tester.view.physicalSize = Size(
        deviceOrSize.logicalSize.width * deviceOrSize.pixelRatio,
        deviceOrSize.logicalSize.height * deviceOrSize.pixelRatio,
      );
      tester.view.devicePixelRatio = deviceOrSize.pixelRatio;
    } else if (deviceOrSize is Size) {
      tester.view.physicalSize = deviceOrSize;
      tester.view.devicePixelRatio = 1.0;
    }
  }

  Widget buildTestBed(
    Widget child, {
    DevicePreset device = DevicePreset.standard,
    double fontScale = 1.0,
    bool isDark = false,
  }) {
    return ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        pushNotificationServiceProvider.overrideWithValue(MockPushNotificationService()),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: device.logicalSize,
          devicePixelRatio: device.pixelRatio,
          textScaler: TextScaler.linear(fontScale),
          padding: const EdgeInsets.only(top: 44, bottom: 34),
          viewInsets: EdgeInsets.zero,
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: isDark
              ? ThemeData.dark(useMaterial3: true).copyWith(
                  scaffoldBackgroundColor: const Color(0xFF0F172A),
                )
              : ThemeData.light(useMaterial3: true).copyWith(
                  scaffoldBackgroundColor: const Color(0xFFF8FAFC),
                ),
          home: child is Scaffold ? child : Scaffold(body: child),
        ),
      ),
    );
  }

  group('Master UI Proof Suite: Multi-Device & Stress Testing', () {
    testWidgets('1. Auth Suite: LoginScreen & SignUpScreen pass all viewports & font scales', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.runAsync(() async => await storage.clearAuthSession());
      for (final device in [DevicePreset.compact, DevicePreset.standard, DevicePreset.tablet]) {
        applyDeviceSurface(tester, device.logicalSize);

        // Test Login Screen
        await tester.pumpWidget(buildTestBed(const LoginScreen(), device: device));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);
        UiGlitchInspector.assertNoUnintendedTruncation(tester);

        // Test SignUp Screen
        await tester.pumpWidget(buildTestBed(const SignUpScreen(), device: device));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);
        UiGlitchInspector.assertNoUnintendedTruncation(tester);
      }

      // Extreme Accessibility Font Scale 1.75x
      applyDeviceSurface(tester, DevicePreset.compact.logicalSize);
      await tester.pumpWidget(buildTestBed(const LoginScreen(), device: DevicePreset.compact, fontScale: 1.75));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      UiGlitchInspector.assertNoOverflows(tester);
    });

    testWidgets('2. Auth Modals: ForgotPasswordSheet & EmailVerificationScreen', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.runAsync(() async => await storage.clearAuthSession());
      applyDeviceSurface(tester, DevicePreset.compact.logicalSize);
      FlutterError.onError = (details) {
        FlutterError.dumpErrorToConsole(details, forceReport: true);
      };

      await tester.pumpWidget(buildTestBed(const ForgotPasswordSheet(), device: DevicePreset.compact));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      UiGlitchInspector.assertNoOverflows(tester);
      UiGlitchInspector.assertNoUnintendedTruncation(tester);

      await tester.pumpWidget(buildTestBed(const EmailVerificationScreen(email: 'alex@trackmytrip.app'), device: DevicePreset.compact));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      UiGlitchInspector.assertNoOverflows(tester);
    });

    testWidgets('3. Home & Trip Creation: HomeScreen, CreateTripSheet, JoinTripSheet, QrScannerScreen', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.runAsync(() async => await storage.saveAuthSession(testUser));
      for (final device in [DevicePreset.compact, DevicePreset.standard]) {
        applyDeviceSurface(tester, device.logicalSize);

        await tester.pumpWidget(buildTestBed(const HomeScreen(), device: device));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(const CreateTripSheet(), device: device));
        await tester.pumpAndSettle();
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(const JoinTripSheet(), device: device));
        await tester.pumpAndSettle();
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(const QrScannerScreen(), device: device));
        await tester.pumpAndSettle();
        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('4. Cockpit & Current Trip Tab: CurrentTripTab & CurrentTripHeroCard', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final device in [DevicePreset.compact, DevicePreset.standard]) {
        applyDeviceSurface(tester, device.logicalSize);

        await tester.pumpWidget(buildTestBed(const CurrentTripTab(), device: device));
        await tester.pumpAndSettle();
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(
          buildTestBed(
            CurrentTripHeroCard(
              trip: testTrip,
              isDark: false,
              onTapLedger: () {},
            ),
            device: device,
          ),
        );
        await tester.pumpAndSettle();
        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('5. Trip Detail Core Subtabs: Timeline, Expenses, Settlement, Members, Memories', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final device in [DevicePreset.compact, DevicePreset.standard]) {
        applyDeviceSurface(tester, device.logicalSize);

        // Expenses Tab
        await tester.pumpWidget(buildTestBed(ExpensesTab(trip: testTrip), device: device));
        await tester.pumpAndSettle();
        UiGlitchInspector.assertNoOverflows(tester);

        // Timeline Tab
        await tester.pumpWidget(buildTestBed(TimelineTab(trip: testTrip), device: device));
        await tester.pumpAndSettle();
        UiGlitchInspector.assertNoOverflows(tester);

        // Settlement Tab
        await tester.pumpWidget(buildTestBed(SettlementTab(trip: testTrip), device: device));
        await tester.pumpAndSettle();
        UiGlitchInspector.assertNoOverflows(tester);

        // Members Tab
        await tester.pumpWidget(buildTestBed(MembersTab(trip: testTrip), device: device));
        await tester.pumpAndSettle();
        UiGlitchInspector.assertNoOverflows(tester);

        // Memories Tab
        await tester.pumpWidget(buildTestBed(MemoriesTab(trip: testTrip), device: device));
        await tester.pumpAndSettle();
        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('6. Analytics, Hub & Profile: TripAnalyticsScreen, ActivityHubTab, ProfileTab', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final device in [DevicePreset.compact, DevicePreset.standard]) {
        applyDeviceSurface(tester, device.logicalSize);

        await tester.pumpWidget(buildTestBed(TripAnalyticsScreen(tripId: testTrip.id), device: device));
        await tester.pumpAndSettle();
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(const ActivityHubTab(), device: device));
        await tester.pumpAndSettle();
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(const ProfileTab(), device: device));
        await tester.pumpAndSettle();
        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('7. Modals & Overlays: GlobalExpensesSheet, NotificationCenterSheet, AuditLogSheet, ShareTripSheet', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final device in [DevicePreset.compact, DevicePreset.standard]) {
        applyDeviceSurface(tester, device.logicalSize);

        await tester.pumpWidget(buildTestBed(const GlobalExpensesSheet(), device: device));
        await tester.pumpAndSettle();
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(const NotificationCenterSheet(), device: device));
        await tester.pumpAndSettle();
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(AuditLogSheet(trip: testTrip), device: device));
        await tester.pumpAndSettle();
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(ShareTripSheet(trip: testTrip), device: device));
        await tester.pumpAndSettle();
        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('8. Dialogs & Action Sheets: AddExpenseScreen, EditTripDialog, StoppageDetailScreen, AddMemoryDialog, CompanionSearchDialog', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final device in [DevicePreset.compact, DevicePreset.standard]) {
        applyDeviceSurface(tester, device.logicalSize);

        await tester.pumpWidget(buildTestBed(AddExpenseScreen(tripId: testTrip.id), device: device));
        await tester.pumpAndSettle();
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(EditTripDialog(trip: testTrip), device: device));
        await tester.pumpAndSettle();
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(StoppageDetailScreen(stoppageId: testStoppage.id, tripId: testTrip.id), device: device));
        await tester.pumpAndSettle();
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(AddMemoryDialog(tripId: testTrip.id, stoppage: testStoppage), device: device));
        await tester.pumpAndSettle();
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(CompanionSearchDialog(currentMembers: testTrip.members, onCompanionSelected: (_) {}), device: device));
        await tester.pump(const Duration(milliseconds: 500));
        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });
  });
}
