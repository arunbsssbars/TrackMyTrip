import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trip_tracker_app/core/database/app_database.dart';
import 'package:trip_tracker_app/core/services/local_storage_service.dart';
import 'package:trip_tracker_app/models/trip.dart';
import 'package:trip_tracker_app/models/trip_member.dart';
import 'package:trip_tracker_app/models/stoppage.dart';
import 'package:trip_tracker_app/models/expense.dart';
import 'package:trip_tracker_app/models/expense_split.dart';
import 'package:trip_tracker_app/models/settlement.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late AppDatabase appDb;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    appDb = await AppDatabase.open(customDb: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SQLite Database Core CRUD & Index Tests', () {
    test('Trips CRUD operations write and read correctly from SQLite', () async {
      const member = TripMember(id: 'm1', name: 'John Doe', isCurrentUser: true);
      final trip = Trip(
        id: 'trip_100',
        title: 'Alpine Route',
        description: 'Through the Swiss Alps',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 10),
        defaultCurrency: 'CHF',
        budget: 2500.0,
        members: [member],
        createdByMemberId: 'm1',
        createdAt: DateTime(2026, 8, 15),
      );

      await appDb.saveTrip(trip);
      final trips = await appDb.getTrips();

      expect(trips.length, equals(1));
      expect(trips.first.id, equals('trip_100'));
      expect(trips.first.title, equals('Alpine Route'));
      expect(trips.first.budget, equals(2500.0));
      expect(trips.first.members.length, equals(1));
      expect(trips.first.members.first.name, equals('John Doe'));
    });

    test('Stoppages CRUD and indexed query by tripId work with transaction isolation', () async {
      final stop1 = Stoppage(
        id: 'stop_1',
        tripId: 'trip_100',
        name: 'Interlaken Cafe',
        latitude: 46.6863,
        longitude: 7.8632,
        category: 'Food & Cafe',
        arrivedAt: DateTime(2026, 9, 2, 10, 0),
        departedAt: DateTime(2026, 9, 2, 11, 0),
        createdBy: 'm1',
        orderIndex: 0,
      );
      final stop2 = Stoppage(
        id: 'stop_2',
        tripId: 'trip_100',
        name: 'Jungfraujoch Peak',
        latitude: 46.5475,
        longitude: 7.9854,
        category: 'Viewpoint',
        arrivedAt: DateTime(2026, 9, 2, 13, 0),
        departedAt: null,
        createdBy: 'm1',
        orderIndex: 1,
      );

      await appDb.saveAllStoppages([stop1, stop2]);

      final tripStops = await appDb.getStoppages('trip_100');
      expect(tripStops.length, equals(2));
      expect(tripStops[0].name, equals('Interlaken Cafe'));
      expect(tripStops[1].name, equals('Jungfraujoch Peak'));
      expect(tripStops[1].isOngoing, isTrue);

      await appDb.deleteStoppage('stop_1');
      final remaining = await appDb.getStoppages('trip_100');
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals('stop_2'));
    });

    test('Expenses and Settlements with Split JSON mapping persist accurately', () async {
      final expense = Expense(
        id: 'exp_1',
        tripId: 'trip_100',
        stoppageId: 'stop_2',
        title: 'Cable Car Tickets',
        totalAmount: 180.0,
        currency: 'CHF',
        category: 'Activities & Tickets',
        paidByMemberId: 'm1',
        splitType: SplitType.equal,
        splits: [
          const ExpenseSplit(memberId: 'm1', allocatedAmount: 90.0),
          const ExpenseSplit(memberId: 'm2', allocatedAmount: 90.0),
        ],
        createdAt: DateTime(2026, 9, 2, 12, 30),
      );

      await appDb.saveExpense(expense);
      final expenses = await appDb.getExpenses('trip_100');

      expect(expenses.length, equals(1));
      expect(expenses.first.totalAmount, equals(180.0));
      expect(expenses.first.splits.length, equals(2));
      expect(expenses.first.splits.last.memberId, equals('m2'));

      final settlement = Settlement(
        id: 'set_1',
        tripId: 'trip_100',
        payerMemberId: 'm2',
        receiverMemberId: 'm1',
        amount: 90.0,
        currency: 'CHF',
        settledAt: DateTime(2026, 9, 2, 18, 0),
        paymentMethod: 'UPI / Cash',
      );

      await appDb.saveSettlement(settlement);
      final settlements = await appDb.getSettlements('trip_100');

      expect(settlements.length, equals(1));
      expect(settlements.first.amount, equals(90.0));
      expect(settlements.first.payerMemberId, equals('m2'));
    });

    test('Cascading trip deletion atomically clears all related entities', () async {
      const member = TripMember(id: 'm1', name: 'John', isCurrentUser: true);
      final trip = Trip(
        id: 'trip_to_delete',
        title: 'Temp Trip',
        startDate: DateTime.now(),
        endDate: DateTime.now(),
        defaultCurrency: 'USD',
        members: [member],
        createdByMemberId: 'm1',
        createdAt: DateTime.now(),
      );
      final stop = Stoppage(
        id: 'temp_stop',
        tripId: 'trip_to_delete',
        name: 'Pitstop',
        latitude: 10.0,
        longitude: 20.0,
        category: 'Food',
        arrivedAt: DateTime.now(),
        createdBy: 'm1',
      );

      await appDb.saveTrip(trip);
      await appDb.saveStoppage(stop);

      expect((await appDb.getTrips()).length, equals(1));
      expect((await appDb.getStoppages('trip_to_delete')).length, equals(1));

      await appDb.deleteTrip('trip_to_delete');

      expect((await appDb.getTrips()).length, equals(0));
      expect((await appDb.getStoppages('trip_to_delete')).length, equals(0));
    });
  });

  group('LocalStorageService SQLite Hybrid & Migration Tests', () {
    test('Seamlessly migrates legacy SharedPreferences JSON blobs to SQLite with zero data loss', () async {
      final legacyTrips = jsonEncode([
        {
          'id': 'legacy_trip_99',
          'title': 'Historic Rome Tour',
          'startDate': '2026-05-01T00:00:00.000',
          'endDate': '2026-05-05T00:00:00.000',
          'defaultCurrency': 'EUR',
          'tripType': 'group',
          'members': [
            {'id': 'm_rome', 'name': 'Arun', 'isCurrentUser': true}
          ],
          'createdByMemberId': 'm_rome',
          'createdAt': '2026-04-01T00:00:00.000',
          'isCompleted': false,
        }
      ]);
      final legacyStops = jsonEncode([
        {
          'id': 'stop_colosseum',
          'tripId': 'legacy_trip_99',
          'name': 'Colosseum Piazza',
          'latitude': 41.8902,
          'longitude': 12.4922,
          'category': 'Sightseeing',
          'arrivedAt': '2026-05-02T09:30:00.000',
          'createdBy': 'm_rome',
          'orderIndex': 0,
        }
      ]);

      await prefs.setString('trips_data_v1', legacyTrips);
      await prefs.setString('stoppages_data_v1', legacyStops);
      await prefs.setBool('app_seeded_v1', true);

      final storage = await LocalStorageService.init(database: appDb, prefs: prefs);

      expect(storage.getTrips().length, equals(1));
      expect(storage.getTrips().first.id, equals('legacy_trip_99'));
      expect(storage.getTrips().first.title, equals('Historic Rome Tour'));
      expect(storage.getStoppages('legacy_trip_99').length, equals(1));
      expect(storage.getStoppages('legacy_trip_99').first.name, equals('Colosseum Piazza'));

      final sqliteTrips = await appDb.getTrips();
      final sqliteStops = await appDb.getStoppages('legacy_trip_99');

      expect(sqliteTrips.length, equals(1));
      expect(sqliteTrips.first.title, equals('Historic Rome Tour'));
      expect(sqliteStops.length, equals(1));
      expect(sqliteStops.first.name, equals('Colosseum Piazza'));

      expect(prefs.getBool('sqlite_migrated_v1'), isTrue);
    });
  });
}