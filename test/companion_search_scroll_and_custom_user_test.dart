import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:trackmytrip/core/database/app_database.dart';
import 'package:trackmytrip/core/services/local_storage_service.dart';
import 'package:trackmytrip/core/services/push_notification_service.dart';
import 'package:trackmytrip/core/services/user_service.dart';
import 'package:trackmytrip/models/trip.dart';
import 'package:trackmytrip/models/trip_member.dart';
import 'package:trackmytrip/providers/invitation_provider.dart';
import 'package:trackmytrip/providers/trip_provider.dart';
import 'package:trackmytrip/screens/trip/companion_search_dialog.dart';

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

  const arunCreator = TripMember(
    id: 'usr_arun_1',
    name: 'Arun',
    email: 'arun@example.com',
    role: 'creator',
  );

  const customMember1 = TripMember(
    id: 'custom_dbddb3ec',
    name: 'Anuj',
    email: null,
    role: 'member',
  );

  const customMember2 = TripMember(
    id: 'offline_c335d539',
    name: 'Prem',
    email: '',
    role: 'member',
  );

  const registeredCompanion = TripMember(
    id: 'usr_pankaj_2',
    name: 'Pankaj',
    email: 'pankaj@example.com',
    role: 'member',
  );

  final testTrip = Trip(
    id: 'trip_manali_101',
    title: 'Manali Expedition',
    startDate: DateTime(2026, 10, 1),
    endDate: DateTime(2026, 10, 5),
    createdByMemberId: 'usr_arun_1',
    members: const [arunCreator, customMember1, customMember2, registeredCompanion],
    defaultCurrency: 'INR',
    tripType: 'group',
    createdAt: DateTime(2026, 10, 1),
  );

  setUpAll(() async {
    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details, forceReport: true);
    };
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final appDb = await AppDatabase.open(customPath: inMemoryDatabasePath);
    storage = await LocalStorageService.init(prefs: prefs, database: appDb);
    await storage.saveTrip(testTrip);
  });

  group('Custom User Exclusion from User Suggestions & Search', () {
    test('UserService.getSuggestedUsers filters out custom_ and offline_ companions without email', () async {
      final suggested = await UserService.getSuggestedUsers();

      // customMember1 (Anuj) and customMember2 (Prem) must NOT be returned in suggested
      expect(suggested.any((u) => u.id == 'custom_dbddb3ec'), isFalse);
      expect(suggested.any((u) => u.id == 'offline_c335d539'), isFalse);
      expect(suggested.any((u) => u.displayName.toLowerCase() == 'anuj'), isFalse);
      expect(suggested.any((u) => u.displayName.toLowerCase() == 'prem'), isFalse);

      // Only registered companion with email (Pankaj) is eligible
      final pankaj = suggested.where((u) => u.id == 'usr_pankaj_2').firstOrNull;
      if (pankaj != null) {
        expect(pankaj.email, equals('pankaj@example.com'));
      }
    });

    test('UserService.searchUsers filters out custom_ and offline_ companions without email', () async {
      final anujResults = await UserService.searchUsers('anuj');
      expect(anujResults.any((u) => u.id.startsWith('custom_')), isFalse);
      expect(anujResults.any((u) => u.email == null || u.email!.isEmpty), isFalse);

      final premResults = await UserService.searchUsers('prem');
      expect(premResults.any((u) => u.id.startsWith('offline_')), isFalse);
    });
  });

  group('Invitation Guard: Suppress Invitations to Custom/Offline Companions', () {
    test('InvitationNotifier.sendInvitation suppresses invitation when inviteeId is custom_', () async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          pushNotificationServiceProvider.overrideWithValue(MockPushNotificationService()),
        ],
      );

      final notifier = container.read(invitationProvider.notifier);

      final beforeCount = storage.getSentInvitations().length;

      // Attempt to invite a custom companion
      await notifier.sendInvitation(
        tripId: testTrip.id,
        tripTitle: testTrip.title,
        inviteeId: 'custom_dbddb3ec',
        inviteeUsername: 'anuj',
        inviteeEmail: null,
      );

      final afterCount = storage.getSentInvitations().length;
      expect(afterCount, equals(beforeCount), reason: 'Invitation must be suppressed for custom_ ID');
    });

    test('InvitationNotifier.sendInvitation suppresses invitation when no email or registered ID is provided', () async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          pushNotificationServiceProvider.overrideWithValue(MockPushNotificationService()),
        ],
      );

      final notifier = container.read(invitationProvider.notifier);
      final beforeCount = storage.getSentInvitations().length;

      await notifier.sendInvitation(
        tripId: testTrip.id,
        tripTitle: testTrip.title,
        inviteeId: null,
        inviteeUsername: 'anonymous',
        inviteeEmail: null,
      );

      final afterCount = storage.getSentInvitations().length;
      expect(afterCount, equals(beforeCount), reason: 'Invitation must be suppressed without email or ID');
    });
  });

  group('CompanionSearchDialog Responsive & Overflow Verification', () {
    const viewports = [
      Size(320, 568),  // Compact Mobile
      Size(393, 852),  // Standard Mobile
      Size(412, 915),  // Large Mobile
      Size(800, 1280), // Tablet Portrait
      Size(1280, 800), // Desktop / Landscape
    ];

    Widget buildTestBed(Widget child, {required Size size, double fontScale = 1.0}) {
      return ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          pushNotificationServiceProvider.overrideWithValue(MockPushNotificationService()),
          selectedTripIdProvider.overrideWith((ref) => testTrip.id),
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

    testWidgets('CompanionSearchDialog renders with zero overflow across 5 viewports at 1.0x, 1.3x, 1.5x font scales', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final vp in viewports) {
        for (final fontScale in [1.0, 1.3, 1.5]) {
          tester.view.physicalSize = vp;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(buildTestBed(
            CompanionSearchDialog(
              currentMembers: testTrip.members,
              onCompanionSelected: (_) {},
            ),
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
