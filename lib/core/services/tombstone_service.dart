import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';

/// Senior-developer persistent tombstone service.
/// Prevents deleted trips from ever being resurrected from SQLite,
/// SharedPreferences, or incoming Cloud Firestore snapshot streams.
class TombstoneService {
  static final Set<String> _tombstonedTripIds = {};
  static SharedPreferences? _prefs;
  static AppDatabase? _db;
  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static const String _prefsKey = 'tombstoned_trip_ids_v1';

  /// Initializes the tombstone memory cache from SharedPreferences and SQLite
  static Future<void> init(SharedPreferences prefs, AppDatabase db) async {
    _prefs = prefs;
    _db = db;

    try {
      // 1. Load from SharedPreferences for instant cold-start protection
      final prefsList = _prefs?.getStringList(_prefsKey) ?? [];
      _tombstonedTripIds.addAll(prefsList);

      // 2. Load from SQLite database and merge
      final dbList = await _db?.getTombstonedTripIds() ?? {};
      _tombstonedTripIds.addAll(dbList);

      // 3. Keep SharedPreferences synced with any database-discovered tombstones
      if (_tombstonedTripIds.length > prefsList.length) {
        await _prefs?.setStringList(_prefsKey, _tombstonedTripIds.toList());
      }

      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('[TombstoneService] Initialized with ${_tombstonedTripIds.length} tombstoned trip(s).');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TombstoneService] Init error: $e');
      }
    }
  }

  /// Instant synchronous O(1) check if a trip is tombstoned
  static bool isTombstoned(String tripId) {
    if (tripId.trim().isEmpty) return false;
    return _tombstonedTripIds.contains(tripId.trim());
  }

  /// Permanently tombstones a trip across memory, SharedPreferences, and SQLite
  static Future<void> markTombstoned(String tripId) async {
    if (tripId.trim().isEmpty) return;
    final cleanId = tripId.trim();

    _tombstonedTripIds.add(cleanId);

    try {
      // Dual-layer persistence
      await _prefs?.setStringList(_prefsKey, _tombstonedTripIds.toList());
      await _db?.addTombstonedTrip(cleanId);

      if (kDebugMode) {
        debugPrint('[TombstoneService] Permanently tombstoned trip: $cleanId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TombstoneService] Error persisting tombstone: $e');
      }
    }
  }

  /// Reloads tombstones when switching SQLite database files
  static Future<void> reload(AppDatabase db) async {
    _db = db;
    try {
      final dbList = await _db?.getTombstonedTripIds() ?? {};
      _tombstonedTripIds.addAll(dbList);
      await _prefs?.setStringList(_prefsKey, _tombstonedTripIds.toList());
    } catch (_) {}
  }

  /// Wipes the entire tombstone state from memory AND SharedPreferences.
  ///
  /// Must be called during account deletion / full local data wipe so that the
  /// next user who logs in on this device does not inherit stale tombstones from
  /// the previous session (which would cause legitimate trips to appear deleted
  /// and then vanish on first click — the "ghost deletion" bug).
  static Future<void> wipeAll() async {
    _tombstonedTripIds.clear();
    try {
      await _prefs?.remove(_prefsKey);
    } catch (_) {}
    if (kDebugMode) {
      debugPrint('[TombstoneService] Full tombstone wipe executed (account deletion).');
    }
  }

  /// Returns an immutable set of all tombstoned trip IDs
  static Set<String> getAllTombstonedTripIds() => Set.unmodifiable(_tombstonedTripIds);
}

final tombstoneServiceProvider = Provider<TombstoneService>((ref) => TombstoneService());
