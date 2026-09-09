import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../../models/trip.dart';
import '../../models/trip_member.dart';
import '../../models/stoppage.dart';
import '../../models/expense.dart';
import '../../models/expense_split.dart';
import '../../models/memory.dart';
import '../../models/settlement.dart';
import '../../models/trip_audit_log.dart';
import '../../models/sync_mutation.dart';
import '../../models/proximity_alert.dart';
import '../../models/auth_user.dart';
import '../../models/trip_invitation.dart';
import 'trip_share_service.dart';

class LocalStorageService {
  static const String _tripsKey = 'trips_data_v1';
  static const String _stoppagesKey = 'stoppages_data_v1';
  static const String _expensesKey = 'expenses_data_v1';
  static const String _memoriesKey = 'memories_data_v1';
  static const String _settlementsKey = 'settlements_data_v1';
  static const String _auditLogsKey = 'audit_logs_data_v1';
  static const String _mutationsKey = 'sync_mutations_v1';
  static const String _alertsKey = 'proximity_alerts_v1';
  static const String _authSessionKey = 'auth_session_v1';
  static const String _registeredUsersKey = 'registered_users_v1';
  static const String _invitationsKey = 'trip_invitations_v1';
  static const String _initializedKey = 'app_seeded_v1';
  static const String _migratedToSqliteKey = 'sqlite_migrated_v1';

  final SharedPreferences _prefs;
  final AppDatabase? _db;

  // In-memory caches to keep synchronous provider getters 100% responsive and synchronous
  List<Trip> _cachedTrips = [];
  List<Stoppage> _cachedStoppages = [];
  List<Expense> _cachedExpenses = [];
  List<Memory> _cachedMemories = [];
  List<Settlement> _cachedSettlements = [];
  List<TripAuditLog> _cachedAuditLogs = [];
  List<SyncMutation> _cachedMutations = [];
  List<ProximityAlert> _cachedAlerts = [];
  List<TripInvitation> _cachedInvitations = [];
  List<Map<String, dynamic>> _cachedRegisteredUsers = [];
  AuthUser? _cachedAuthUser;

  LocalStorageService(this._prefs, [this._db]) {
    _loadSyncFromMemoryOrPrefs();
  }

  AppDatabase? get db => _db;

  void _loadSyncFromMemoryOrPrefs() {
    // 1. Trips
    final tripsStr = _prefs.getString(_tripsKey);
    if (tripsStr != null) {
      try {
        final List<dynamic> list = jsonDecode(tripsStr);
        _cachedTrips = list.map((e) => Trip.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    // 2. Stoppages
    final stopStr = _prefs.getString(_stoppagesKey);
    if (stopStr != null) {
      try {
        final List<dynamic> list = jsonDecode(stopStr);
        _cachedStoppages = list.map((e) => Stoppage.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    // 3. Expenses
    final expStr = _prefs.getString(_expensesKey);
    if (expStr != null) {
      try {
        final List<dynamic> list = jsonDecode(expStr);
        _cachedExpenses = list.map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    // 4. Memories
    final memStr = _prefs.getString(_memoriesKey);
    if (memStr != null) {
      try {
        final List<dynamic> list = jsonDecode(memStr);
        _cachedMemories = list.map((e) => Memory.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    // 5. Settlements
    final setStr = _prefs.getString(_settlementsKey);
    if (setStr != null) {
      try {
        final List<dynamic> list = jsonDecode(setStr);
        _cachedSettlements = list.map((e) => Settlement.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    // 6. Audit Logs
    final auditStr = _prefs.getString(_auditLogsKey);
    if (auditStr != null) {
      try {
        final List<dynamic> list = jsonDecode(auditStr);
        _cachedAuditLogs = list.map((e) => TripAuditLog.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    // 7. Mutations
    final mutStr = _prefs.getString(_mutationsKey);
    if (mutStr != null) {
      try {
        final List<dynamic> list = jsonDecode(mutStr);
        _cachedMutations = list.map((e) => SyncMutation.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    // 8. Alerts
    final alertStr = _prefs.getString(_alertsKey);
    if (alertStr != null) {
      try {
        final List<dynamic> list = jsonDecode(alertStr);
        _cachedAlerts = list.map((e) => ProximityAlert.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    // 9. Auth Session
    final authStr = _prefs.getString(_authSessionKey);
    if (authStr != null) {
      try {
        _cachedAuthUser = AuthUser.fromJson(jsonDecode(authStr) as Map<String, dynamic>);
      } catch (_) {}
    }

    // 10. Registered Users
    final regStr = _prefs.getString(_registeredUsersKey);
    if (regStr != null) {
      try {
        final List<dynamic> list = jsonDecode(regStr);
        _cachedRegisteredUsers = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    // 11. Invitations
    final invStr = _prefs.getString(_invitationsKey);
    if (invStr != null) {
      try {
        final List<dynamic> list = jsonDecode(invStr);
        _cachedInvitations = list.map((e) => TripInvitation.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
  }

  static Future<LocalStorageService> init({AppDatabase? database, SharedPreferences? prefs}) async {
    final effectivePrefs = prefs ?? await SharedPreferences.getInstance();
    AppDatabase? effectiveDb = database;

    if (effectiveDb == null) {
      try {
        effectiveDb = await AppDatabase.open();
      } catch (_) {
        // Fallback for non-sqlite or test environments without sqflite initialized
      }
    }

    final service = LocalStorageService(effectivePrefs, effectiveDb);
    await service._initDatabaseAndMigrate();
    return service;
  }

  Future<void> _initDatabaseAndMigrate() async {
    if (_db != null) {
      final isMigrated = _prefs.getBool(_migratedToSqliteKey) ?? false;
      if (!isMigrated) {
        await _migrateLegacyPreferencesToSqlite();
        await _prefs.setBool(_migratedToSqliteKey, true);
      }

      // Populate memory cache from SQLite
      _cachedTrips = await _db.getTrips();
      _cachedStoppages = await _db.getAllStoppages();
      _cachedExpenses = await _db.getAllExpenses();
      _cachedMemories = await _db.getAllMemories();
      _cachedSettlements = await _db.getAllSettlements();
      _cachedAuditLogs = await _db.getAllAuditLogs();
      _cachedMutations = await _db.getPendingMutations();
      _cachedAlerts = await _db.getAllAlerts();
      _cachedAuthUser = await _db.getAuthSession();
      _cachedRegisteredUsers = await _db.getRegisteredUsers();
      _cachedInvitations = await _db.getAllInvitations();
    }

    if (_cachedTrips.isEmpty && _prefs.getBool(_initializedKey) != true) {
      await _seedInitialDataIfEmpty();
    }
  }

  Future<void> _migrateLegacyPreferencesToSqlite() async {
    if (_db == null) return;

    if (_cachedTrips.isNotEmpty) {
      await _db.saveTrips(_cachedTrips);
    }
    if (_cachedStoppages.isNotEmpty) {
      await _db.saveAllStoppages(_cachedStoppages);
    }
    if (_cachedExpenses.isNotEmpty) {
      await _db.saveAllExpenses(_cachedExpenses);
    }
    if (_cachedMemories.isNotEmpty) {
      await _db.saveAllMemories(_cachedMemories);
    }
    if (_cachedSettlements.isNotEmpty) {
      await _db.saveAllSettlements(_cachedSettlements);
    }
    if (_cachedAuditLogs.isNotEmpty) {
      await _db.saveAllAuditLogs(_cachedAuditLogs);
    }
    if (_cachedMutations.isNotEmpty) {
      await _db.saveAllMutations(_cachedMutations);
    }
    if (_cachedAlerts.isNotEmpty) {
      await _db.saveAllAlerts(_cachedAlerts);
    }
    if (_cachedAuthUser != null) {
      await _db.saveAuthSession(_cachedAuthUser!);
    }
    for (final reg in _cachedRegisteredUsers) {
      await _db.saveRegisteredUser(reg);
    }
    for (final inv in _cachedInvitations) {
      await _db.saveInvitation(inv);
    }
  }

  // --- TRIPS ---
  List<Trip> getTrips() => List.from(_cachedTrips);

  Future<List<Trip>> getTripsAsync() async {
    if (_db != null) {
      _cachedTrips = await _db.getTrips();
    }
    return getTrips();
  }

  Future<void> saveTrips(List<Trip> trips) async {
    _cachedTrips = List.from(trips);
    final jsonString = jsonEncode(trips.map((e) => e.toJson()).toList());
    await _prefs.setString(_tripsKey, jsonString);
    if (_db != null) {
      await _db.saveTrips(trips);
    }
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

    final jsonString = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_tripsKey, jsonString);
    if (_db != null) {
      await _db.saveTrip(trip);
    }
  }

  Future<void> deleteTrip(String tripId) async {
    _cachedTrips.removeWhere((t) => t.id == tripId);
    _cachedStoppages.removeWhere((s) => s.tripId == tripId);
    _cachedExpenses.removeWhere((e) => e.tripId == tripId);
    _cachedMemories.removeWhere((m) => m.tripId == tripId);
    _cachedSettlements.removeWhere((s) => s.tripId == tripId);
    _cachedAuditLogs.removeWhere((a) => a.tripId == tripId);

    await saveTrips(_cachedTrips);
    await saveAllStoppages(_cachedStoppages);
    await saveAllExpenses(_cachedExpenses);
    await saveAllMemories(_cachedMemories);
    await saveAllSettlements(_cachedSettlements);
    await saveAllAuditLogs(_cachedAuditLogs);

    if (_db != null) {
      await _db.deleteTrip(tripId);
    }
  }

  Future<Trip> importTripPackage(TripPackage package, {String? activeMemberId}) async {
    final existingTrips = List<Trip>.from(_cachedTrips);
    final tripId = package.trip.id;
    final existingIndex = existingTrips.indexWhere((t) => t.id == tripId);
    final existingTrip = existingIndex >= 0 ? existingTrips[existingIndex] : null;

    final effectiveActiveMemberId = activeMemberId ?? existingTrip?.currentUserMember?.id;

    List<TripMember> membersToSave = package.trip.members.map((m) {
      if (effectiveActiveMemberId != null) {
        return m.copyWith(isCurrentUser: m.id == effectiveActiveMemberId);
      }
      return m;
    }).toList();

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
    allMems.addAll(package.memories);
    await saveAllMemories(allMems);

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
    if (_db != null) {
      return await _db.getStoppages(tripId);
    }
    return getStoppages(tripId);
  }

  Future<void> saveAllStoppages(List<Stoppage> stoppages) async {
    _cachedStoppages = List.from(stoppages);
    final jsonString = jsonEncode(stoppages.map((e) => e.toJson()).toList());
    await _prefs.setString(_stoppagesKey, jsonString);
    if (_db != null) {
      await _db.saveAllStoppages(stoppages);
    }
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
    await _prefs.setString(_stoppagesKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    if (_db != null) {
      await _db.saveStoppage(stoppage);
    }
  }

  Future<void> deleteStoppage(String stoppageId) async {
    _cachedStoppages.removeWhere((s) => s.id == stoppageId);
    await _prefs.setString(_stoppagesKey, jsonEncode(_cachedStoppages.map((e) => e.toJson()).toList()));
    if (_db != null) {
      await _db.deleteStoppage(stoppageId);
    }
  }

  List<Stoppage> getAllStoppages() => List.from(_cachedStoppages);

  // --- EXPENSES ---
  List<Expense> getExpenses(String tripId) {
    return _cachedExpenses.where((e) => e.tripId == tripId).toList();
  }

  Future<List<Expense>> getExpensesAsync(String tripId) async {
    if (_db != null) {
      return await _db.getExpenses(tripId);
    }
    return getExpenses(tripId);
  }

  Future<void> saveAllExpenses(List<Expense> expenses) async {
    _cachedExpenses = List.from(expenses);
    final jsonString = jsonEncode(expenses.map((e) => e.toJson()).toList());
    await _prefs.setString(_expensesKey, jsonString);
    if (_db != null) {
      await _db.saveAllExpenses(expenses);
    }
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
    await _prefs.setString(_expensesKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    if (_db != null) {
      await _db.saveExpense(expense);
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    _cachedExpenses.removeWhere((e) => e.id == expenseId);
    await _prefs.setString(_expensesKey, jsonEncode(_cachedExpenses.map((e) => e.toJson()).toList()));
    if (_db != null) {
      await _db.deleteExpense(expenseId);
    }
  }

  List<Expense> getAllExpenses() => List.from(_cachedExpenses);

  // --- MEMORIES ---
  List<Memory> getMemories(String tripId) {
    return _cachedMemories.where((m) => m.tripId == tripId).toList();
  }

  Future<List<Memory>> getMemoriesAsync(String tripId) async {
    if (_db != null) {
      return await _db.getMemories(tripId);
    }
    return getMemories(tripId);
  }

  Future<void> saveAllMemories(List<Memory> memories) async {
    _cachedMemories = List.from(memories);
    final jsonString = jsonEncode(memories.map((e) => e.toJson()).toList());
    await _prefs.setString(_memoriesKey, jsonString);
    if (_db != null) {
      await _db.saveAllMemories(memories);
    }
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
    await _prefs.setString(_memoriesKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    if (_db != null) {
      await _db.saveMemory(memory);
    }
  }

  Future<void> deleteMemory(String memoryId) async {
    _cachedMemories.removeWhere((m) => m.id == memoryId);
    await _prefs.setString(_memoriesKey, jsonEncode(_cachedMemories.map((e) => e.toJson()).toList()));
    if (_db != null) {
      await _db.deleteMemory(memoryId);
    }
  }

  List<Memory> getAllMemories() => List.from(_cachedMemories);

  // --- SETTLEMENTS ---
  List<Settlement> getSettlements(String tripId) {
    return _cachedSettlements.where((s) => s.tripId == tripId).toList();
  }

  Future<List<Settlement>> getSettlementsAsync(String tripId) async {
    if (_db != null) {
      return await _db.getSettlements(tripId);
    }
    return getSettlements(tripId);
  }

  Future<void> saveAllSettlements(List<Settlement> settlements) async {
    _cachedSettlements = List.from(settlements);
    final jsonString = jsonEncode(settlements.map((e) => e.toJson()).toList());
    await _prefs.setString(_settlementsKey, jsonString);
    if (_db != null) {
      await _db.saveAllSettlements(settlements);
    }
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
    await _prefs.setString(_settlementsKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    if (_db != null) {
      await _db.saveSettlement(settlement);
    }
  }

  Future<void> deleteSettlement(String settlementId) async {
    _cachedSettlements.removeWhere((s) => s.id == settlementId);
    await _prefs.setString(_settlementsKey, jsonEncode(_cachedSettlements.map((e) => e.toJson()).toList()));
    if (_db != null) {
      await _db.deleteSettlement(settlementId);
    }
  }

  List<Settlement> getAllSettlements() => List.from(_cachedSettlements);

  // --- AUDIT / TRUST LOGS ---
  List<TripAuditLog> getAuditLogs(String tripId) {
    final filtered = _cachedAuditLogs.where((a) => a.tripId == tripId).toList();
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filtered;
  }

  Future<List<TripAuditLog>> getAuditLogsAsync(String tripId) async {
    if (_db != null) {
      return await _db.getAuditLogs(tripId);
    }
    return getAuditLogs(tripId);
  }

  Future<void> saveAllAuditLogs(List<TripAuditLog> logs) async {
    _cachedAuditLogs = List.from(logs);
    final jsonString = jsonEncode(logs.map((e) => e.toJson()).toList());
    await _prefs.setString(_auditLogsKey, jsonString);
    if (_db != null) {
      await _db.saveAllAuditLogs(logs);
    }
  }

  Future<void> saveAuditLog(TripAuditLog log) async {
    final list = List<TripAuditLog>.from(_cachedAuditLogs);
    list.insert(0, log);
    if (list.length > 500) list.removeLast();
    _cachedAuditLogs = list;
    await _prefs.setString(_auditLogsKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    if (_db != null) {
      await _db.saveAuditLog(log);
    }
  }

  List<TripAuditLog> getAllAuditLogs() => List.from(_cachedAuditLogs);

  // --- OFFLINE OUTBOX MUTATIONS ---
  List<SyncMutation> getPendingMutations() => List.from(_cachedMutations);

  Future<List<SyncMutation>> getPendingMutationsAsync() async {
    if (_db != null) {
      _cachedMutations = await _db.getPendingMutations();
    }
    return getPendingMutations();
  }

  Future<void> saveAllMutations(List<SyncMutation> mutations) async {
    _cachedMutations = List.from(mutations);
    final jsonString = jsonEncode(mutations.map((e) => e.toJson()).toList());
    await _prefs.setString(_mutationsKey, jsonString);
    if (_db != null) {
      await _db.saveAllMutations(mutations);
    }
  }

  Future<void> enqueueMutation(SyncMutation mutation) async {
    final list = List<SyncMutation>.from(_cachedMutations);
    list.add(mutation);
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
    if (_db != null) {
      _cachedAlerts = await _db.getAllAlerts();
    }
    return getAllAlerts();
  }

  Future<void> saveAllAlerts(List<ProximityAlert> alerts) async {
    _cachedAlerts = List.from(alerts);
    final jsonString = jsonEncode(alerts.map((e) => e.toJson()).toList());
    await _prefs.setString(_alertsKey, jsonString);
    if (_db != null) {
      await _db.saveAllAlerts(alerts);
    }
  }

  Future<void> addAlert(ProximityAlert alert) async {
    final list = List<ProximityAlert>.from(_cachedAlerts);
    list.insert(0, alert);
    if (list.length > 100) list.removeLast();
    _cachedAlerts = list;
    await saveAllAlerts(list);
  }

  Future<void> markAlertAsRead(String alertId) async {
    final list = List<ProximityAlert>.from(_cachedAlerts);
    final idx = list.indexWhere((a) => a.id == alertId);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(isRead: true);
      _cachedAlerts = list;
      await saveAllAlerts(list);
    }
  }

  Future<void> clearAllAlerts() async {
    _cachedAlerts = [];
    await _prefs.remove(_alertsKey);
    if (_db != null) {
      await _db.clearAllAlerts();
    }
  }

  // --- AUTH SESSION & REGISTERED ACCOUNTS ---
  AuthUser? getAuthSession() => _cachedAuthUser;

  Future<AuthUser?> getAuthSessionAsync() async {
    if (_db != null) {
      _cachedAuthUser = await _db.getAuthSession();
    }
    return getAuthSession();
  }

  Future<void> saveAuthSession(AuthUser user) async {
    _cachedAuthUser = user;
    final jsonString = jsonEncode(user.toJson());
    await _prefs.setString(_authSessionKey, jsonString);
    if (_db != null) {
      await _db.saveAuthSession(user);
    }
  }

  Future<void> clearAuthSession() async {
    _cachedAuthUser = null;
    await _prefs.remove(_authSessionKey);
    if (_db != null) {
      await _db.clearAuthSession();
    }
  }

  List<Map<String, dynamic>> getRegisteredUsers() => List.from(_cachedRegisteredUsers);

  Future<List<Map<String, dynamic>>> getRegisteredUsersAsync() async {
    if (_db != null) {
      _cachedRegisteredUsers = await _db.getRegisteredUsers();
    }
    return getRegisteredUsers();
  }

  Future<void> saveRegisteredUser(Map<String, dynamic> userRecord) async {
    final list = List<Map<String, dynamic>>.from(_cachedRegisteredUsers);
    list.removeWhere((u) => u['email'] == userRecord['email'] || u['username'] == userRecord['username']);
    list.add(userRecord);
    _cachedRegisteredUsers = list;
    await _prefs.setString(_registeredUsersKey, jsonEncode(list));
    if (_db != null) {
      await _db.saveRegisteredUser(userRecord);
    }
  }

  Future<bool> updateRegisteredUserPassword(String email, String newPassword) async {
    final list = List<Map<String, dynamic>>.from(_cachedRegisteredUsers);
    final idx = list.indexWhere((u) => (u['email'] as String).toLowerCase() == email.toLowerCase());
    if (idx != -1) {
      list[idx]['password'] = newPassword;
      _cachedRegisteredUsers = list;
      await _prefs.setString(_registeredUsersKey, jsonEncode(list));
      if (_db != null) {
        await _db.updateRegisteredUserPassword(email, newPassword);
      }
      return true;
    }
    return false;
  }

  // --- TRIP INVITATIONS ---
  List<TripInvitation> getAllInvitations() => List.from(_cachedInvitations);

  Future<List<TripInvitation>> getAllInvitationsAsync() async {
    if (_db != null) {
      _cachedInvitations = await _db.getAllInvitations();
    }
    return getAllInvitations();
  }

  List<TripInvitation> getPendingInvitations() {
    return _cachedInvitations.where((inv) => inv.status == InvitationStatus.pending).toList();
  }

  Future<void> saveInvitation(TripInvitation invitation) async {
    final list = List<TripInvitation>.from(_cachedInvitations);
    list.removeWhere((i) => i.id == invitation.id);
    list.insert(0, invitation);
    _cachedInvitations = list;
    final jsonString = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_invitationsKey, jsonString);
    if (_db != null) {
      await _db.saveInvitation(invitation);
    }
  }

  Future<void> updateInvitationStatus(String invitationId, InvitationStatus status) async {
    final list = List<TripInvitation>.from(_cachedInvitations);
    final idx = list.indexWhere((i) => i.id == invitationId);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(status: status);
      _cachedInvitations = list;
      final jsonString = jsonEncode(list.map((e) => e.toJson()).toList());
      await _prefs.setString(_invitationsKey, jsonString);
      if (_db != null) {
        await _db.updateInvitationStatus(invitationId, status);
      }
    }
  }

  Future<void> deleteInvitation(String invitationId) async {
    final list = List<TripInvitation>.from(_cachedInvitations);
    list.removeWhere((i) => i.id == invitationId);
    _cachedInvitations = list;
    final jsonString = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_invitationsKey, jsonString);
    if (_db != null) {
      await _db.deleteInvitation(invitationId);
    }
  }

  // --- SEED SAMPLE ROAD TRIP ---
  Future<void> _seedInitialDataIfEmpty() async {
    if (_prefs.getBool(_initializedKey) == true) return;

    const uuid = Uuid();
    final tripId = uuid.v4();
    const memberAlex = TripMember(id: 'member_alex', name: 'Alex (You)', isCurrentUser: true, colorHex: '0xFF0F766E');
    const memberSarah = TripMember(id: 'member_sarah', name: 'Sarah', colorHex: '0xFFF97316');
    const memberDavid = TripMember(id: 'member_david', name: 'David', colorHex: '0xFF3B82F6');
    const memberMaya = TripMember(id: 'member_maya', name: 'Maya', colorHex: '0xFFEC4899');

    final sampleTrip = Trip(
      id: tripId,
      title: 'Pacific Coast Highway Getaway',
      description: 'Scenic road trip from San Francisco to Big Sur with friends!',
      startDate: DateTime.now().subtract(const Duration(days: 2)),
      endDate: DateTime.now().add(const Duration(days: 3)),
      defaultCurrency: 'USD',
      members: [memberAlex, memberSarah, memberDavid, memberMaya],
      createdByMemberId: memberAlex.id,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    );

    // Stoppages
    final stop1Id = uuid.v4();
    final stop2Id = uuid.v4();
    final stop3Id = uuid.v4();

    final now = DateTime.now();
    final stop1 = Stoppage(
      id: stop1Id,
      tripId: tripId,
      name: 'Half Moon Bay Bakery & Cafe',
      latitude: 37.4636,
      longitude: -122.4286,
      address: 'Main St, Half Moon Bay, CA',
      category: 'Food & Cafe',
      arrivedAt: now.subtract(const Duration(days: 1, hours: 8)),
      departedAt: now.subtract(const Duration(days: 1, hours: 7)),
      notes: 'Delicious warm croissants and espresso before the coastal drive.',
      createdBy: memberAlex.id,
      orderIndex: 0,
    );

    final stop2 = Stoppage(
      id: stop2Id,
      tripId: tripId,
      name: 'Chevron Coastal Fuel Station',
      latitude: 36.9741,
      longitude: -122.0308,
      address: 'Santa Cruz, CA',
      category: 'Gas / Fuel Station',
      arrivedAt: now.subtract(const Duration(days: 1, hours: 4)),
      departedAt: now.subtract(const Duration(days: 1, hours: 3, minutes: 40)),
      notes: 'Full tank refuel and wind-shield wipe.',
      createdBy: memberDavid.id,
      orderIndex: 1,
    );

    final stop3 = Stoppage(
      id: stop3Id,
      tripId: tripId,
      name: 'Bixby Creek Bridge Viewpoint',
      latitude: 36.3714,
      longitude: -121.9018,
      address: 'Cabillo Hwy, Big Sur, CA',
      category: 'Viewpoint',
      arrivedAt: now.subtract(const Duration(hours: 3)),
      departedAt: null, // Currently active / ongoing stop!
      notes: 'Breathtaking ocean cliff views and sea breeze sunset.',
      createdBy: memberSarah.id,
      orderIndex: 2,
    );

    // Expenses attached to stoppages
    final expense1 = Expense(
      id: uuid.v4(),
      tripId: tripId,
      stoppageId: stop1Id,
      title: 'Breakfast & Artisanal Coffee',
      totalAmount: 64.0,
      currency: 'USD',
      category: 'Food & Drinks',
      paidByMemberId: memberAlex.id,
      splitType: SplitType.equal,
      splits: [
        ExpenseSplit(memberId: memberAlex.id, allocatedAmount: 16.0),
        ExpenseSplit(memberId: memberSarah.id, allocatedAmount: 16.0),
        ExpenseSplit(memberId: memberDavid.id, allocatedAmount: 16.0),
        ExpenseSplit(memberId: memberMaya.id, allocatedAmount: 16.0),
      ],
      createdAt: now.subtract(const Duration(days: 1, hours: 7, minutes: 30)),
    );

    final expense2 = Expense(
      id: uuid.v4(),
      tripId: tripId,
      stoppageId: stop2Id,
      title: 'Full Tank Premium Gas',
      totalAmount: 72.50,
      currency: 'USD',
      category: 'Fuel / Gas',
      paidByMemberId: memberDavid.id,
      splitType: SplitType.equal,
      splits: [
        ExpenseSplit(memberId: memberAlex.id, allocatedAmount: 18.125),
        ExpenseSplit(memberId: memberSarah.id, allocatedAmount: 18.125),
        ExpenseSplit(memberId: memberDavid.id, allocatedAmount: 18.125),
        ExpenseSplit(memberId: memberMaya.id, allocatedAmount: 18.125),
      ],
      createdAt: now.subtract(const Duration(days: 1, hours: 3, minutes: 45)),
    );

    final expense3 = Expense(
      id: uuid.v4(),
      tripId: tripId,
      stoppageId: stop3Id,
      title: 'Big Sur State Park Entry Passes',
      totalAmount: 40.0,
      currency: 'USD',
      category: 'Activities & Tickets',
      paidByMemberId: memberSarah.id,
      splitType: SplitType.equal,
      splits: [
        ExpenseSplit(memberId: memberAlex.id, allocatedAmount: 10.0),
        ExpenseSplit(memberId: memberSarah.id, allocatedAmount: 10.0),
        ExpenseSplit(memberId: memberDavid.id, allocatedAmount: 10.0),
        ExpenseSplit(memberId: memberMaya.id, allocatedAmount: 10.0),
      ],
      createdAt: now.subtract(const Duration(hours: 2, minutes: 40)),
    );

    // Memories
    final memory1 = Memory(
      id: uuid.v4(),
      tripId: tripId,
      stoppageId: stop1Id,
      uploadedByMemberId: memberSarah.id,
      mediaPath: 'assets/sample_croissant.png',
      caption: 'Best almond croissants on the coast!',
      createdAt: now.subtract(const Duration(days: 1, hours: 7, minutes: 20)),
      likedByMemberIds: [memberAlex.id, memberDavid.id],
    );

    final memory2 = Memory(
      id: uuid.v4(),
      tripId: tripId,
      stoppageId: stop3Id,
      uploadedByMemberId: memberAlex.id,
      mediaPath: 'assets/sample_bixby.png',
      caption: 'The bridge looks majestic under the afternoon golden light!',
      createdAt: now.subtract(const Duration(hours: 2, minutes: 15)),
      likedByMemberIds: [memberSarah.id, memberMaya.id, memberDavid.id],
    );

    await saveTrips([sampleTrip]);
    await saveAllStoppages([stop1, stop2, stop3]);
    await saveAllExpenses([expense1, expense2, expense3]);
    await saveAllMemories([memory1, memory2]);
    await saveAllSettlements([]);

    await _prefs.setBool(_initializedKey, true);
  }
}
