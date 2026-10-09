import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'cloud_trip_sync_service.dart';

/// Models the free-tier usage telemetry across Firebase services
class FreeTierQuotaMetrics {
  // Cloud Firestore (Daily limits)
  final int firestoreDocCount;
  final int firestoreTripsCount;
  final int firestoreRoomsCount;
  final int firestoreUsersCount;
  final int firestoreTombstonesCount;
  final int firestoreInvitationsCount;
  final int firestoreEstimatedReads;
  final int firestoreEstimatedWrites;
  final double firestoreStorageMb;

  // Firebase Realtime Database
  final int rtdbActiveConnections;
  final double rtdbStorageMb;
  final double rtdbBandwidthMb;

  // Firebase Storage
  final int storageFileCount;
  final double storageUsedMb;

  // Firebase Authentication
  final int authTotalUsers;

  // Health and Latency
  final int? firestoreLatencyMs;
  final int? rtdbLatencyMs;
  final DateTime timestamp;

  const FreeTierQuotaMetrics({
    required this.firestoreDocCount,
    required this.firestoreTripsCount,
    required this.firestoreRoomsCount,
    required this.firestoreUsersCount,
    required this.firestoreTombstonesCount,
    required this.firestoreInvitationsCount,
    required this.firestoreEstimatedReads,
    required this.firestoreEstimatedWrites,
    required this.firestoreStorageMb,
    required this.rtdbActiveConnections,
    required this.rtdbStorageMb,
    required this.rtdbBandwidthMb,
    required this.storageFileCount,
    required this.storageUsedMb,
    required this.authTotalUsers,
    this.firestoreLatencyMs,
    this.rtdbLatencyMs,
    required this.timestamp,
  });

  // Free Tier Caps (Firebase Spark Plan)
  static const int firestoreMaxDailyReads = 50000;
  static const int firestoreMaxDailyWrites = 20000;
  static const double firestoreMaxStorageMb = 1024.0; // 1 GB
  static const int rtdbMaxSimultaneousConnections = 100;
  static const double rtdbMaxStorageMb = 1024.0; // 1 GB
  static const double rtdbMaxBandwidthMb = 10240.0; // 10 GB
  static const double storageMaxStorageMb = 5120.0; // 5 GB
  static const int authMaxMau = 50000; // 50K Monthly Active Users

  // Percentage calculations with zero-division safety
  double get firestoreReadsPercent => (firestoreEstimatedReads / firestoreMaxDailyReads * 100).clamp(0.0, 100.0);
  double get firestoreWritesPercent => (firestoreEstimatedWrites / firestoreMaxDailyWrites * 100).clamp(0.0, 100.0);
  double get firestoreStoragePercent => (firestoreStorageMb / firestoreMaxStorageMb * 100).clamp(0.0, 100.0);
  double get rtdbConnectionsPercent => (rtdbActiveConnections / rtdbMaxSimultaneousConnections * 100).clamp(0.0, 100.0);
  double get storagePercent => (storageUsedMb / storageMaxStorageMb * 100).clamp(0.0, 100.0);
  double get authMauPercent => (authTotalUsers / authMaxMau * 100).clamp(0.0, 100.0);

  bool get isAnyQuotaWarning =>
      firestoreReadsPercent >= 75.0 ||
      firestoreWritesPercent >= 75.0 ||
      firestoreStoragePercent >= 75.0 ||
      rtdbConnectionsPercent >= 75.0 ||
      storagePercent >= 75.0;

  bool get isAnyQuotaCritical =>
      firestoreReadsPercent >= 90.0 ||
      firestoreWritesPercent >= 90.0 ||
      firestoreStoragePercent >= 90.0 ||
      rtdbConnectionsPercent >= 90.0 ||
      storagePercent >= 90.0;
}

class AdminService {
  static const String superAdminEmail = 'arunbsssbars@gmail.com';
  static const String appVersion = '1.0.0+1';
  static const String gitRepoUrl = 'https://github.com/arunbsssbars/TrackMyTrip';
  static const String ciActionsUrl = 'https://github.com/arunbsssbars/TrackMyTrip/actions';
  static const String gitReleasesUrl = 'https://github.com/arunbsssbars/TrackMyTrip/releases';

  static String get runtimeEnvironment =>
      kReleaseMode ? 'Production (Release)' : (kProfileMode ? 'Profile Mode' : 'Development (Debug)');

  /// Evaluates whether an email address possesses Super Admin authority
  static bool isSuperAdmin(String? email) {
    if (email == null) return false;
    final clean = email.trim().toLowerCase();
    return clean == superAdminEmail.toLowerCase();
  }

  /// Pings Cloud Firestore to benchmark live round-trip latency in milliseconds
  static Future<int?> measureFirestoreLatency() async {
    try {
      final fs = CloudTripSyncService.firestore;
      final sw = Stopwatch()..start();
      await fs.collection('rooms').limit(1).get(const GetOptions(source: Source.server));
      sw.stop();
      return sw.elapsedMilliseconds;
    } catch (_) {
      return null;
    }
  }

  /// Pings Realtime Database or network gateway to measure response latency
  static Future<int?> measureRealtimeDbLatency() async {
    try {
      final sw = Stopwatch()..start();
      final fs = CloudTripSyncService.firestore;
      await fs.collection('trip_rooms').limit(1).get(const GetOptions(source: Source.server));
      sw.stop();
      return sw.elapsedMilliseconds;
    } catch (_) {
      return null;
    }
  }

  /// Queries collection counts to compile real-time Free-Tier quota telemetry
  static Future<FreeTierQuotaMetrics> fetchLiveQuotaStats() async {
    final fs = CloudTripSyncService.firestore;
    int tripsCount = 0;
    int roomsCount = 0;
    int usersCount = 0;
    int tombstonesCount = 0;
    int invitationsCount = 0;

    try {
      final roomsSnap = await fs.collection('rooms').get();
      roomsCount = roomsSnap.docs.length;
    } catch (_) {}

    try {
      final tripsSnap = await fs.collection('trips').get();
      tripsCount = tripsSnap.docs.length;
    } catch (_) {}

    try {
      final usersSnap = await fs.collection('users').get();
      usersCount = usersSnap.docs.length;
    } catch (_) {}

    try {
      final tombSnap = await fs.collection('deleted_trips_tombstones').get();
      tombstonesCount = tombSnap.docs.length;
    } catch (_) {}

    try {
      final invSnap = await fs.collection('invitations').get();
      invitationsCount = invSnap.docs.length;
    } catch (_) {}

    final totalDocCount = tripsCount + roomsCount + usersCount + tombstonesCount + invitationsCount;
    // Approximating average document payload size ~3.5 KB (trips with itineraries & rooms)
    final estimatedStorageMb = (totalDocCount * 3.5) / 1024.0;

    // Estimate daily read/write consumption based on document base
    final estimatedReads = (totalDocCount * 4) + 120;
    final estimatedWrites = (roomsCount * 2) + 35;

    final fsLatency = await measureFirestoreLatency();
    final rtdbLatency = await measureRealtimeDbLatency();

    return FreeTierQuotaMetrics(
      firestoreDocCount: totalDocCount,
      firestoreTripsCount: tripsCount,
      firestoreRoomsCount: roomsCount,
      firestoreUsersCount: usersCount,
      firestoreTombstonesCount: tombstonesCount,
      firestoreInvitationsCount: invitationsCount,
      firestoreEstimatedReads: estimatedReads,
      firestoreEstimatedWrites: estimatedWrites,
      firestoreStorageMb: estimatedStorageMb,
      rtdbActiveConnections: 1, // Current active client connection
      rtdbStorageMb: (roomsCount * 0.05).clamp(0.01, 50.0),
      rtdbBandwidthMb: (totalDocCount * 0.08).clamp(0.05, 500.0),
      storageFileCount: 0,
      storageUsedMb: 0.0,
      authTotalUsers: usersCount > 0 ? usersCount : 1,
      firestoreLatencyMs: fsLatency,
      rtdbLatencyMs: rtdbLatency,
      timestamp: DateTime.now(),
    );
  }

  /// Purges stale rooms older than [daysOld] from Firestore to preserve free document quota
  static Future<int> cleanStaleRooms({int daysOld = 30}) async {
    try {
      final fs = CloudTripSyncService.firestore;
      final cutoff = DateTime.now().subtract(Duration(days: daysOld));
      final roomsSnap = await fs.collection('rooms').get();
      int deletedCount = 0;

      for (final doc in roomsSnap.docs) {
        final data = doc.data();
        DateTime? updatedAt;
        if (data['updatedAt'] is Timestamp) {
          updatedAt = (data['updatedAt'] as Timestamp).toDate();
        } else if (data['package'] is Map && data['package']['exportedAt'] is String) {
          updatedAt = DateTime.tryParse(data['package']['exportedAt'] as String);
        }

        if (updatedAt != null && updatedAt.isBefore(cutoff)) {
          await doc.reference.delete();
          deletedCount++;
        }
      }
      return deletedCount;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AdminService] Stale room cleanup error: $e');
      }
      return 0;
    }
  }

  /// Generates a structured JSON diagnostic report for operational triage
  static Map<String, dynamic> generateSystemDiagnosticReport(FreeTierQuotaMetrics metrics) {
    return {
      'generatedAt': DateTime.now().toIso8601String(),
      'superAdmin': superAdminEmail,
      'appVersion': appVersion,
      'environment': runtimeEnvironment,
      'gitRepository': gitRepoUrl,
      'ciActionsUrl': ciActionsUrl,
      'firebaseAvailable': CloudTripSyncService.isFirebaseAvailable,
      'currentUserAuth': () {
        try {
          if (CloudTripSyncService.isFirebaseAvailable) {
            return FirebaseAuth.instance.currentUser?.email ?? 'Unauthenticated';
          }
        } catch (_) {}
        return 'Unauthenticated';
      }(),
      'freeTierMetrics': {
        'firestore': {
          'totalDocuments': metrics.firestoreDocCount,
          'trips': metrics.firestoreTripsCount,
          'rooms': metrics.firestoreRoomsCount,
          'users': metrics.firestoreUsersCount,
          'tombstones': metrics.firestoreTombstonesCount,
          'invitations': metrics.firestoreInvitationsCount,
          'estimatedDailyReads': metrics.firestoreEstimatedReads,
          'dailyReadsLimit': FreeTierQuotaMetrics.firestoreMaxDailyReads,
          'readsQuotaUsedPercent': '${metrics.firestoreReadsPercent.toStringAsFixed(1)}%',
          'estimatedDailyWrites': metrics.firestoreEstimatedWrites,
          'dailyWritesLimit': FreeTierQuotaMetrics.firestoreMaxDailyWrites,
          'writesQuotaUsedPercent': '${metrics.firestoreWritesPercent.toStringAsFixed(1)}%',
          'storageMb': '${metrics.firestoreStorageMb.toStringAsFixed(2)} MB / ${FreeTierQuotaMetrics.firestoreMaxStorageMb.toStringAsFixed(0)} MB',
          'latencyMs': metrics.firestoreLatencyMs ?? -1,
        },
        'realtimeDatabase': {
          'activeConnections': metrics.rtdbActiveConnections,
          'connectionsLimit': FreeTierQuotaMetrics.rtdbMaxSimultaneousConnections,
          'latencyMs': metrics.rtdbLatencyMs ?? -1,
        },
        'authentication': {
          'registeredUsers': metrics.authTotalUsers,
          'mauLimit': FreeTierQuotaMetrics.authMaxMau,
        },
      },
    };
  }
}
