import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trip_tracker_app/core/database/app_database.dart';
import 'package:trip_tracker_app/core/services/local_storage_service.dart';
import 'package:trip_tracker_app/core/services/user_service.dart';
import 'package:trip_tracker_app/models/trip.dart';
import 'package:trip_tracker_app/models/trip_member.dart';
import 'package:trip_tracker_app/models/expense.dart';
import 'package:trip_tracker_app/models/trip_invitation.dart';
import 'package:trip_tracker_app/models/user_profile.dart';
import 'package:trip_tracker_app/core/services/trip_share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late SharedPreferences prefs;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('trip_isolation_test_');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('MASVS-STORAGE: Per-User SQLite Database Partitioning & Isolation', () {
    test('User A and User B have physically isolated databases and zero cross-contamination', () async {
      final userADbPath = '${tempDir.path}/trip_tracker_user_a.db';
      final userBDbPath = '${tempDir.path}/trip_tracker_user_b.db';

      // 1. User A session
      final dbA = await AppDatabase.open(customPath: userADbPath);
      final storageA = await LocalStorageService.init(prefs: prefs, database: dbA, initialUserId: 'user_a');

      final tripA = Trip(
        id: 'trip_alpha',
        title: 'Arun Himalayas Tour',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 5)),
        defaultCurrency: 'INR',
        tripType: 'solo',
        members: [
          const TripMember(id: 'user_a', name: 'Arun', isCurrentUser: true),
        ],
        createdByMemberId: 'user_a',
        createdAt: DateTime.now(),
      );

      final expenseA = Expense(
        id: 'exp_alpha',
        tripId: 'trip_alpha',
        title: 'Fuel Tanker',
        totalAmount: 3500.0,
        currency: 'INR',
        category: 'fuel',
        paidByMemberId: 'user_a',
        splitType: SplitType.equal,
        splits: const [],
        createdAt: DateTime.now(),
      );

      await storageA.saveTrip(tripA);
      await storageA.saveExpense(expenseA);

      expect(storageA.getTrips().length, 1);
      expect(storageA.getTrips().first.title, 'Arun Himalayas Tour');
      expect(storageA.getAllExpenses().length, 1);
      expect(storageA.getAllExpenses().first.title, 'Fuel Tanker');

      // 2. User A logs out -> switch to User B session
      final dbB = await AppDatabase.open(customPath: userBDbPath);
      final storageB = await LocalStorageService.init(prefs: prefs, database: dbB, initialUserId: 'user_b');

      // User B MUST see 0 trips and 0 expenses from User A
      expect(storageB.getTrips(), isEmpty);
      expect(storageB.getAllExpenses(), isEmpty);

      // User B creates their own trip and expense
      final tripB = Trip(
        id: 'trip_beta',
        title: 'Savitri Delhi Exploration',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 2)),
        defaultCurrency: 'INR',
        tripType: 'solo',
        members: [
          const TripMember(id: 'user_b', name: 'Savitri', isCurrentUser: true),
        ],
        createdByMemberId: 'user_b',
        createdAt: DateTime.now(),
      );

      final expenseB = Expense(
        id: 'exp_beta',
        tripId: 'trip_beta',
        title: 'Museum Entry Ticket',
        totalAmount: 250.0,
        currency: 'INR',
        category: 'activities',
        paidByMemberId: 'user_b',
        splitType: SplitType.equal,
        splits: const [],
        createdAt: DateTime.now(),
      );

      await storageB.saveTrip(tripB);
      await storageB.saveExpense(expenseB);

      expect(storageB.getTrips().length, 1);
      expect(storageB.getTrips().first.title, 'Savitri Delhi Exploration');
      expect(storageB.getAllExpenses().length, 1);
      expect(storageB.getAllExpenses().first.title, 'Museum Entry Ticket');

      // 3. User B logs out -> Switch back to User A
      final dbAReloaded = await AppDatabase.open(customPath: userADbPath);
      final storageAReloaded = await LocalStorageService.init(prefs: prefs, database: dbAReloaded, initialUserId: 'user_a');

      // User A sees ONLY User A data, never User B's museum ticket
      expect(storageAReloaded.getTrips().length, 1);
      expect(storageAReloaded.getTrips().first.id, 'trip_alpha');
      expect(storageAReloaded.getAllExpenses().length, 1);
      expect(storageAReloaded.getAllExpenses().first.id, 'exp_alpha');
      expect(storageAReloaded.getAllExpenses().any((e) => e.id == 'exp_beta'), isFalse);
    });

    test('getDbNameForUser normalizes user ID correctly and handles guest', () {
      expect(AppDatabase.getDbNameForUser(null), 'trip_tracker_guest.db');
      expect(AppDatabase.getDbNameForUser(''), 'trip_tracker_guest.db');
      expect(AppDatabase.getDbNameForUser('   '), 'trip_tracker_guest.db');
      expect(AppDatabase.getDbNameForUser('usr_arun123'), 'trip_tracker_usr_arun123.db');
      expect(AppDatabase.getDbNameForUser('user@example.com'), 'trip_tracker_user_example_com.db');
    });
  });

  group('Two-Phase Trip Invitation Workflow', () {
    test('Trip creation keeps only creator in members and generates pending invitation', () async {
      final db = await AppDatabase.open(customPath: '${tempDir.path}/test_inv.db');
      final storage = await LocalStorageService.init(prefs: prefs, database: db, initialUserId: 'creator_1');

      // 1. Initial trip only contains creator
      const creator = TripMember(id: 'creator_1', name: 'Trip Lead', isCurrentUser: true);
      final newTrip = Trip(
        id: 'trip_shared_101',
        title: 'Goa Coastal Drive',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 4)),
        defaultCurrency: 'INR',
        tripType: 'friends',
        members: [creator],
        createdByMemberId: 'creator_1',
        createdAt: DateTime.now(),
      );

      await storage.saveTrip(newTrip);

      // Verify members list has ONLY the creator
      expect(newTrip.members.length, 1);
      expect(newTrip.members.first.id, 'creator_1');

      // 2. Dispatch pending invitation for companion
      final invitation = TripInvitation(
        id: 'inv_101',
        tripId: newTrip.id,
        tripTitle: newTrip.title,
        inviterId: 'creator_1',
        inviterName: 'Trip Lead',
        inviteeEmail: 'savitri.devi838390@gmail.com',
        inviteeUsername: 'savitri',
        createdAt: DateTime.now(),
        status: InvitationStatus.pending,
        tripJson: newTrip.toJson(),
      );

      await storage.saveInvitation(invitation);

      // Creator checking pending invitations sees 0 (outgoing invitation not shown to creator)
      expect(storage.getPendingInvitations(currentUserId: 'creator_1'), isEmpty);

      // Invitee checking pending invitations sees 1
      final pending = storage.getPendingInvitations(currentUserEmail: 'savitri.devi838390@gmail.com');
      expect(pending.length, 1);
      expect(pending.first.id, 'inv_101');
      expect(pending.first.status, InvitationStatus.pending);

      // 3. Companion declines invitation -> status becomes rejected and trip is NOT added
      await storage.updateInvitationStatus('inv_101', InvitationStatus.rejected);
      final pendingAfterDecline = storage.getPendingInvitations(currentUserEmail: 'savitri.devi838390@gmail.com');
      expect(pendingAfterDecline, isEmpty);

      // 4. Test acceptance workflow on a new invitation
      final invitation2 = invitation.copyWith(id: 'inv_102', status: InvitationStatus.pending);
      await storage.saveInvitation(invitation2);
      expect(storage.getPendingInvitations(currentUserEmail: 'savitri.devi838390@gmail.com').length, 1);

      await storage.updateInvitationStatus('inv_102', InvitationStatus.accepted);
      expect(storage.getPendingInvitations(currentUserEmail: 'savitri.devi838390@gmail.com'), isEmpty);

      final allInvs = storage.getAllInvitations();
      final accepted = allInvs.firstWhere((i) => i.id == 'inv_102');
      expect(accepted.status, InvitationStatus.accepted);
    });

    test('InvitationStatus serializes and deserializes rejected cleanly', () {
      final inv = TripInvitation(
        id: 'inv_test_rejected',
        tripId: 'trip_1',
        tripTitle: 'Test Trip',
        inviterId: 'inv_1',
        inviterName: 'Lead',
        inviteeUsername: 'companion',
        createdAt: DateTime.now(),
        status: InvitationStatus.rejected,
      );

      final json = inv.toJson();
      expect(json['status'], 'rejected');

      final reconstructed = TripInvitation.fromJson(json);
      expect(reconstructed.status, InvitationStatus.rejected);
    });
  });

  group('Global Expenses Tab & Data Isolation Scoping', () {
    test('Foreign expenses not belonging to active user trips are excluded', () async {
      final db = await AppDatabase.open(customPath: '${tempDir.path}/test_expenses.db');
      final storage = await LocalStorageService.init(prefs: prefs, database: db, initialUserId: 'active_user');

      // User has one trip: trip_my
      final myTrip = Trip(
        id: 'trip_my',
        title: 'My Trip',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 2)),
        defaultCurrency: 'INR',
        tripType: 'solo',
        members: [const TripMember(id: 'active_user', name: 'Me', isCurrentUser: true)],
        createdByMemberId: 'active_user',
        createdAt: DateTime.now(),
      );
      await storage.saveTrip(myTrip);

      // Save two expenses: one for trip_my, one foreign for trip_foreign
      final myExpense = Expense(
        id: 'exp_mine',
        tripId: 'trip_my',
        title: 'Lunch',
        totalAmount: 200.0,
        currency: 'INR',
        category: 'food',
        paidByMemberId: 'active_user',
        splitType: SplitType.equal,
        splits: const [],
        createdAt: DateTime.now(),
      );

      final foreignExpense = Expense(
        id: 'exp_foreign',
        tripId: 'trip_foreign',
        title: 'Arun Flight Ticket',
        totalAmount: 5000.0,
        currency: 'INR',
        category: 'transport',
        paidByMemberId: 'arun_other_user',
        splitType: SplitType.equal,
        splits: const [],
        createdAt: DateTime.now(),
      );

      await storage.saveExpense(myExpense);
      await storage.saveExpense(foreignExpense);

      // Scoped filtering logic
      final userTripIds = storage.getTrips().map((t) => t.id).toSet();
      final scopedExpenses = storage.getAllExpenses().where((e) => userTripIds.contains(e.tripId)).toList();

      expect(scopedExpenses.length, 1);
      expect(scopedExpenses.first.id, 'exp_mine');
      expect(scopedExpenses.any((e) => e.id == 'exp_foreign'), isFalse);
    });

    test('AppDatabase.getDbNameForUser resolves guest partition for null or empty user', () {
      expect(AppDatabase.getDbNameForUser(null), 'trip_tracker_guest.db');
      expect(AppDatabase.getDbNameForUser(''), 'trip_tracker_guest.db');
      expect(AppDatabase.getDbNameForUser('   '), 'trip_tracker_guest.db');
      expect(AppDatabase.getDbNameForUser('user_123'), 'trip_tracker_user_123.db');
      expect(AppDatabase.getDbNameForUser('usr:abc!def'), 'trip_tracker_usr_abc_def.db');
    });

    test('UserService.resetCurrentUser purges cached registered users', () {
      UserService.updateCurrentUser(const UserProfile(
        id: 'user_temp',
        username: 'temp_user',
        displayName: 'Temp User',
      ));
      expect(UserService.getCurrentUser().id, 'user_temp');

      UserService.resetCurrentUser();
      expect(UserService.getCurrentUser().id, 'usr_me');
    });

    test('Companion Search: Queries < 2 chars return empty list to protect user directory privacy', () async {
      final emptyResult = await UserService.searchUsers('');
      expect(emptyResult, isEmpty);

      final whitespaceResult = await UserService.searchUsers('   ');
      expect(whitespaceResult, isEmpty);

      final singleCharResult = await UserService.searchUsers('a');
      expect(singleCharResult, isEmpty);

      // Register companion user
      UserService.registerUser(const UserProfile(
        id: 'user_arun',
        username: 'arun_explorer',
        displayName: 'Arun Kumar',
        email: 'arun@example.com',
      ));

      // 2+ chars search performs keyword matching against registered users
      final matchResult = await UserService.searchUsers('arun');
      expect(matchResult.any((u) => u.username.contains('arun') || u.email?.contains('arun') == true), isTrue);
    });

    test('Shared Trip Deletion Semantics: isCreator accurately identifies creator vs companions', () {
      final trip = Trip(
        id: 'trip_collab',
        title: 'Goa Road Trip',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 4)),
        defaultCurrency: 'INR',
        tripType: 'group',
        members: [
          const TripMember(id: 'lead_user', name: 'Lead Arun', isCurrentUser: false),
          const TripMember(id: 'comp_user', name: 'Companion Savitri', isCurrentUser: true),
        ],
        createdByMemberId: 'lead_user',
        createdAt: DateTime.now(),
        status: 'active',
      );

      expect(trip.isCreator('lead_user'), isTrue);
      expect(trip.isCreator('comp_user'), isFalse);
      expect(trip.isCreator('random_stranger'), isFalse);
      expect(trip.isCreator(null), isFalse);
      expect(trip.isCreator(''), isFalse);

      // Verify status serialization & isDeleted getter
      expect(trip.isDeleted, isFalse);
      final deletedTrip = trip.copyWith(status: 'deleted');
      expect(deletedTrip.isDeleted, isTrue);
      expect(deletedTrip.isRunning, isFalse);

      final json = deletedTrip.toJson();
      expect(json['status'], 'deleted');
      final fromJson = Trip.fromJson(json);
      expect(fromJson.status, 'deleted');
      expect(fromJson.isDeleted, isTrue);
    });

    test('Companion Leaving: Purges trip and associated records locally for departing companion', () async {
      final db = await AppDatabase.open(customPath: '${tempDir.path}/test_leave_trip.db');
      final storage = await LocalStorageService.init(prefs: prefs, database: db, initialUserId: 'comp_user');

      final sharedTrip = Trip(
        id: 'trip_group_101',
        title: 'Manali Expedition',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 3)),
        defaultCurrency: 'INR',
        tripType: 'group',
        members: [
          const TripMember(id: 'lead_1', name: 'Lead', isCurrentUser: false),
          const TripMember(id: 'comp_user', name: 'Companion', isCurrentUser: true),
        ],
        createdByMemberId: 'lead_1',
        createdAt: DateTime.now(),
      );

      final sharedExpense = Expense(
        id: 'exp_manali_1',
        tripId: 'trip_group_101',
        title: 'Resort Stay',
        totalAmount: 12000.0,
        currency: 'INR',
        category: 'stay',
        paidByMemberId: 'lead_1',
        splitType: SplitType.equal,
        splits: const [],
        createdAt: DateTime.now(),
      );

      await storage.saveTrip(sharedTrip);
      await storage.saveExpense(sharedExpense);

      expect(storage.getTrips().length, 1);
      expect(storage.getAllExpenses().length, 1);

      // Companion leaves the trip -> deleteTrip is called locally
      await storage.deleteTrip('trip_group_101');

      expect(storage.getTrips(), isEmpty);
      expect(storage.getAllExpenses(), isEmpty);
    });

    test('Two-Phase Invitations: Outgoing invitations are never returned to the creator as pending', () async {
      final db = await AppDatabase.open(customPath: '${tempDir.path}/test_invitations.db');
      final storage = await LocalStorageService.init(prefs: prefs, database: db, initialUserId: 'creator_uid');

      final outgoingInvitation = TripInvitation(
        id: 'inv_101',
        tripId: 'trip_ladakh',
        tripTitle: 'Ladakh Bike Expedition',
        inviterId: 'creator_uid',
        inviterName: 'Creator Arun',
        inviteeId: 'invitee_uid',
        inviteeUsername: 'savitri',
        inviteeEmail: 'savitri.devi838390@gmail.com',
        createdAt: DateTime.now(),
        status: InvitationStatus.pending,
      );

      await storage.saveInvitation(outgoingInvitation);

      // Creator's pending inbox MUST be empty (creator does NOT accept/decline own invitation)
      final creatorPending = storage.getPendingInvitations(
        currentUserId: 'creator_uid',
        currentUserEmail: 'arun@example.com',
        currentUsername: 'arun',
      );
      expect(creatorPending, isEmpty, reason: 'Creator should never see their own outgoing invitation in pending inbox');

      // Creator's sent invitations list contains it
      final creatorSent = storage.getSentInvitations(currentUserId: 'creator_uid');
      expect(creatorSent.length, 1);
      expect(creatorSent.first.id, 'inv_101');

      // Invitee matching by UID sees the invitation
      final inviteePendingByUid = storage.getPendingInvitations(
        currentUserId: 'invitee_uid',
      );
      expect(inviteePendingByUid.length, 1);
      expect(inviteePendingByUid.first.tripTitle, 'Ladakh Bike Expedition');

      // Invitee matching by Email sees the invitation
      final inviteePendingByEmail = storage.getPendingInvitations(
        currentUserEmail: 'savitri.devi838390@gmail.com',
      );
      expect(inviteePendingByEmail.length, 1);

      // Invitee matching by Username sees the invitation
      final inviteePendingByUsername = storage.getPendingInvitations(
        currentUsername: 'savitri',
      );
      expect(inviteePendingByUsername.length, 1);

      // Unrelated third-party user sees 0 pending invitations
      final strangerPending = storage.getPendingInvitations(
        currentUserId: 'stranger_uid',
        currentUserEmail: 'stranger@example.com',
        currentUsername: 'stranger',
      );
      expect(strangerPending, isEmpty);
    });

    test('Trip package import persists expenses and allows immediate expense calculation', () async {
      final db = await AppDatabase.open(customPath: '${tempDir.path}/test_import_package.db');
      final storage = await LocalStorageService.init(prefs: prefs, database: db, initialUserId: 'user_sync');

      final trip = Trip(
        id: 'trip_sync_1',
        title: 'Manali Snow Trek',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 3)),
        defaultCurrency: 'INR',
        tripType: 'group',
        members: [
          const TripMember(id: 'user_sync', name: 'Arun', isCurrentUser: true),
        ],
        createdByMemberId: 'user_sync',
        createdAt: DateTime.now(),
      );

      final exp1 = Expense(
        id: 'exp_sync_1',
        tripId: 'trip_sync_1',
        title: 'Snow Gear Rental',
        totalAmount: 1800.0,
        currency: 'INR',
        category: 'gear',
        paidByMemberId: 'user_sync',
        splitType: SplitType.equal,
        splits: const [],
        createdAt: DateTime.now(),
      );

      final exp2 = Expense(
        id: 'exp_sync_2',
        tripId: 'trip_sync_1',
        title: 'Cottage Stay',
        totalAmount: 4200.0,
        currency: 'INR',
        category: 'accommodation',
        paidByMemberId: 'user_sync',
        splitType: SplitType.equal,
        splits: const [],
        createdAt: DateTime.now(),
      );

      final pkg = TripPackage(
        trip: trip,
        stoppages: const [],
        expenses: [exp1, exp2],
        memories: const [],
        settlements: const [],
      );

      await storage.importTripPackage(pkg, activeMemberId: 'user_sync');

      final trips = storage.getTrips();
      expect(trips.length, 1);
      expect(trips.first.title, 'Manali Snow Trek');

      final expenses = storage.getAllExpenses();
      expect(expenses.length, 2);
      final totalAmount = expenses.fold(0.0, (sum, e) => sum + e.totalAmount);
      expect(totalAmount, 6000.0);
    });
  });
}

