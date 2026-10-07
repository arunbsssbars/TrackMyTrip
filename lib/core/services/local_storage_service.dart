import 'dart:convert';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import '../../models/trip.dart';
import '../../models/trip_member.dart';
import '../../models/stoppage.dart';
import '../../models/expense.dart';
import '../../models/memory.dart';
import '../../models/settlement.dart';
import '../../models/trip_audit_log.dart';
import '../../models/sync_mutation.dart';
import '../../models/proximity_alert.dart';
import '../../models/auth_user.dart';
import '../../models/trip_invitation.dart';
import 'security_service.dart';
import 'tombstone_service.dart';
import 'trip_share_service.dart';

class LocalStorageService {
  static const String _initializedKey = 'app_seeded_v1';
  static const String _migratedToSqliteKey = 'sqlite_migrated_v1';

  final SharedPreferences _prefs;
  AppDatabase _db;
  String? _currentUserId;

  // In-memory caches to keep synchronous provider getters 100% responsive and synchronous
  List<Trip> _cachedTrips = [];
  List<Stoppage> _cachedStoppages = [];
  List<Expense> _cachedExpenses = [];
  List<Memory> _cachedMemories = [];
  List<Settlement> _cachedSettlements = [];
  List<TripAuditLog> _cachedAuditLogs = [];
  List<SyncMutation> _cachedMutations = [];
  List<ProximityAlert> _cachedAlerts = [];
  Set<String> _readAlertIds = {};
  Set<String> _dismissedAlertIds = {};
  List<TripInvitation> _cachedInvitations = [];
  List<Map<String, dynamic>> _cachedRegisteredUsers = [];
  AuthUser? _cachedAuthUser;

  LocalStorageService._(this._prefs, this._db);

  AppDatabase get db => _db;
  String? get currentUserId => _currentUserId;

  static Future<LocalStorageService> init({
    SharedPreferences? prefs,
    AppDatabase? database,
    String? initialUserId,
  }) async {
    final effectivePrefs = prefs ?? await SharedPreferences.getInstance();
    AppDatabase effectiveDb;
    if (database != null) {
      effectiveDb = database;
    } else {
      final security = SecurityService(prefs: effectivePrefs);
      final encKey = await security.getDatabaseEncryptionKey();
      effectiveDb = await AppDatabase.open(
        password: encKey,
        userId: initialUserId,
      );
    }
    final service = LocalStorageService._(effectivePrefs, effectiveDb);
    service._currentUserId = initialUserId;
    await service._initDatabase();
    return service;
  }

  /// Switches active SQLite database to an isolated per-user database file
  Future<void> switchUser(String? userId) async {
    final cleanUserId = userId?.trim().isEmpty == true ? null : userId?.trim();
    if (cleanUserId == _currentUserId && cleanUserId != null) {
      return;
    }

    _currentUserId = cleanUserId;

    // Check if running on in-memory / mock test database
    final dbPath = _db.database.path;
    final isSpecialDb = dbPath == ':memory:' || dbPath.isEmpty || !dbPath.contains('.db');

    if (isSpecialDb) {
      if (cleanUserId == null) {
        _clearMemoryCaches();
      } else {
        await _reloadAllCaches();
      }
      return;
    }

    try {
      await _db.close();
    } catch (_) {}

    final security = SecurityService(prefs: _prefs);
    final encKey = await security.getDatabaseEncryptionKey();
    _db = await AppDatabase.openForUser(cleanUserId, password: encKey);

    if (cleanUserId == null) {
      _clearMemoryCaches();
    } else {
      await TombstoneService.reload(_db);
      await _reloadAllCaches();
    }
  }

  void _clearMemoryCaches() {
    _cachedTrips = [];
    _cachedStoppages = [];
    _cachedExpenses = [];
    _cachedMemories = [];
    _cachedSettlements = [];
    _cachedAuditLogs = [];
    _cachedMutations = [];
    _cachedAlerts = [];
    _dismissedAlertIds.clear();
    _cachedInvitations = [];
    _cachedAuthUser = null;
  }

  Future<void> _reloadAllCaches() async {
    // Populate memory cache from SQLite
    _cachedTrips = await _db.getTrips();
    _cachedStoppages = await _db.getAllStoppages();
    _cachedExpenses = await _db.getAllExpenses();
    _cachedMemories = await _db.getAllMemories();
    _cachedSettlements = await _db.getAllSettlements();
    _cachedAuditLogs = await _db.getAllAuditLogs();
    _cachedMutations = await _db.getPendingMutations();
    _cachedAlerts = await _db.getAllAlerts();
    final readList = _prefs.getStringList('read_alert_ids_${_currentUserId ?? "anon"}') ?? [];
    _readAlertIds = readList.toSet();
    final dismissedList = _prefs.getStringList('dismissed_alert_ids_${_currentUserId ?? "anon"}') ?? [];
    final dbDismissed = await _db.getDismissedAlertIds();
    _dismissedAlertIds = {...dismissedList, ...dbDismissed};
    _cachedAlerts = _cachedAlerts.where((a) => !_dismissedAlertIds.contains(a.id)).map((a) {
      if (_readAlertIds.contains(a.id)) {
        return a.copyWith(isRead: true);
      }
      return a;
    }).toList();
    _cachedAuthUser = await _db.getAuthSession();
    _cachedRegisteredUsers = await _db.getRegisteredUsers();
    _cachedInvitations = await _db.getAllInvitations();

    // Inbound anti-resurrection tombstone filter: purge any tombstoned items immediately
    final tombstoned = TombstoneService.getAllTombstonedTripIds();
    if (tombstoned.isNotEmpty) {
      _cachedTrips.removeWhere((t) => tombstoned.contains(t.id));
      _cachedStoppages.removeWhere((s) => tombstoned.contains(s.tripId));
      _cachedExpenses.removeWhere((e) => tombstoned.contains(e.tripId));
      _cachedMemories.removeWhere((m) => tombstoned.contains(m.tripId));
      _cachedSettlements.removeWhere((s) => tombstoned.contains(s.tripId));
      _cachedAuditLogs.removeWhere((a) => tombstoned.contains(a.tripId));
      _cachedAlerts.removeWhere((a) => tombstoned.contains(a.tripId));
      _cachedInvitations.removeWhere((i) => tombstoned.contains(i.tripId));
    }

    await _purgeDummyData();
  }

  Future<void> _initDatabase() async {
    await TombstoneService.init(_prefs, _db);
    if (_prefs.getBool(_migratedToSqliteKey) != true) {
      final legacyTripsStr = _prefs.getString('trips_data_v1');
      if (legacyTripsStr != null) {
        try {
          final List<dynamic> list = jsonDecode(legacyTripsStr);
          final trips = list.map((e) => Trip.fromJson(e as Map<String, dynamic>)).toList();
          for (final t in trips) {
            await _db.saveTrip(t);
          }
        } catch (_) {}
      }
      final legacyStopsStr = _prefs.getString('stoppages_data_v1');
      if (legacyStopsStr != null) {
        try {
          final List<dynamic> list = jsonDecode(legacyStopsStr);
          final stops = list.map((e) => Stoppage.fromJson(e as Map<String, dynamic>)).toList();
          await _db.saveAllStoppages(stops);
        } catch (_) {}
      }
      await _prefs.setBool(_migratedToSqliteKey, true);
    }
    await _reloadAllCaches();
  }

  // --- TRIPS ---
  List<Trip> getTrips() => List.from(_cachedTrips);

  Trip? getTrip(String tripId) => _cachedTrips.where((t) => t.id == tripId).firstOrNull;

  Future<List<Trip>> getTripsAsync() async {
      _cachedTrips = await _db.getTrips();
    return getTrips();
  }

  Future<void> saveTrips(List<Trip> trips) async {
    _cachedTrips = List.from(trips);
      await _db.saveTrips(trips);
  }

  Future<void> saveTrip(Trip trip) async {
    final list = List<Trip>.from(_cachedTrips);
    final idx = list.indexWhere((t) => t.id == trip.id);
    if (idx != -1) {
      list[idx] = trip;
    } else {
      list.insert(0, trip);
    }
    _cachedTrips = list;

      await _db.saveTrip(trip);
  }

  Future<void> deleteTrip(String tripId) async {
    await TombstoneService.markTombstoned(tripId);

    _cachedTrips.removeWhere((t) => t.id == tripId);
    _cachedStoppages.removeWhere((s) => s.tripId == tripId);
    _cachedExpenses.removeWhere((e) => e.tripId == tripId);
    _cachedMemories.removeWhere((m) => m.tripId == tripId);
    _cachedSettlements.removeWhere((s) => s.tripId == tripId);
    _cachedAuditLogs.removeWhere((a) => a.tripId == tripId);
    _cachedAlerts.removeWhere((a) => a.tripId == tripId);
    _cachedInvitations.removeWhere((i) => i.tripId == tripId);

    await Future.wait([
      saveTrips(_cachedTrips),
      saveAllStoppages(_cachedStoppages),
      saveAllExpenses(_cachedExpenses),
      saveAllMemories(_cachedMemories),
      saveAllSettlements(_cachedSettlements),
      saveAllAuditLogs(_cachedAuditLogs),
      _db.deleteTrip(tripId),
    ]);
  }

  Future<Trip> importTripPackage(TripPackage package, {String? activeMemberId}) async {
    final tripId = package.trip.id;
    if (TombstoneService.isTombstoned(tripId)) {
      return package.trip;
    }
    final existingTrips = List<Trip>.from(_cachedTrips);
    final existingIndex = existingTrips.indexWhere((t) => t.id == tripId);
    final existingTrip = existingIndex >= 0 ? existingTrips[existingIndex] : null;

    final effectiveActiveMemberId = activeMemberId ?? existingTrip?.currentUserMember?.id;

    // Merge members: retain existing local members and combine with incoming package members
    final Map<String, TripMember> memberMap = {};
    if (existingTrip != null) {
      for (final m in existingTrip.members) {
        memberMap[m.id] = m;
      }
    }
    for (final m in package.trip.members) {
      memberMap[m.id] = m;
    }

    List<TripMember> membersToSave = memberMap.values.map((m) {
      if (effectiveActiveMemberId != null) {
        return m.copyWith(isCurrentUser: m.id == effectiveActiveMemberId);
      }
      return m;
    }).toList();

    // Critical: If active member is not present in incoming package, preserve from existing local trip
    if (effectiveActiveMemberId != null && !membersToSave.any((m) => m.id == effectiveActiveMemberId)) {
      final existingActiveMember = existingTrip?.members.where((m) => m.id == effectiveActiveMemberId).firstOrNull;
      if (existingActiveMember != null) {
        membersToSave.add(existingActiveMember.copyWith(isCurrentUser: true));
      }
    }

    final preservedShareCode = package.trip.shareCode ?? existingTrip?.shareCode;
    final tripToSave = package.trip.copyWith(
      shareCode: preservedShareCode,
      members: membersToSave,
    );

    if (existingIndex >= 0) {
      existingTrips[existingIndex] = tripToSave;
    } else {
      existingTrips.insert(0, tripToSave);
    }
    await saveTrips(existingTrips);

    // Merge Stoppages
    final allStops = List<Stoppage>.from(_cachedStoppages);
    allStops.removeWhere((s) => s.tripId == tripId);
    allStops.addAll(package.stoppages);
    await saveAllStoppages(allStops);

    // Merge Expenses
    final allExps = List<Expense>.from(_cachedExpenses);
    allExps.removeWhere((e) => e.tripId == tripId);
    allExps.addAll(package.expenses);
    await saveAllExpenses(allExps);

    // Merge Memories
    final allMems = List<Memory>.from(_cachedMemories);
    allMems.removeWhere((m) => m.tripId == tripId);
    final validMemories = package.memories.where((m) => !TombstoneService.isMemoryTombstoned(m.id)).toList();
    allMems.addAll(validMemories);
    await _db.deleteMemoriesForTrip(tripId);
    await _db.saveAllMemories(allMems);
    _cachedMemories = allMems;

    // Merge Settlements
    final allSettlements = List<Settlement>.from(_cachedSettlements);
    allSettlements.removeWhere((s) => s.tripId == tripId);
    allSettlements.addAll(package.settlements);
    await saveAllSettlements(allSettlements);

    // Merge Audit Logs
    final allAudit = List<TripAuditLog>.from(_cachedAuditLogs);
    final existingIds = allAudit.map((a) => a.id).toSet();
    for (final log in package.auditLogs) {
      if (!existingIds.contains(log.id)) {
        allAudit.add(log);
      }
    }
    await saveAllAuditLogs(allAudit);

    return tripToSave;
  }

  Future<void> setActiveMember(String tripId, String memberId) async {
    final existingTrips = List<Trip>.from(_cachedTrips);
    final tripIndex = existingTrips.indexWhere((t) => t.id == tripId);
    if (tripIndex == -1) return;

    final trip = existingTrips[tripIndex];
    final updatedMembers = trip.members.map((m) {
      return m.copyWith(isCurrentUser: m.id == memberId);
    }).toList();

    existingTrips[tripIndex] = trip.copyWith(members: updatedMembers);
    await saveTrips(existingTrips);
  }

  // --- STOPPAGES ---
  List<Stoppage> getStoppages(String tripId) {
    final filtered = _cachedStoppages.where((s) => s.tripId == tripId).toList();
    filtered.sort((a, b) => a.arrivedAt.compareTo(b.arrivedAt));
    return filtered;
  }

  Future<List<Stoppage>> getStoppagesAsync(String tripId) async {
    return await _db.getStoppages(tripId);
  }

  Future<void> saveAllStoppages(List<Stoppage> stoppages) async {
    _cachedStoppages = List.from(stoppages);
      await _db.saveAllStoppages(stoppages);
  }

  Future<void> saveStoppage(Stoppage stoppage) async {
    final list = List<Stoppage>.from(_cachedStoppages);
    final idx = list.indexWhere((s) => s.id == stoppage.id);
    if (idx != -1) {
      list[idx] = stoppage;
    } else {
      list.add(stoppage);
    }
    _cachedStoppages = list;
      await _db.saveStoppage(stoppage);
  }

  Future<void> deleteStoppage(String stoppageId) async {
    _cachedStoppages.removeWhere((s) => s.id == stoppageId);
      await _db.deleteStoppage(stoppageId);
  }

  List<Stoppage> getAllStoppages() => List.from(_cachedStoppages);

  // --- EXPENSES ---
  List<Expense> getExpenses(String tripId) {
    return _cachedExpenses.where((e) => e.tripId == tripId).toList();
  }

  Future<List<Expense>> getExpensesAsync(String tripId) async {
    return await _db.getExpenses(tripId);
  }

  Future<void> saveAllExpenses(List<Expense> expenses) async {
    _cachedExpenses = List.from(expenses);
      await _db.saveAllExpenses(expenses);
  }

  Future<void> saveExpense(Expense expense) async {
    final list = List<Expense>.from(_cachedExpenses);
    final idx = list.indexWhere((e) => e.id == expense.id);
    if (idx != -1) {
      list[idx] = expense;
    } else {
      list.add(expense);
    }
    _cachedExpenses = list;
      await _db.saveExpense(expense);
  }

  Future<void> deleteExpense(String expenseId) async {
    _cachedExpenses.removeWhere((e) => e.id == expenseId);
      await _db.deleteExpense(expenseId);
  }

  List<Expense> getAllExpenses() => List.from(_cachedExpenses);

  // --- MEMORIES ---
  List<Memory> getMemories(String tripId) {
    return _cachedMemories.where((m) => m.tripId == tripId).toList();
  }

  Future<List<Memory>> getMemoriesAsync(String tripId) async {
    return await _db.getMemories(tripId);
  }

  Future<void> saveAllMemories(List<Memory> memories) async {
    _cachedMemories = List.from(memories);
      await _db.saveAllMemories(memories);
  }

  Future<void> saveMemory(Memory memory) async {
    final list = List<Memory>.from(_cachedMemories);
    final idx = list.indexWhere((m) => m.id == memory.id);
    if (idx != -1) {
      list[idx] = memory;
    } else {
      list.add(memory);
    }
    _cachedMemories = list;
      await _db.saveMemory(memory);
  }

  Future<void> deleteMemory(String memoryId) async {
    _cachedMemories.removeWhere((m) => m.id == memoryId);
    await _db.deleteMemory(memoryId);
    await TombstoneService.markMemoryTombstoned(memoryId);
  }

  List<Memory> getAllMemories() => List.from(_cachedMemories);

  // --- SETTLEMENTS ---
  List<Settlement> getSettlements(String tripId) {
    return _cachedSettlements.where((s) => s.tripId == tripId).toList();
  }

  Future<List<Settlement>> getSettlementsAsync(String tripId) async {
    return await _db.getSettlements(tripId);
  }

  Future<void> saveAllSettlements(List<Settlement> settlements) async {
    _cachedSettlements = List.from(settlements);
      await _db.saveAllSettlements(settlements);
  }

  Future<void> saveSettlement(Settlement settlement) async {
    final list = List<Settlement>.from(_cachedSettlements);
    final idx = list.indexWhere((s) => s.id == settlement.id);
    if (idx != -1) {
      list[idx] = settlement;
    } else {
      list.add(settlement);
    }
    _cachedSettlements = list;
      await _db.saveSettlement(settlement);
  }

  Future<void> deleteSettlement(String settlementId) async {
    _cachedSettlements.removeWhere((s) => s.id == settlementId);
      await _db.deleteSettlement(settlementId);
  }

  List<Settlement> getAllSettlements() => List.from(_cachedSettlements);

  // --- AUDIT / TRUST LOGS ---
  List<TripAuditLog> getAuditLogs(String tripId) {
    final filtered = _cachedAuditLogs.where((a) => a.tripId == tripId).toList();
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filtered;
  }

  Future<List<TripAuditLog>> getAuditLogsAsync(String tripId) async {
    return await _db.getAuditLogs(tripId);
  }

  Future<void> saveAllAuditLogs(List<TripAuditLog> logs) async {
    _cachedAuditLogs = List.from(logs);
      await _db.saveAllAuditLogs(logs);
  }

  Future<void> saveAuditLog(TripAuditLog log) async {
    final list = List<TripAuditLog>.from(_cachedAuditLogs);
    list.insert(0, log);
    if (list.length > 500) list.removeLast();
    _cachedAuditLogs = list;
      await _db.saveAuditLog(log);
  }

  List<TripAuditLog> getAllAuditLogs() => List.from(_cachedAuditLogs);

  // --- OFFLINE OUTBOX MUTATIONS ---
  List<SyncMutation> getPendingMutations() => List.from(_cachedMutations);

  Future<List<SyncMutation>> getPendingMutationsAsync() async {
      _cachedMutations = await _db.getPendingMutations();
    return getPendingMutations();
  }

  Future<void> saveAllMutations(List<SyncMutation> mutations) async {
    _cachedMutations = List.from(mutations);
      await _db.saveAllMutations(mutations);
  }

  Future<void> enqueueMutation(SyncMutation mutation) async {
    final list = List<SyncMutation>.from(_cachedMutations);
    final existingIdx = list.indexWhere((m) =>
        m.id == mutation.id ||
        ((m.status == SyncStatus.pending || m.status == SyncStatus.failed) &&
            m.entityType == mutation.entityType &&
            m.entityId == mutation.entityId));
    if (existingIdx != -1) {
      list[existingIdx] = mutation;
    } else {
      list.add(mutation);
    }
    _cachedMutations = list;
    await saveAllMutations(list);
  }

  Future<void> removeMutation(String mutationId) async {
    final list = List<SyncMutation>.from(_cachedMutations);
    list.removeWhere((m) => m.id == mutationId);
    _cachedMutations = list;
    await saveAllMutations(list);
  }

  Future<void> clearSyncedMutations() async {
    final list = List<SyncMutation>.from(_cachedMutations);
    list.removeWhere((m) => m.status == SyncStatus.synced);
    _cachedMutations = list;
    await saveAllMutations(list);
  }

  // --- PROXIMITY & PUSH ALERTS ---
  List<ProximityAlert> getAllAlerts() => List.from(_cachedAlerts);

  Future<List<ProximityAlert>> getAllAlertsAsync() async {
      _cachedAlerts = await _db.getAllAlerts();
    return getAllAlerts();
  }

  Future<void> saveAllAlerts(List<ProximityAlert> alerts) async {
    _cachedAlerts = List.from(alerts);
      await _db.saveAllAlerts(alerts);
  }

  bool isAlertRead(String alertId) => _readAlertIds.contains(alertId);

  Future<void> addAlert(ProximityAlert alert) async {
    if (_readAlertIds.contains(alert.id)) {
      alert = alert.copyWith(isRead: true);
    }
    final list = List<ProximityAlert>.from(_cachedAlerts);
    list.removeWhere((a) => a.id == alert.id);
    list.insert(0, alert);
    if (list.length > 100) list.removeLast();
    _cachedAlerts = list;
    await saveAllAlerts(list);
  }

  Future<void> markAlertAsRead(String alertId) async {
    _readAlertIds.add(alertId);
    await _prefs.setStringList('read_alert_ids_${_currentUserId ?? "anon"}', _readAlertIds.toList());
    final list = List<ProximityAlert>.from(_cachedAlerts);
    final idx = list.indexWhere((a) => a.id == alertId);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(isRead: true);
      _cachedAlerts = list;
      await saveAllAlerts(list);
    }
  }

  Future<void> markAllAlertsAsRead() async {
    for (final a in _cachedAlerts) {
      _readAlertIds.add(a.id);
    }
    await _prefs.setStringList('read_alert_ids_${_currentUserId ?? "anon"}', _readAlertIds.toList());
    _cachedAlerts = _cachedAlerts.map((a) => a.copyWith(isRead: true)).toList();
    await saveAllAlerts(_cachedAlerts);
  }

  bool isAlertDismissed(String alertId) => _dismissedAlertIds.contains(alertId);

  DateTime? getAlertsClearedAt() {
    final ms = _prefs.getInt('alerts_cleared_at_${_currentUserId ?? "anon"}');
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> recordAlertDismissed(String alertId, {String? tripId}) async {
    _dismissedAlertIds.add(alertId);
    await _db.recordAlertDismissed(alertId, tripId: tripId);
    await _prefs.setStringList('dismissed_alert_ids_${_currentUserId ?? "anon"}', _dismissedAlertIds.toList());
  }

  Future<void> deleteAlert(String alertId, {String? tripId}) async {
    final list = List<ProximityAlert>.from(_cachedAlerts);
    final target = list.where((a) => a.id == alertId).firstOrNull;
    list.removeWhere((a) => a.id == alertId);
    _cachedAlerts = list;
    await recordAlertDismissed(alertId, tripId: tripId ?? target?.tripId);
    await _db.deleteAlert(alertId);
  }

  Future<void> clearAllAlerts() async {
    for (final a in _cachedAlerts) {
      _dismissedAlertIds.add(a.id);
    }
    await _prefs.setStringList('dismissed_alert_ids_${_currentUserId ?? "anon"}', _dismissedAlertIds.toList());
    await _prefs.setInt('alerts_cleared_at_${_currentUserId ?? "anon"}', DateTime.now().millisecondsSinceEpoch);
    _cachedAlerts = [];
    await _db.clearAllAlerts();
  }

  DateTime? getTripAlertsClearedAt(String tripId) {
    final ms = _prefs.getInt('trip_alerts_cleared_at_${tripId}_${_currentUserId ?? "anon"}');
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> clearAlertsForTrip(String tripId) async {
    final toDismiss = _cachedAlerts.where((a) => a.tripId == tripId).toList();
    for (final a in toDismiss) {
      _dismissedAlertIds.add(a.id);
      await _db.recordAlertDismissed(a.id, tripId: tripId);
    }
    await _prefs.setStringList('dismissed_alert_ids_${_currentUserId ?? "anon"}', _dismissedAlertIds.toList());
    await _prefs.setInt('trip_alerts_cleared_at_${tripId}_${_currentUserId ?? "anon"}', DateTime.now().millisecondsSinceEpoch);
    _cachedAlerts = _cachedAlerts.where((a) => a.tripId != tripId).toList();
    await _db.deleteAlertsByTripId(tripId);
  }

  // --- IN-APP BANNER PREFERENCES ---
  bool getInAppBannersEnabled() => _prefs.getBool('in_app_banners_enabled') ?? true;

  Future<void> setInAppBannersEnabled(bool enabled) async {
    await _prefs.setBool('in_app_banners_enabled', enabled);
  }

  // --- GEOFENCE & PROXIMITY PREFERENCES ---
  double getStrayThresholdMeters() => _prefs.getDouble('stray_threshold_meters') ?? 1500.0;

  Future<void> setStrayThresholdMeters(double meters) async {
    await _prefs.setDouble('stray_threshold_meters', meters);
  }

  bool getStrayAlertsEnabled() => _prefs.getBool('stray_alerts_enabled') ?? true;

  Future<void> setStrayAlertsEnabled(bool enabled) async {
    await _prefs.setBool('stray_alerts_enabled', enabled);
  }

  bool getStoppageAlertsEnabled() => _prefs.getBool('stoppage_alerts_enabled') ?? true;

  Future<void> setStoppageAlertsEnabled(bool enabled) async {
    await _prefs.setBool('stoppage_alerts_enabled', enabled);
  }

  bool hasRequestedLocationPermission() => _prefs.getBool('has_requested_location_permission_v1') ?? false;

  Future<void> setRequestedLocationPermission(bool requested) async {
    await _prefs.setBool('has_requested_location_permission_v1', requested);
  }

  // --- THEME PREFERENCES ---
  ThemeMode getThemeMode() {
    final modeStr = _prefs.getString('app_theme_mode_v1');
    switch (modeStr) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    String modeStr;
    switch (mode) {
      case ThemeMode.light:
        modeStr = 'light';
        break;
      case ThemeMode.dark:
        modeStr = 'dark';
        break;
      case ThemeMode.system:
        modeStr = 'system';
        break;
    }
    await _prefs.setString('app_theme_mode_v1', modeStr);
  }

  // --- AUTH SESSION & REGISTERED ACCOUNTS ---
  AuthUser? getAuthSession() => _cachedAuthUser;

  Future<AuthUser?> getAuthSessionAsync() async {
      _cachedAuthUser = await _db.getAuthSession();
    return getAuthSession();
  }

  Future<void> saveAuthSession(AuthUser user) async {
    _cachedAuthUser = user;
      await _db.saveAuthSession(user);
  }

  Future<void> clearAuthSession() async {
    _cachedAuthUser = null;
      await _db.clearAuthSession();
  }

  List<Map<String, dynamic>> getRegisteredUsers() => List.from(_cachedRegisteredUsers);

  Future<List<Map<String, dynamic>>> getRegisteredUsersAsync() async {
      _cachedRegisteredUsers = await _db.getRegisteredUsers();
    return getRegisteredUsers();
  }

  Future<void> saveRegisteredUser(Map<String, dynamic> userRecord) async {
    final list = List<Map<String, dynamic>>.from(_cachedRegisteredUsers);
    list.removeWhere((u) => u['email'] == userRecord['email'] || u['username'] == userRecord['username']);
    list.add(userRecord);
    _cachedRegisteredUsers = list;
    await _db.saveRegisteredUser(userRecord);
  }

  Future<void> deleteRegisteredUser(String idOrEmail) async {
    final clean = idOrEmail.toLowerCase().trim();
    final list = List<Map<String, dynamic>>.from(_cachedRegisteredUsers);
    list.removeWhere((u) =>
      (u['id'] != null && u['id'].toString().toLowerCase() == clean) ||
      (u['email'] != null && u['email'].toString().toLowerCase() == clean) ||
      (u['username'] != null && u['username'].toString().toLowerCase() == clean)
    );
    _cachedRegisteredUsers = list;
    await _db.deleteRegisteredUser(clean);
  }

  Future<bool> updateRegisteredUserPassword(String email, String newPassword) async {
    final list = List<Map<String, dynamic>>.from(_cachedRegisteredUsers);
    final idx = list.indexWhere((u) => (u['email'] as String).toLowerCase() == email.toLowerCase());
    if (idx != -1) {
      list[idx]['password'] = newPassword;
      _cachedRegisteredUsers = list;
          await _db.updateRegisteredUserPassword(email, newPassword);
      return true;
    }
    return false;
  }

  // --- TRIP INVITATIONS ---
  List<TripInvitation> getAllInvitations() => List.from(_cachedInvitations);

  Future<List<TripInvitation>> getAllInvitationsAsync() async {
      _cachedInvitations = await _db.getAllInvitations();
    return getAllInvitations();
  }

  List<TripInvitation> getPendingInvitations({
    String? currentUserId,
    String? currentUserEmail,
    String? currentUsername,
  }) {
    final effectiveUid = currentUserId ??
        (currentUserEmail == null && currentUsername == null
            ? (_currentUserId ?? _cachedAuthUser?.id)
            : null);
    final effectiveEmail = currentUserEmail?.trim().toLowerCase() ?? _cachedAuthUser?.email.trim().toLowerCase();
    final effectiveUsername = currentUsername?.trim().toLowerCase() ?? _cachedAuthUser?.username.trim().toLowerCase();

    return _cachedInvitations.where((inv) {
      if (inv.status != InvitationStatus.pending) return false;

      // 1. Never show outgoing invitations sent by the current user to themselves
      if (effectiveUid != null && inv.inviterId == effectiveUid) {
        return false;
      }

      // 2. If user identity is specified, ensure invitation is addressed to them
      if (effectiveUid != null || effectiveEmail != null || effectiveUsername != null) {
        final matchesId = effectiveUid != null && inv.inviteeId != null && inv.inviteeId == effectiveUid;
        final matchesEmail = effectiveEmail != null &&
            inv.inviteeEmail != null &&
            inv.inviteeEmail!.trim().toLowerCase() == effectiveEmail;
        final matchesUsername = effectiveUsername != null &&
            inv.inviteeUsername.trim().toLowerCase() == effectiveUsername;
        return matchesId || matchesEmail || matchesUsername;
      }

      // 3. Fallback: If no parameters given, do not return invitations sent by database owner
      if (_currentUserId != null && inv.inviterId == _currentUserId) {
        return false;
      }

      return true;
    }).toList();
  }

  List<TripInvitation> getSentInvitations({String? currentUserId}) {
    final effectiveUid = currentUserId ?? _currentUserId ?? _cachedAuthUser?.id;
    if (effectiveUid == null) return [];
    return _cachedInvitations.where((inv) => inv.inviterId == effectiveUid).toList();
  }

  Future<void> saveInvitation(TripInvitation invitation) async {
    final list = List<TripInvitation>.from(_cachedInvitations);
    list.removeWhere((i) => i.id == invitation.id);
    list.insert(0, invitation);
    _cachedInvitations = list;
      await _db.saveInvitation(invitation);
  }

  Future<void> updateInvitationStatus(String invitationId, InvitationStatus status) async {
    final list = List<TripInvitation>.from(_cachedInvitations);
    final idx = list.indexWhere((i) => i.id == invitationId);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(status: status);
      _cachedInvitations = list;
      await _db.updateInvitationStatus(invitationId, status);
    }
  }

  Future<void> deleteInvitation(String invitationId) async {
    final list = List<TripInvitation>.from(_cachedInvitations);
    list.removeWhere((i) => i.id == invitationId);
    _cachedInvitations = list;
    await _db.deleteInvitation(invitationId);
  }


  /// Loop 126: Telemetry stats for offline SQLite database & cached entities
  Map<String, int> getStorageTelemetry() {
    return {
      'trips': _cachedTrips.length,
      'stoppages': _cachedStoppages.length,
      'expenses': _cachedExpenses.length,
      'memories': _cachedMemories.length,
      'settlements': _cachedSettlements.length,
      'auditLogs': _cachedAuditLogs.length,
      'mutations': _cachedMutations.length,
      'alerts': _cachedAlerts.length,
    };
  }

  /// Loop 126: Purge obsolete or completed mutations from the offline sync queue
  Future<int> purgeObsoleteMutations() async {
    final initialCount = _cachedMutations.length;
    final now = DateTime.now();
    // Remove mutations already synced OR failed mutations older than 7 days
    _cachedMutations.removeWhere((m) {
      if (m.status == SyncStatus.synced) return true;
      if (m.status == SyncStatus.failed && now.difference(m.createdAt).inDays > 7) return true;
      return false;
    });
    final purged = initialCount - _cachedMutations.length;
    if (purged > 0) {
      await saveAllMutations(_cachedMutations);
    }
    return purged;
  }

  Future<void> _purgeDummyData() async {
    final dummyTrips = _cachedTrips.where((t) =>
        t.title == 'Pacific Coast Highway Getaway' ||
        t.title.toLowerCase().contains('sample') ||
        t.title.toLowerCase().contains('mock') ||
        t.createdByMemberId == 'usr_me' ||
        t.createdByMemberId == 'mock_user' ||
        t.createdByMemberId.isEmpty,
    ).toList();
    for (final dt in dummyTrips) {
      await deleteTrip(dt.id);
    }
    _cachedStoppages.removeWhere((s) =>
        s.name.contains('Half Moon Bay') ||
        s.name.contains('Chevron Coastal') ||
        s.name.contains('Bixby Creek'));
    _cachedExpenses.removeWhere((e) =>
        e.title.contains('Artisanal Coffee') ||
        e.title.contains('Full Tank') ||
        e.title.contains('Big Sur State Park'));
    _cachedMemories.removeWhere((m) =>
        m.caption?.contains('croissant') == true ||
        m.caption?.contains('majestic') == true);
    await _db.saveAllStoppages(_cachedStoppages);
    await _db.saveAllExpenses(_cachedExpenses);
    await _db.saveAllMemories(_cachedMemories);
    await _prefs.setBool(_initializedKey, true);
  }
}
