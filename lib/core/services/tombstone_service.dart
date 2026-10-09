import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';

/// Senior-developer persistent tombstone service.
/// Prevents deleted trips from ever being resurrected from SQLite,
/// SharedPreferences, or incoming Cloud Firestore snapshot streams.
class TombstoneService {
  static final Set<String> _tombstonedTripIds = {};
  static final Set<String> _tombstonedMemoryIds = {};
  static SharedPreferences? _prefs;
  static AppDatabase? _db;
  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static const String _prefsKey = 'tombstoned_trip_ids_v1';
  static const String _memoryPrefsKey = 'tombstoned_memory_ids_v1';

  /// Initializes the tombstone memory cache from SharedPreferences and SQLite
  static Future<void> init(SharedPreferences prefs, AppDatabase db) async {
    _prefs = prefs;
    _db = db;

    try {
      // 1. Load from SharedPreferences for instant cold-start protection
      final prefsList = _prefs?.getStringList(_prefsKey) ?? [];
      _tombstonedTripIds.addAll(prefsList);

      final memoryPrefsList = _prefs?.getStringList(_memoryPrefsKey) ?? [];
      _tombstonedMemoryIds.addAll(memoryPrefsList);

      // 2. Load from SQLite database and merge
      final dbList = await _db?.getTombstonedTripIds() ?? {};
      _tombstonedTripIds.addAll(dbList);

      final dbMemList = await _db?.getTombstonedMemoryIds() ?? {};
      _tombstonedMemoryIds.addAll(dbMemList);

      // 3. Compact malformed entries, then keep SharedPreferences synced
      final removed = compact(_tombstonedTripIds);
      if (removed > 0 || _tombstonedTripIds.length != prefsList.length) {
        await _prefs?.setStringList(_prefsKey, _tombstonedTripIds.toList());
      }

      final removedMem = compact(_tombstonedMemoryIds);
      if (removedMem > 0 || _tombstonedMemoryIds.length != memoryPrefsList.length) {
        await _prefs?.setStringList(_memoryPrefsKey, _tombstonedMemoryIds.toList());
      }

      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('[TombstoneService] Initialized with ${_tombstonedTripIds.length} tombstoned trip(s) and ${_tombstonedMemoryIds.length} tombstoned memory(ies).');
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

  /// Instant synchronous O(1) check if a memory is tombstoned
  static bool isMemoryTombstoned(String memoryId) {
    if (memoryId.trim().isEmpty) return false;
    return _tombstonedMemoryIds.contains(memoryId.trim());
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

  /// Permanently tombstones a memory across memory, SharedPreferences, and SQLite
  static Future<void> markMemoryTombstoned(String memoryId, {String? tripId}) async {
    if (memoryId.trim().isEmpty) return;
    final cleanId = memoryId.trim();

    _tombstonedMemoryIds.add(cleanId);

    try {
      // Dual-layer persistence
      await _prefs?.setStringList(_memoryPrefsKey, _tombstonedMemoryIds.toList());
      await _db?.addTombstonedMemory(cleanId, tripId: tripId);

      if (kDebugMode) {
        debugPrint('[TombstoneService] Permanently tombstoned memory: $cleanId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TombstoneService] Error persisting memory tombstone: $e');
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

      final dbMemList = await _db?.getTombstonedMemoryIds() ?? {};
      _tombstonedMemoryIds.addAll(dbMemList);
      await _prefs?.setStringList(_memoryPrefsKey, _tombstonedMemoryIds.toList());
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
    _tombstonedMemoryIds.clear();
    try {
      await _prefs?.remove(_prefsKey);
      await _prefs?.remove(_memoryPrefsKey);
    } catch (_) {}
    if (kDebugMode) {
      debugPrint('[TombstoneService] Full tombstone wipe executed (account deletion).');
    }
  }

  /// Returns an immutable set of all tombstoned trip IDs
  static Set<String> getAllTombstonedTripIds() => Set.unmodifiable(_tombstonedTripIds);

  /// Returns an immutable set of all tombstoned memory IDs
  static Set<String> getAllTombstonedMemoryIds() => Set.unmodifiable(_tombstonedMemoryIds);

  /// Removes a trip tombstone if explicitly requested (e.g. undo delete or recreation)
  static Future<void> removeTripTombstone(String tripId) async {
    final cleanId = tripId.trim();
    if (cleanId.isEmpty) return;
    _tombstonedTripIds.remove(cleanId);
    try {
      await _prefs?.setStringList(_prefsKey, _tombstonedTripIds.toList());
      await _db?.removeTombstonedTrip(cleanId);
    } catch (_) {}
  }

  /// Normalises a tombstone set in place: trims whitespace and drops blank or
  /// placeholder entries ("null", "undefined"). Returns the number of entries removed.
  ///
  /// Valid tombstones are never expired — removing them could allow a stale
  /// cloud snapshot to resurrect a deleted trip.
  @visibleForTesting
  static int compact(Set<String> ids) {
    final before = ids.length;
    final normalised = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && id.toLowerCase() != 'null' && id.toLowerCase() != 'undefined')
        .toSet();
    ids
      ..clear()
      ..addAll(normalised);
    return before - ids.length;
  }
}

final tombstoneServiceProvider = Provider<TombstoneService>((ref) => TombstoneService());
