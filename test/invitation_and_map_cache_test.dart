import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_tracker_app/core/database/app_database.dart';
import 'package:trip_tracker_app/core/services/local_storage_service.dart';
import 'package:trip_tracker_app/core/services/map_tile_cache_service.dart';
import 'package:trip_tracker_app/core/services/user_service.dart';
import 'package:trip_tracker_app/models/trip_invitation.dart';
import 'package:trip_tracker_app/models/user_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mobile Number & User Search Tests', () {
    test('UserService searches companions by formatted phone number and raw digits', () async {
      UserService.registerUser(const UserProfile(
        id: 'usr_mike_test',
        username: 'mike_trekker',
        displayName: 'Mike Chen',
        email: 'mike.chen@example.com',
        phone: '+1 (555) 345-6789',
      ));
      UserService.registerUser(const UserProfile(
        id: 'usr_alex_test',
        username: 'alex_explorer',
        displayName: 'Alex Morgan',
        email: 'alex.m@example.com',
        phone: '+1 (555) 567-8901',
      ));
      UserService.registerUser(const UserProfile(
        id: 'usr_elena_test',
        username: 'elena_hikes',
        displayName: 'Elena Rostova',
        email: 'elena.r@example.com',
      ));

      // Search by formatted phone
      final results1 = await UserService.searchUsers('+1 (555) 345-6789');
      expect(results1.isNotEmpty, isTrue);
      expect(results1.first.username, equals('mike_trekker'));

      // Search by raw digits
      final results2 = await UserService.searchUsers('5553456789');
      expect(results2.isNotEmpty, isTrue);
      expect(results2.first.displayName, equals('Mike Chen'));

      // Partial phone digits
      final results3 = await UserService.searchUsers('5678901');
      expect(results3.any((u) => u.username == 'alex_explorer'), isTrue);

      // Search by username handle still works
      final results4 = await UserService.searchUsers('@elena_hikes');
      expect(results4.any((u) => u.username == 'elena_hikes'), isTrue);
    });
  });

  group('TripInvitation Model & Storage Tests', () {
    late LocalStorageService storage;
    late AppDatabase appDb;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      appDb = await AppDatabase.open(customPath: inMemoryDatabasePath);
      storage = await LocalStorageService.init(prefs: prefs, database: appDb);
    });

    tearDown(() {
      appDb.database.close();
    });

    test('TripInvitation serializes and deserializes properly', () {
      final inv = TripInvitation(
        id: 'inv_test_1',
        tripId: 'trip_100',
        tripTitle: 'Goa Coastal Highway',
        inviterId: 'usr_me',
        inviterName: 'Arun',
        inviteeUsername: 'priya_wanderer',
        inviteePhone: '+91 98765 43210',
        createdAt: DateTime(2026, 9, 5, 10, 0),
        status: InvitationStatus.pending,
        tripJson: {'id': 'trip_100', 'title': 'Goa Coastal Highway'},
      );

      final json = inv.toJson();
      expect(json['id'], equals('inv_test_1'));
      expect(json['status'], equals('pending'));
      expect(json['inviteePhone'], equals('+91 98765 43210'));

      final revived = TripInvitation.fromJson(json);
      expect(revived.id, equals('inv_test_1'));
      expect(revived.tripTitle, equals('Goa Coastal Highway'));
      expect(revived.status, equals(InvitationStatus.pending));
      expect(revived.tripJson?['title'], equals('Goa Coastal Highway'));
    });

    test('LocalStorageService persists, queries pending, updates status, and deletes invitations', () async {
      expect(storage.getPendingInvitations().isEmpty, isTrue);

      final inv1 = TripInvitation(
        id: 'inv_1',
        tripId: 'trip_1',
        tripTitle: 'Himalayan Pass',
        inviterId: 'usr_1',
        inviterName: 'Alex',
        inviteeUsername: 'mike_trekker',
        createdAt: DateTime.now(),
        status: InvitationStatus.pending,
      );

      final inv2 = TripInvitation(
        id: 'inv_2',
        tripId: 'trip_2',
        tripTitle: 'Desert Safari',
        inviterId: 'usr_2',
        inviterName: 'Sarah',
        inviteeUsername: 'mike_trekker',
        createdAt: DateTime.now(),
        status: InvitationStatus.pending,
      );

      await storage.saveInvitation(inv1);
      await storage.saveInvitation(inv2);

      // Both should be pending
      final pending = storage.getPendingInvitations();
      expect(pending.length, equals(2));

      // Accept first invitation
      await storage.updateInvitationStatus('inv_1', InvitationStatus.accepted);
      final pendingAfterAccept = storage.getPendingInvitations();
      expect(pendingAfterAccept.length, equals(1));
      expect(pendingAfterAccept.first.id, equals('inv_2'));

      final all = storage.getAllInvitations();
      expect(all.firstWhere((i) => i.id == 'inv_1').status, equals(InvitationStatus.accepted));

      // Delete second invitation
      await storage.deleteInvitation('inv_2');
      expect(storage.getPendingInvitations().isEmpty, isTrue);
    });
  });

  group('MapTileCacheService Geometry & Tile Math Tests', () {
    test('Converts coordinates to OSM tile indices with mathematical precision', () {
      // Test at known origin (lat: 0, lon: 0, zoom: 0)
      final x0 = MapTileCacheService.lon2tile(0.0, 0);
      final y0 = MapTileCacheService.lat2tile(0.0, 0);
      expect(x0, equals(0));
      expect(y0, equals(0));

      // Test San Francisco (lat: 37.7749, lon: -122.4194) at zoom 12
      final xSF = MapTileCacheService.lon2tile(-122.4194, 12);
      final ySF = MapTileCacheService.lat2tile(37.7749, 12);
      expect(xSF, equals(655));
      expect(ySF, equals(1583));
    });

    test('calculateTileCoordinates computes bounding box tiles within max limits', () {
      final points = [
        const LatLng(37.7749, -122.4194),
        const LatLng(37.7849, -122.4094),
        const LatLng(37.7649, -122.4294),
      ];

      final tiles = MapTileCacheService.calculateTileCoordinates(
        points: points,
        zoomLevels: [12, 13],
        margin: 0.02,
        maxTiles: 100,
      );

      expect(tiles.isNotEmpty, isTrue);
      expect(tiles.length, lessThanOrEqualTo(100));

      // Ensures all computed zoom levels are in the requested set
      for (final t in tiles) {
        expect([12, 13].contains(t.z), isTrue);
      }
    });
  });
}
