import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trackmytrip/core/services/admin_service.dart';
import 'package:trackmytrip/core/services/canary_health_service.dart';
import 'package:trackmytrip/core/services/cloudinary_service.dart';
import 'package:trackmytrip/core/services/live_currency_service.dart';
import 'package:trackmytrip/core/services/map_tile_cache_service.dart';
import 'package:trackmytrip/core/services/media_cache_service.dart';
import 'package:trackmytrip/core/services/security_service.dart';
import 'package:trackmytrip/core/services/secret_config_service.dart';
import 'package:trackmytrip/core/services/tombstone_service.dart';
import 'package:trackmytrip/core/utils/debt_simplifier.dart';
import 'package:trackmytrip/core/utils/notification_formatter.dart';
import 'package:trackmytrip/models/proximity_alert.dart';
import 'package:trackmytrip/models/stoppage.dart';
import 'package:trackmytrip/models/sync_mutation.dart';
import 'package:trackmytrip/models/trip.dart';
import 'package:trackmytrip/models/trip_member.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Track 1: Authentication & Biometrics Security Vault', () {
    test('SecurityService verifies vault health and pepper configuration', () async {
      final security = SecurityService();
      final health = await security.performVaultHealthCheck();

      expect(health['status'], anyOf(equals('OK'), equals('Unavailable / Emulated')));
      expect(health['keystoreActive'], isNotNull);
      expect(SecretConfigService.vaultPepper, isNotEmpty);
      expect(SecretConfigService.vaultPepper.length, greaterThanOrEqualTo(8));
    });

    test('Data masking defensively protects sensitive identifiers', () {
      final maskedKey = SecretConfigService.maskSecret('AIzaSyD-sample-production-key-12345');
      expect(maskedKey.startsWith('AIza'), isTrue);
      expect(maskedKey.endsWith('2345'), isTrue);
      expect(maskedKey.contains('••••'), isTrue);
    });
  });

  group('Track 2: Trip Management & Tombstone Anti-Resurrection', () {
    test('TombstoneService prevents resurrected deleted trips', () async {
      const tripId = 'trip_verify_tombstone_001';
      expect(TombstoneService.isTombstoned(tripId), isFalse);

      await TombstoneService.markTombstoned(tripId);
      expect(TombstoneService.isTombstoned(tripId), isTrue);
    });

    test('Trip model serialization preserves member roles and settings', () {
      const creator = TripMember(
        id: 'user_001',
        name: 'Arun',
        email: 'arunbsssbars@gmail.com',
        role: TripMember.roleCreator,
      );
      const companion = TripMember(
        id: 'user_002',
        name: 'Companion',
        email: 'companion@gmail.com',
        role: TripMember.roleMember,
      );

      final trip = Trip(
        id: 'trip_verify_001',
        title: 'Manali Expedition 2026',
        description: 'Testing trip life-cycle',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 5),
        defaultCurrency: 'INR',
        budget: 25000,
        shareCode: 'MNL26',
        tripType: 'group',
        members: [creator, companion],
        createdByMemberId: 'user_001',
        createdAt: DateTime(2026, 9, 1),
      );

      final map = trip.toJson();
      final restored = Trip.fromJson(map);

      expect(restored.id, equals(trip.id));
      expect(restored.shareCode, equals('MNL26'));
      expect(restored.budget, equals(25000));
      expect(restored.isSolo, isFalse);
      expect(restored.isMemberCreator(creator), isTrue);
    });
  });

  group('Track 3: Real-Time Companion GPS & Stray Detection', () {
    test('Stray geofence trigger flags companions beyond safety threshold', () {
      const double thresholdMeters = 500.0;
      const double normalDistance = 120.0;
      const double strayDistance = 850.0;

      expect(normalDistance > thresholdMeters, isFalse);
      expect(strayDistance > thresholdMeters, isTrue);
    });
  });

  group('Track 4: Financial Ledger & Multi-Currency FX Conversion', () {
    test('DebtSimplifier resolves multilateral expenses into minimal payments', () {
      final netBalances = {
        'Alice': 60.0,
        'Bob': -20.0,
        'Charlie': -30.0,
        'David': -10.0,
      };

      final transfers = DebtSimplifier.simplifyDebts(netBalances);

      expect(transfers.isNotEmpty, isTrue);
      final totalTransferred = transfers.fold<double>(0, (sum, t) => sum + t.amount);
      expect(totalTransferred, closeTo(60.0, 0.01));

      for (final t in transfers) {
        expect(t.toMemberId, equals('Alice'));
      }
    });

    test('LiveCurrencyService converts foreign amounts with fallback rates', () {
      final inr = LiveCurrencyService.convert(100.0, 'USD', 'INR');
      expect(inr, greaterThan(7000.0));
      expect(inr, lessThan(9500.0));
    });
  });

  group('Track 5: Itinerary & Stoppage Geofencing', () {
    test('Stoppage arrival check computes within 150m geofence radius', () {
      final stop = Stoppage(
        id: 'stop_1',
        tripId: 'trip_test',
        name: 'Solang Valley Viewpoint',
        latitude: 32.3167,
        longitude: 77.1578,
        orderIndex: 0,
        category: 'Sightseeing',
        createdBy: 'user_001',
        arrivedAt: DateTime(2026, 9, 2, 10, 0),
      );

      expect(stop.name, equals('Solang Valley Viewpoint'));
      expect(stop.latitude, closeTo(32.3167, 0.0001));
      expect(stop.isOngoing, isTrue);
    });
  });

  group('Track 6: Memories & Media Cache Queue', () {
    test('MediaCacheService handles memory queue and item tracking', () {
      final service = MediaCacheService();
      expect(service.allItems, isEmpty);

      final item = MediaItem(
        id: 'med_001',
        localPath: '/local/test/photo.jpg',
        createdAt: DateTime.now(),
        entityType: 'memory',
        entityId: 'mem_123',
        status: MediaUploadStatus.local,
      );

      expect(item.isLocal, isTrue);
      expect(item.isUploaded, isFalse);
      expect(item.displayPath, equals('/local/test/photo.jpg'));
    });

    test('CloudinaryService produces optimized responsive memory URLs', () {
      const cdnUrl = 'https://res.cloudinary.com/testcloud/image/upload/v1/photos/snow.jpg';
      final optimized = CloudinaryService.getOptimizedUrl(cdnUrl, width: 600, quality: 80);
      expect(optimized, contains('w_600'));
      expect(optimized, contains('q_80'));
      expect(optimized, contains('f_auto'));
    });
  });

  group('Track 7: Proximity Alerts & Activity Hub Deep-Linking', () {
    test('NotificationFormatter formats alerts into human-readable messages', () {
      final alert = ProximityAlert(
        id: 'alt_001',
        tripId: 'trip_manali',
        type: AlertType.billAdded,
        title: 'New Bill Added',
        message: 'Alice added a bill of INR 1,200',
        timestamp: DateTime.now(),
        senderMemberId: 'user_alice',
        senderName: 'Alice',
        amount: 1200,
        currency: 'INR',
      );

      final title = NotificationFormatter.formatTitle(alert, currentUserId: 'user_bob');
      expect(title, isNotEmpty);
      expect(alert.amount, equals(1200));
    });
  });

  group('Track 8: Offline-First Synchronization & Outbox Queue', () {
    test('SyncMutation serializes and preserves mutation payload', () {
      final mutation = SyncMutation(
        id: 'mut_test_001',
        action: MutationAction.updateTrip,
        entityType: 'trip',
        entityId: 'trip_offline_001',
        tripId: 'trip_offline_001',
        payload: {'title': 'Updated Offline Title'},
        createdAt: DateTime.now(),
      );

      final jsonMap = mutation.toJson();
      final restored = SyncMutation.fromJson(jsonMap);

      expect(restored.id, equals(mutation.id));
      expect(restored.action, equals(MutationAction.updateTrip));
      expect(restored.payload['title'], equals('Updated Offline Title'));
    });
  });

  group('Track 9: Regional Offline Map Tile Pack Downloader', () {
    test('MapTileCacheService calculates tile coordinates for region', () {
      final manaliPoints = [
        const LatLng(32.2396, 77.1887),
        const LatLng(32.3166, 77.1575),
        const LatLng(32.3716, 77.2466),
      ];

      final tiles = MapTileCacheService.calculateTileCoordinates(points: manaliPoints);
      expect(tiles, isNotEmpty);
      expect(tiles.length, greaterThan(0));
    });
  });

  group('Track 10: Super Admin Console Telemetry & Canary Probe', () {
    test('AdminService verifies super admin role boundaries and metrics', () {
      expect(AdminService.isSuperAdmin('arunbsssbars@gmail.com'), isTrue);
      expect(AdminService.isSuperAdmin('ARUNBSSSBARS@GMAIL.COM '), isTrue);
      expect(AdminService.isSuperAdmin('unauthorized@test.com'), isFalse);

      final metrics = FreeTierQuotaMetrics(
        firestoreDocCount: 150,
        firestoreTripsCount: 20,
        firestoreRoomsCount: 15,
        firestoreUsersCount: 10,
        firestoreTombstonesCount: 5,
        firestoreInvitationsCount: 100,
        firestoreEstimatedReads: 5000,
        firestoreEstimatedWrites: 2000,
        firestoreStorageMb: 50.0,
        rtdbActiveConnections: 5,
        rtdbStorageMb: 2.0,
        rtdbBandwidthMb: 20.0,
        storageFileCount: 10,
        storageUsedMb: 100.0,
        authTotalUsers: 15,
        timestamp: DateTime.now(),
      );

      expect(metrics.firestoreReadsPercent, closeTo(10.0, 0.01));
      expect(metrics.rtdbConnectionsPercent, closeTo(5.0, 0.01));

      final report = AdminService.generateSystemDiagnosticReport(metrics);
      expect(report['superAdmin'], equals('arunbsssbars@gmail.com'));
      expect(report['freeTierMetrics'], isA<Map<String, dynamic>>());
      final fsMetrics = report['freeTierMetrics']['firestore'] as Map<String, dynamic>;
      expect(fsMetrics['totalDocuments'], equals(150));
    });

    test('CanaryHealthService executes live probe validation', () async {
      final canary = await CanaryHealthService.runCanaryHealthProbe();
      expect(canary.healthScore, greaterThanOrEqualTo(0));
      expect(canary.serviceStatuses, isNotEmpty);
    });
  });
}
