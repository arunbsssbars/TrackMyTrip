import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:latlong2/latlong.dart';

import 'package:trackmytrip/core/database/app_database.dart';
import 'package:trackmytrip/core/services/local_storage_service.dart';
import 'package:trackmytrip/core/services/push_notification_service.dart';
import 'package:trackmytrip/core/theme/app_theme.dart';
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

// Screens, Sheets & Dialogs across the application
import 'package:trackmytrip/screens/main_scaffold.dart';
import 'package:trackmytrip/screens/home/home_screen.dart';
import 'package:trackmytrip/screens/home/create_trip_sheet.dart';
import 'package:trackmytrip/screens/home/join_trip_sheet.dart';
import 'package:trackmytrip/screens/home/qr_scanner_screen.dart';
import 'package:trackmytrip/screens/trip/current_trip_tab.dart';
import 'package:trackmytrip/screens/trip/companion_search_dialog.dart';
import 'package:trackmytrip/screens/trip_detail/trip_detail_screen.dart';
import 'package:trackmytrip/screens/trip_detail/tabs/timeline_tab.dart';
import 'package:trackmytrip/screens/trip_detail/tabs/expenses_tab.dart';
import 'package:trackmytrip/screens/trip_detail/tabs/settlement_tab.dart';
import 'package:trackmytrip/screens/trip_detail/tabs/members_tab.dart';
import 'package:trackmytrip/screens/trip_detail/tabs/memories_tab.dart';
import 'package:trackmytrip/screens/trip_detail/audit_log_sheet.dart';
import 'package:trackmytrip/screens/trip_detail/edit_trip_dialog.dart';
import 'package:trackmytrip/screens/trip_detail/share_trip_sheet.dart';
import 'package:trackmytrip/screens/trip_detail/widgets/offline_map_download_sheet.dart';
import 'package:trackmytrip/screens/activity/activity_hub_tab.dart';
import 'package:trackmytrip/screens/profile/profile_tab.dart';
import 'package:trackmytrip/screens/stats/trip_analytics_screen.dart';
import 'package:trackmytrip/screens/stoppage/stoppage_detail_screen.dart';
import 'package:trackmytrip/screens/stoppage/add_stoppage_dialog.dart';
import 'package:trackmytrip/screens/memories/add_memory_dialog.dart';
import 'package:trackmytrip/screens/auth/login_screen.dart';
import 'package:trackmytrip/screens/auth/signup_screen.dart';
import 'package:trackmytrip/screens/auth/email_verification_screen.dart';
import 'package:trackmytrip/screens/auth/forgot_password_sheet.dart';
import 'package:trackmytrip/screens/expenses/add_expense_screen.dart';
import 'package:trackmytrip/screens/expenses/global_expenses_sheet.dart';
import 'package:trackmytrip/screens/notifications/notification_center_sheet.dart';
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
    id: 'user_aqil_master_1',
    email: 'alex@trackmytrip.app',
    displayName: 'Alex Explorer',
    username: 'alex_explorer',
    provider: AuthProviderType.email,
    createdAt: DateTime(2026, 1, 1),
  );

  final testTrip = Trip(
    id: 'trip_aqil_master_101',
    title: 'Himalayan Ridge Expedition 2026',
    description: 'Autonomous exploration from Manali to Leh across high-altitude mountain passes.',
    startDate: DateTime.now().subtract(const Duration(days: 2)),
    endDate: DateTime.now().add(const Duration(days: 5)),
    defaultCurrency: 'USD',
    budget: 5000.0,
    shareCode: 'HIMA-2026',
    tripType: 'group',
    createdByMemberId: 'user_aqil_master_1',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    members: const [
      TripMember(
        id: 'user_aqil_master_1',
        name: 'Alex Explorer',
        email: 'alex@trackmytrip.app',
        isCurrentUser: true,
        colorHex: '0xFF0D9488',
        role: 'creator',
      ),
      TripMember(
        id: 'user_aqil_master_2',
        name: 'Priya Sharma',
        email: 'priya@trackmytrip.app',
        phoneNumber: '+15550192834',
        isCurrentUser: false,
        colorHex: '0xFF3B82F6',
        role: 'editor',
      ),
      TripMember(
        id: 'user_aqil_master_3',
        name: 'Carlos Mendez',
        email: 'carlos@trackmytrip.app',
        isCurrentUser: false,
        colorHex: '0xFFF59E0B',
        role: 'viewer',
      ),
    ],
  );

  final testExpense = Expense(
    id: 'exp_aqil_master_1',
    tripId: 'trip_aqil_master_101',
    title: 'High Altitude Basecamp Fuel & Supplies',
    totalAmount: 145.50,
    currency: 'USD',
    category: 'Fuel',
    paidByMemberId: 'user_aqil_master_1',
    splitType: SplitType.equal,
    splits: const [
      ExpenseSplit(memberId: 'user_aqil_master_1', allocatedAmount: 48.50),
      ExpenseSplit(memberId: 'user_aqil_master_2', allocatedAmount: 48.50),
      ExpenseSplit(memberId: 'user_aqil_master_3', allocatedAmount: 48.50),
    ],
    createdAt: DateTime.now(),
    isPersonal: false,
  );

  final testStoppage = Stoppage(
    id: 'stop_aqil_master_1',
    tripId: 'trip_aqil_master_101',
    name: 'Rohtang Pass Crest',
    latitude: 32.3716,
    longitude: 77.2466,
    category: 'Scenic Viewpoint',
    arrivedAt: DateTime.now().subtract(const Duration(hours: 3)),
    createdBy: 'user_aqil_master_1',
    notes: 'Panoramic mountain vista at 3980m elevation.',
  );

  final testMemory = Memory(
    id: 'mem_aqil_master_1',
    tripId: 'trip_aqil_master_101',
    stoppageId: 'stop_aqil_master_1',
    uploadedByMemberId: 'user_aqil_master_1',
    mediaPath: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    caption: 'Glacial peak panorama at sunrise',
    createdAt: DateTime.now(),
  );

  final testSettlement = Settlement(
    id: 'settle_aqil_master_1',
    tripId: 'trip_aqil_master_101',
    payerMemberId: 'user_aqil_master_2',
    receiverMemberId: 'user_aqil_master_1',
    amount: 48.50,
    currency: 'USD',
    settledAt: DateTime.now(),
    paymentMethod: 'Cash',
    notes: 'Basecamp fuel reimbursement',
  );

  final testAuditLog = TripAuditLog(
    id: 'audit_aqil_master_1',
    tripId: 'trip_aqil_master_101',
    actionType: 'create_expense',
    itemTitle: 'High Altitude Basecamp Fuel',
    performedByMemberId: 'user_aqil_master_1',
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

  Widget buildTestBed(Widget child, {required Size size, double fontScale = 1.0, bool isDark = false}) {
    return ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        pushNotificationServiceProvider.overrideWithValue(MockPushNotificationService()),
        selectedTripIdProvider.overrideWith((ref) => testTrip.id),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(fontScale),
            padding: const EdgeInsets.only(top: 24, bottom: 16),
            viewInsets: EdgeInsets.zero,
          ),
          child: child,
        ),
      ),
    );
  }

  const viewports = [
    Size(320, 568),  // Compact mobile
    Size(390, 844),  // Standard mobile
    Size(412, 915),  // Large mobile
    Size(768, 1024), // Tablet portrait
    Size(1280, 800), // Desktop landscape
  ];

  group('Universal AQIL Multi-Viewport Master Verification Across All Screens', () {
    testWidgets('Section 1: Authentication & Onboarding (Login, Signup, Verify, Forgot)', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final vp in viewports) {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(buildTestBed(const LoginScreen(), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(const SignUpScreen(), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(const EmailVerificationScreen(email: 'alex@trackmytrip.app'), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(const ForgotPasswordSheet(), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('Section 2: Home Dashboard & Quick Sheets (Home, Create, Join, QR)', (tester) async {
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

        await tester.pumpWidget(buildTestBed(const CreateTripSheet(), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(const JoinTripSheet(), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(const QrScannerScreen(), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('Section 3: Cockpit & Active Navigation (CurrentTripTab & HeroCard)', (tester) async {
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

        await tester.pumpWidget(buildTestBed(CurrentTripHeroCard(trip: testTrip, isDark: false, onTapLedger: () {}), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('Section 4: Trip Detail Screen & TimelineTab', (tester) async {
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

        await tester.pumpWidget(buildTestBed(TimelineTab(trip: testTrip), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('Section 5: Financial Operations (ExpensesTab, AddExpenseScreen, GlobalExpensesSheet)', (tester) async {
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

        await tester.pumpWidget(buildTestBed(const GlobalExpensesSheet(), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('Section 6: Group Settlement & Members Collaboration', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final vp in viewports) {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(buildTestBed(SettlementTab(trip: testTrip), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(MembersTab(trip: testTrip), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(CompanionSearchDialog(currentMembers: testTrip.members, onCompanionSelected: (_) {}), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('Section 7: Memories & Stoppages (MemoriesTab, AddMemoryDialog, StoppageDetailScreen, AddStoppageDialog)', (tester) async {
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

        await tester.pumpWidget(buildTestBed(AddMemoryDialog(tripId: testTrip.id, stoppage: testStoppage), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(StoppageDetailScreen(stoppageId: testStoppage.id, tripId: testTrip.id), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(AddStoppageDialog(tripId: testTrip.id, autoDetectGps: false), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('Section 8: Activity Hub, Notifications & Audit Log (Hub, Center, Sheet)', (tester) async {
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

    testWidgets('Section 9: Trip Analytics, Profile, Share, Edit & Offline Maps', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final vp in viewports) {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(buildTestBed(TripAnalyticsScreen(tripId: testTrip.id), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(const ProfileTab(), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(ShareTripSheet(trip: testTrip), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(EditTripDialog(trip: testTrip), size: vp, fontScale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(
          OfflineMapDownloadSheet(
            routePoints: const [LatLng(32.37, 77.24), LatLng(32.38, 77.25)],
            tripTitle: testTrip.title,
          ),
          size: vp,
          fontScale: 1.3,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('Section 10: App Shell & Extreme Accessibility Font Scaling 1.5x (MainScaffold & All Hubs)', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      const compactVp = Size(320, 568);
      const standardVp = Size(390, 844);

      for (final vp in [compactVp, standardVp]) {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(buildTestBed(const MainScaffold(), size: vp, fontScale: 1.5));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(TripDetailScreen(tripId: testTrip.id), size: vp, fontScale: 1.5));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(ExpensesTab(trip: testTrip), size: vp, fontScale: 1.5));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(SettlementTab(trip: testTrip), size: vp, fontScale: 1.5));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(MembersTab(trip: testTrip), size: vp, fontScale: 1.5));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);

        await tester.pumpWidget(buildTestBed(MemoriesTab(trip: testTrip), size: vp, fontScale: 1.5));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        UiGlitchInspector.assertNoOverflows(tester);
      }
      await tester.pump(const Duration(seconds: 12));
    });
  });
}
