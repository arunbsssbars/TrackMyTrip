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
import 'package:trackmytrip/models/trip_audit_log.dart';
import 'package:trackmytrip/models/user_profile.dart';
import 'package:trackmytrip/providers/trip_provider.dart';

import 'package:trackmytrip/screens/trip_detail/tabs/analytics_tab.dart';
import 'package:trackmytrip/screens/trip_detail/tabs/audit_tab.dart';

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

  const arnikaMember = TripMember(
    id: 'usr_arnika_1',
    name: 'Arnika',
    email: 'arnika@example.com',
    phoneNumber: '+919876543210',
    role: TripMember.roleCreator,
  );

  const arunMember = TripMember(
    id: 'usr_arun_2',
    name: 'Arun',
    email: 'arun@example.com',
    phoneNumber: '+919876543211',
    role: 'admin',
  );

  final chandratalTrip = Trip(
    id: 'trip_chandratal_101',
    title: 'Chandratal Lake Expedition',
    description: 'High altitude camping in Spiti',
    startDate: DateTime(2026, 9, 10),
    endDate: DateTime(2026, 9, 15),
    createdByMemberId: 'usr_arnika_1',
    members: const [arnikaMember, arunMember],
    defaultCurrency: 'INR',
    budget: 35000.0,
    tripType: 'group',
    createdAt: DateTime(2026, 9, 10),
  );

  final sampleStoppages = [
    Stoppage(
      id: 'stop_1',
      tripId: chandratalTrip.id,
      name: 'Manali Basecamp',
      latitude: 32.2432,
      longitude: 77.1892,
      category: 'campsite',
      arrivedAt: DateTime(2026, 9, 10, 10, 0),
      createdBy: 'usr_arnika_1',
    ),
    Stoppage(
      id: 'stop_2',
      tripId: chandratalTrip.id,
      name: 'Rohtang Pass Viewpoint',
      latitude: 32.3716,
      longitude: 77.2466,
      category: 'viewpoint',
      arrivedAt: DateTime(2026, 9, 11, 14, 0),
      createdBy: 'usr_arnika_1',
    ),
  ];

  final sampleExpenses = [
    Expense(
      id: 'exp_1',
      tripId: chandratalTrip.id,
      title: 'Camping Gear Rental',
      totalAmount: 12000.0,
      currency: 'INR',
      category: 'equipment',
      paidByMemberId: 'usr_arnika_1',
      createdAt: DateTime(2026, 9, 10),
      splitType: SplitType.equal,
      splits: const [
        ExpenseSplit(memberId: 'usr_arnika_1', allocatedAmount: 6000.0),
        ExpenseSplit(memberId: 'usr_arun_2', allocatedAmount: 6000.0),
      ],
    ),
    Expense(
      id: 'exp_2',
      tripId: chandratalTrip.id,
      title: 'Fuel & Jeep 4x4',
      totalAmount: 15500.0,
      currency: 'INR',
      category: 'fuel',
      paidByMemberId: 'usr_arun_2',
      createdAt: DateTime(2026, 9, 11),
      splitType: SplitType.equal,
      splits: const [
        ExpenseSplit(memberId: 'usr_arnika_1', allocatedAmount: 7750.0),
        ExpenseSplit(memberId: 'usr_arun_2', allocatedAmount: 7750.0),
      ],
    ),
  ];

  final sampleAuditLogs = [
    TripAuditLog(
      id: 'log_fin_1',
      tripId: chandratalTrip.id,
      actionType: 'create_expense',
      itemTitle: 'Camping Gear Rental',
      amount: 12000.0,
      currency: 'INR',
      performedByMemberId: 'usr_arnika_1',
      performedByName: 'Arnika',
      timestamp: DateTime(2026, 9, 10, 11, 0),
      changeDetails: 'Added bill of ₹12,000 for 2 members',
    ),
    TripAuditLog(
      id: 'log_fin_2',
      tripId: chandratalTrip.id,
      actionType: 'record_payment',
      itemTitle: 'Settlement Payment to Arnika',
      amount: 1750.0,
      currency: 'INR',
      performedByMemberId: 'usr_arun_2',
      performedByName: 'Arun',
      timestamp: DateTime(2026, 9, 12, 16, 0),
      changeDetails: 'Paid ₹1,750 via UPI',
    ),
    TripAuditLog(
      id: 'log_fin_3',
      tripId: chandratalTrip.id,
      actionType: 'create_settlement_advance',
      itemTitle: 'Advance for Camp Booking',
      amount: 5000.0,
      currency: 'INR',
      performedByMemberId: 'usr_arnika_1',
      performedByName: 'Arnika',
      timestamp: DateTime(2026, 9, 8, 10, 0),
      changeDetails: 'Advance payment of ₹5,000 recorded',
    ),
  ];

  setUpAll(() async {
    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details, forceReport: true);
    };
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final appDb = await AppDatabase.open(customPath: inMemoryDatabasePath);
    storage = await LocalStorageService.init(prefs: prefs, database: appDb);
    await storage.saveTrip(chandratalTrip);
    for (final s in sampleStoppages) {
      await storage.saveStoppage(s);
    }
    for (final e in sampleExpenses) {
      await storage.saveExpense(e);
    }
    for (final a in sampleAuditLogs) {
      await storage.saveAuditLog(a);
    }
  });

  Widget buildTestBed(Widget child, {required Size size, double fontScale = 1.0}) {
    return ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        pushNotificationServiceProvider.overrideWithValue(MockPushNotificationService()),
        selectedTripIdProvider.overrideWith((ref) => chandratalTrip.id),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(fontScale),
          ),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  group('Item 4 Verification: Pure Financial Trip Audit', () {
    test('isFinancial predicate strictly filters financial vs non-financial events', () {
      final billLog = TripAuditLog(
        id: '1', tripId: 't1', actionType: 'create_expense',
        itemTitle: 'Dinner', performedByMemberId: 'u1', performedByName: 'A',
        timestamp: DateTime.now(),
      );
      final updateBillLog = TripAuditLog(
        id: '2', tripId: 't1', actionType: 'update_expense',
        itemTitle: 'Dinner edit', performedByMemberId: 'u1', performedByName: 'A',
        timestamp: DateTime.now(),
      );
      final deleteBillLog = TripAuditLog(
        id: '3', tripId: 't1', actionType: 'delete_bill',
        itemTitle: 'Remove bill', performedByMemberId: 'u1', performedByName: 'A',
        timestamp: DateTime.now(),
      );
      final paymentLog = TripAuditLog(
        id: '4', tripId: 't1', actionType: 'record_payment',
        itemTitle: 'Settlement', performedByMemberId: 'u1', performedByName: 'A',
        timestamp: DateTime.now(),
      );
      final advanceLog = TripAuditLog(
        id: '5', tripId: 't1', actionType: 'record_advance',
        itemTitle: 'Advance deposit', performedByMemberId: 'u1', performedByName: 'A',
        timestamp: DateTime.now(),
      );
      final budgetLog = TripAuditLog(
        id: '6', tripId: 't1', actionType: 'update_budget',
        itemTitle: 'Trip budget adjusted', performedByMemberId: 'u1', performedByName: 'A',
        timestamp: DateTime.now(),
      );

      // Non-financial events
      final photoLog = TripAuditLog(
        id: '7', tripId: 't1', actionType: 'add_memory',
        itemTitle: 'Lake photo', performedByMemberId: 'u1', performedByName: 'A',
        timestamp: DateTime.now(),
      );
      final stopLog = TripAuditLog(
        id: '8', tripId: 't1', actionType: 'create_stoppage',
        itemTitle: 'Gas station', performedByMemberId: 'u1', performedByName: 'A',
        timestamp: DateTime.now(),
      );
      final sosLog = TripAuditLog(
        id: '9', tripId: 't1', actionType: 'send_sos_alert',
        itemTitle: 'Emergency SOS', performedByMemberId: 'u1', performedByName: 'A',
        timestamp: DateTime.now(),
      );

      expect(billLog.isFinancial, isTrue);
      expect(updateBillLog.isFinancial, isTrue);
      expect(deleteBillLog.isFinancial, isTrue);
      expect(paymentLog.isFinancial, isTrue);
      expect(advanceLog.isFinancial, isTrue);
      expect(budgetLog.isFinancial, isTrue);

      expect(photoLog.isFinancial, isFalse);
      expect(stopLog.isFinancial, isFalse);
      expect(sosLog.isFinancial, isFalse);
    });
  });

  group('Item 5 Verification: Single Authentic Creator Exclusivity', () {
    test('Only authentic creator has isMemberCreator == true', () {
      expect(chandratalTrip.isMemberCreator(arnikaMember), isTrue);
      expect(chandratalTrip.isMemberCreator(arunMember), isFalse);

      expect(arnikaMember.displayRole, equals('Creator'));
      expect(arunMember.displayRole, equals('Admin'));
      expect(arunMember.isCreator, isFalse);
    });

    test('Trip.isCreator checks creator ID accurately and rejects invited admins', () {
      expect(chandratalTrip.isCreator('usr_arnika_1'), isTrue);
      expect(chandratalTrip.isCreator('usr_arun_2'), isFalse);
      expect(chandratalTrip.isCreator(null), isFalse);
      expect(chandratalTrip.isCreator(''), isFalse);
    });
  });

  group('Item 2 Verification: Mobile Number Deserialization & Persistence', () {
    test('AuthUser & UserProfile deserialize phone across diverse field aliases', () {
      final user1 = AuthUser.fromJson({
        'id': 'u1', 'username': 'user1', 'email': 'u1@test.com', 'phone': '+919999911111'
      });
      final user2 = AuthUser.fromJson({
        'id': 'u2', 'username': 'user2', 'email': 'u2@test.com', 'phoneNumber': '+919999922222'
      });
      final user3 = AuthUser.fromJson({
        'id': 'u3', 'username': 'user3', 'email': 'u3@test.com', 'mobile': '+919999933333'
      });
      final profile = UserProfile.fromJson({
        'id': 'p1', 'username': 'prof1', 'email': 'p1@test.com', 'mobileNumber': '+919999944444'
      });

      expect(user1.phone, equals('+919999911111'));
      expect(user2.phone, equals('+919999922222'));
      expect(user3.phone, equals('+919999933333'));
      expect(profile.phone, equals('+919999944444'));
    });
  });

  group('AQIL Multi-Viewport Verification: AnalyticsTab & AuditTab', () {
    const viewports = [
      Size(320, 568),   // Compact Mobile (iPhone SE 1st gen)
      Size(393, 852),   // Standard Mobile (iPhone 16 Pro)
      Size(412, 915),   // Large Mobile (Pixel 8)
      Size(800, 1280),  // Tablet Portrait
      Size(1280, 800),  // Tablet / Desktop Landscape
    ];

    testWidgets('AnalyticsTab renders with zero overflow across 5 viewports at 1.0x, 1.3x, 1.5x font scale', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final vp in viewports) {
        for (final fontScale in [1.0, 1.3, 1.5]) {
          tester.view.physicalSize = vp;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(buildTestBed(
            AnalyticsTab(trip: chandratalTrip),
            size: vp,
            fontScale: fontScale,
          ));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          UiGlitchInspector.assertNoOverflows(tester);
        }
      }
    });

    testWidgets('AuditTab renders with zero overflow across 5 viewports at 1.0x, 1.3x, 1.5x font scale', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final vp in viewports) {
        for (final fontScale in [1.0, 1.3, 1.5]) {
          tester.view.physicalSize = vp;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(buildTestBed(
            AuditTab(trip: chandratalTrip),
            size: vp,
            fontScale: fontScale,
          ));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          UiGlitchInspector.assertNoOverflows(tester);
        }
      }
    });
  });
}
