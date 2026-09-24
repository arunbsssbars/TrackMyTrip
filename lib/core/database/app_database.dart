import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;
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
import '../services/media_cache_service.dart';

class AppDatabase {
  static const String dbName = 'trip_tracker_v1.db';
  static const int dbVersion = 1;

  static AppDatabase? _instance;
  static AppDatabase? get instance => _instance;

  final Database _db;

  AppDatabase(this._db) {
    _instance = this;
  }

  Database get database => _db;

  static String getDbNameForUser(String? userId) {
    if (userId == null || userId.trim().isEmpty) {
      return 'trip_tracker_guest.db';
    }
    final cleanId = userId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'trip_tracker_$cleanId.db';
  }

  /// Safely purges any pre-partitioning monolithic database file to prevent cross-account leakage
  static Future<void> purgeLegacyDatabase() async {
    try {
      final dbDir = await getDatabasesPath();
      final legacyPath = p.join(dbDir, dbName);
      await deleteDatabase(legacyPath);
    } catch (_) {}
  }

  Future<void> close() async {
    try {
      await _db.close();
    } catch (_) {}
    if (_instance == this) {
      _instance = null;
    }
  }

  /// Open or create user-partitioned SQLite database
  static Future<AppDatabase> openForUser(
    String? userId, {
    String? password,
    String? customPath,
    Database? customDb,
  }) async {
    return open(
      userId: userId,
      password: password,
      customPath: customPath,
      customDb: customDb,
    );
  }

  /// Open or create encrypted SQLite (SQLCipher AES-256) database on device
  static Future<AppDatabase> open({
    String? customPath,
    Database? customDb,
    String? password,
    String? userId,
  }) async {
    if (customDb != null) {
      await _onCreate(customDb, dbVersion);
      final instance = AppDatabase(customDb);
      _instance = instance;
      return instance;
    }

    final effectiveDbName = customPath != null
        ? p.basename(customPath)
        : getDbNameForUser(userId);
    final dbPath = customPath ?? p.join(await getDatabasesPath(), effectiveDbName);
    Database db;
    if (password != null && password.isNotEmpty) {
      try {
        db = await sqlcipher.openDatabase(
          dbPath,
          version: dbVersion,
          password: password,
          onCreate: _onCreate,
        );
      } catch (_) {
        // Fallback for test harnesses / desktop where native SQLCipher channel is unavailable
        db = await openDatabase(
          dbPath,
          version: dbVersion,
          onCreate: _onCreate,
        );
      }
    } else {
      db = await openDatabase(
        dbPath,
        version: dbVersion,
        onCreate: _onCreate,
      );
    }

    return AppDatabase(db);
  }

  /// Schema creation
  static Future<void> _onCreate(Database db, int version) async {
    // 1. Trips
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trips (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        coverImageUrl TEXT,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        defaultCurrency TEXT NOT NULL,
        budget REAL,
        shareCode TEXT,
        tripType TEXT NOT NULL,
        membersJson TEXT NOT NULL,
        createdByMemberId TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        rating REAL,
        experienceReview TEXT,
        completedAt TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_trips_startDate ON trips(startDate)');

    // 2. Stoppages
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stoppages (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        address TEXT,
        category TEXT NOT NULL,
        arrivedAt TEXT NOT NULL,
        departedAt TEXT,
        notes TEXT,
        createdBy TEXT NOT NULL,
        orderIndex INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stoppages_tripId ON stoppages(tripId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stoppages_arrivedAt ON stoppages(arrivedAt)');

    // 3. Expenses
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        stoppageId TEXT,
        title TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        currency TEXT NOT NULL,
        category TEXT NOT NULL,
        paidByMemberId TEXT NOT NULL,
        splitType TEXT NOT NULL,
        splitsJson TEXT NOT NULL,
        receiptImagePath TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_tripId ON expenses(tripId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_stoppageId ON expenses(stoppageId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_createdAt ON expenses(createdAt)');

    // 4. Memories
    await db.execute('''
      CREATE TABLE IF NOT EXISTS memories (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        stoppageId TEXT NOT NULL,
        uploadedByMemberId TEXT NOT NULL,
        mediaPath TEXT NOT NULL,
        localPath TEXT,
        remoteUrl TEXT,
        uploadStatus TEXT NOT NULL,
        caption TEXT,
        createdAt TEXT NOT NULL,
        likedByMemberIdsJson TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_memories_tripId ON memories(tripId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_memories_stoppageId ON memories(stoppageId)');

    // 5. Settlements
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settlements (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        payerMemberId TEXT NOT NULL,
        receiverMemberId TEXT NOT NULL,
        amount REAL NOT NULL,
        currency TEXT NOT NULL,
        settledAt TEXT NOT NULL,
        notes TEXT,
        paymentMethod TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_settlements_tripId ON settlements(tripId)');

    // 6. Audit Logs
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        actionType TEXT NOT NULL,
        itemTitle TEXT NOT NULL,
        performedByMemberId TEXT NOT NULL,
        performedByName TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        changeDetails TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_tripId ON audit_logs(tripId, timestamp)');

    // 7. Sync Mutations
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_mutations (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        action TEXT NOT NULL,
        entityType TEXT NOT NULL,
        entityId TEXT NOT NULL,
        payloadJson TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        status TEXT NOT NULL,
        retryCount INTEGER NOT NULL DEFAULT 0,
        errorMessage TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mutations_status ON sync_mutations(status)');

    // 8. Proximity Alerts
    await db.execute('''
      CREATE TABLE IF NOT EXISTS proximity_alerts (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        senderMemberId TEXT NOT NULL,
        senderName TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        distanceMeters REAL,
        timestamp TEXT NOT NULL,
        urgency TEXT NOT NULL,
        isRead INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_alerts_tripId ON proximity_alerts(tripId, isRead)');

    // 9. Auth Session
    await db.execute('''
      CREATE TABLE IF NOT EXISTS auth_session (
        key TEXT PRIMARY KEY,
        userJson TEXT NOT NULL
      )
    ''');

    // 10. Registered Users
    await db.execute('''
      CREATE TABLE IF NOT EXISTS registered_users (
        email TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        userRecordJson TEXT NOT NULL
      )
    ''');

    // 11. Trip Invitations
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trip_invitations (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        tripTitle TEXT NOT NULL,
        inviterId TEXT NOT NULL,
        inviterName TEXT NOT NULL,
        inviteeUsername TEXT NOT NULL,
        inviteePhone TEXT,
        createdAt TEXT NOT NULL,
        status TEXT NOT NULL,
        tripJson TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_invitations_username ON trip_invitations(inviteeUsername, status)');
  }

  // ===================== CRUD OPERATIONS =====================

  // --- TRIPS ---
  Future<List<Trip>> getTrips() async {
    final rows = await _db.query('trips', orderBy: 'startDate DESC');
    return rows.map((row) => _tripFromRow(row)).toList();
  }

  Future<void> saveTrip(Trip trip) async {
    await _db.insert(
      'trips',
      _tripToRow(trip),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveTrips(List<Trip> trips) async {
    final batch = _db.batch();
    for (final trip in trips) {
      batch.insert(
        'trips',
        _tripToRow(trip),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteTrip(String tripId) async {
    await _db.transaction((txn) async {
      await txn.delete('trips', where: 'id = ?', whereArgs: [tripId]);
      await txn.delete('stoppages', where: 'tripId = ?', whereArgs: [tripId]);
      await txn.delete('expenses', where: 'tripId = ?', whereArgs: [tripId]);
      await txn.delete('memories', where: 'tripId = ?', whereArgs: [tripId]);
      await txn.delete('settlements', where: 'tripId = ?', whereArgs: [tripId]);
      await txn.delete('audit_logs', where: 'tripId = ?', whereArgs: [tripId]);
    });
  }

  // --- STOPPAGES ---
  Future<List<Stoppage>> getStoppages(String tripId) async {
    final rows = await _db.query(
      'stoppages',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'arrivedAt ASC',
    );
    return rows.map((row) => _stoppageFromRow(row)).toList();
  }

  Future<List<Stoppage>> getAllStoppages() async {
    final rows = await _db.query('stoppages', orderBy: 'arrivedAt ASC');
    return rows.map((row) => _stoppageFromRow(row)).toList();
  }

  Future<void> saveStoppage(Stoppage stoppage) async {
    await _db.insert(
      'stoppages',
      _stoppageToRow(stoppage),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveAllStoppages(List<Stoppage> stoppages) async {
    final batch = _db.batch();
    for (final stop in stoppages) {
      batch.insert(
        'stoppages',
        _stoppageToRow(stop),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteStoppagesForTrip(String tripId) async {
    await _db.delete('stoppages', where: 'tripId = ?', whereArgs: [tripId]);
  }

  // --- EXPENSES ---
  Future<List<Expense>> getExpenses(String tripId) async {
    final rows = await _db.query(
      'expenses',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'createdAt DESC',
    );
    return rows.map((row) => _expenseFromRow(row)).toList();
  }

  Future<List<Expense>> getAllExpenses() async {
    final rows = await _db.query('expenses', orderBy: 'createdAt DESC');
    return rows.map((row) => _expenseFromRow(row)).toList();
  }

  Future<void> saveExpense(Expense expense) async {
    await _db.insert(
      'expenses',
      _expenseToRow(expense),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveAllExpenses(List<Expense> expenses) async {
    final batch = _db.batch();
    for (final expense in expenses) {
      batch.insert(
        'expenses',
        _expenseToRow(expense),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteExpensesForTrip(String tripId) async {
    await _db.delete('expenses', where: 'tripId = ?', whereArgs: [tripId]);
  }

  // --- MEMORIES ---
  Future<List<Memory>> getMemories(String tripId) async {
    final rows = await _db.query(
      'memories',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'createdAt DESC',
    );
    return rows.map((row) => _memoryFromRow(row)).toList();
  }

  Future<List<Memory>> getAllMemories() async {
    final rows = await _db.query('memories', orderBy: 'createdAt DESC');
    return rows.map((row) => _memoryFromRow(row)).toList();
  }

  Future<void> saveMemory(Memory memory) async {
    await _db.insert(
      'memories',
      _memoryToRow(memory),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveAllMemories(List<Memory> memories) async {
    final batch = _db.batch();
    for (final memory in memories) {
      batch.insert(
        'memories',
        _memoryToRow(memory),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // --- SETTLEMENTS ---
  Future<List<Settlement>> getSettlements(String tripId) async {
    final rows = await _db.query(
      'settlements',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'settledAt DESC',
    );
    return rows.map((row) => _settlementFromRow(row)).toList();
  }

  Future<List<Settlement>> getAllSettlements() async {
    final rows = await _db.query('settlements', orderBy: 'settledAt DESC');
    return rows.map((row) => _settlementFromRow(row)).toList();
  }

  Future<void> saveSettlement(Settlement settlement) async {
    await _db.insert(
      'settlements',
      _settlementToRow(settlement),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveAllSettlements(List<Settlement> settlements) async {
    final batch = _db.batch();
    for (final settlement in settlements) {
      batch.insert(
        'settlements',
        _settlementToRow(settlement),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // --- AUDIT LOGS ---
  Future<List<TripAuditLog>> getAuditLogs(String tripId) async {
    final rows = await _db.query(
      'audit_logs',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'timestamp DESC',
    );
    return rows.map((row) => _auditLogFromRow(row)).toList();
  }

  Future<List<TripAuditLog>> getAllAuditLogs() async {
    final rows = await _db.query('audit_logs', orderBy: 'timestamp DESC');
    return rows.map((row) => _auditLogFromRow(row)).toList();
  }

  Future<void> saveAuditLog(TripAuditLog log) async {
    await _db.insert(
      'audit_logs',
      _auditLogToRow(log),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveAllAuditLogs(List<TripAuditLog> logs) async {
    final batch = _db.batch();
    for (final log in logs) {
      batch.insert(
        'audit_logs',
        _auditLogToRow(log),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // --- MUTATIONS ---
  Future<List<SyncMutation>> getPendingMutations() async {
    final rows = await _db.query('sync_mutations', orderBy: 'createdAt ASC');
    return rows.map((row) => _mutationFromRow(row)).toList();
  }

  Future<void> saveMutation(SyncMutation mutation) async {
    await _db.insert(
      'sync_mutations',
      _mutationToRow(mutation),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveAllMutations(List<SyncMutation> mutations) async {
    final batch = _db.batch();
    for (final mut in mutations) {
      batch.insert(
        'sync_mutations',
        _mutationToRow(mut),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> removeMutation(String mutationId) async {
    await _db.delete('sync_mutations', where: 'id = ?', whereArgs: [mutationId]);
  }

  Future<void> clearSyncedMutations() async {
    await _db.delete('sync_mutations', where: 'status = ?', whereArgs: [SyncStatus.synced.name]);
  }

  // --- PROXIMITY ALERTS ---
  Future<List<ProximityAlert>> getAllAlerts() async {
    final rows = await _db.query('proximity_alerts', orderBy: 'timestamp DESC', limit: 100);
    return rows.map((row) => _alertFromRow(row)).toList();
  }

  Future<void> saveAlert(ProximityAlert alert) async {
    await _db.insert(
      'proximity_alerts',
      _alertToRow(alert),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveAllAlerts(List<ProximityAlert> alerts) async {
    final batch = _db.batch();
    for (final alert in alerts) {
      batch.insert(
        'proximity_alerts',
        _alertToRow(alert),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> markAlertAsRead(String alertId) async {
    await _db.update(
      'proximity_alerts',
      {'isRead': 1},
      where: 'id = ?',
      whereArgs: [alertId],
    );
  }

  Future<void> deleteAlert(String alertId) async {
    await _db.delete('proximity_alerts', where: 'id = ?', whereArgs: [alertId]);
  }

  Future<void> clearAllAlerts() async {
    await _db.delete('proximity_alerts');
  }

  // --- AUTH SESSION ---
  Future<AuthUser?> getAuthSession() async {
    final rows = await _db.query('auth_session', where: 'key = ?', whereArgs: ['current_user'], limit: 1);
    if (rows.isEmpty) return null;
    final jsonStr = rows.first['userJson'] as String;
    return AuthUser.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
  }

  Future<void> saveAuthSession(AuthUser user) async {
    await _db.insert(
      'auth_session',
      {
        'key': 'current_user',
        'userJson': jsonEncode(user.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearAuthSession() async {
    await _db.delete('auth_session', where: 'key = ?', whereArgs: ['current_user']);
  }

  // --- REGISTERED USERS ---
  Future<List<Map<String, dynamic>>> getRegisteredUsers() async {
    final rows = await _db.query('registered_users');
    return rows.map((row) {
      final jsonStr = row['userRecordJson'] as String;
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    }).toList();
  }

  Future<void> saveRegisteredUser(Map<String, dynamic> userRecord) async {
    await _db.insert(
      'registered_users',
      {
        'email': (userRecord['email'] as String).toLowerCase(),
        'username': (userRecord['username'] as String).toLowerCase(),
        'userRecordJson': jsonEncode(userRecord),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> updateRegisteredUserPassword(String email, String newPassword) async {
    final rows = await _db.query(
      'registered_users',
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return false;

    final userRecord = jsonDecode(rows.first['userRecordJson'] as String) as Map<String, dynamic>;
    userRecord['password'] = newPassword;

    await _db.update(
      'registered_users',
      {'userRecordJson': jsonEncode(userRecord)},
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );
    return true;
  }

  // --- INVITATIONS ---
  Future<List<TripInvitation>> getAllInvitations() async {
    final rows = await _db.query('trip_invitations', orderBy: 'createdAt DESC');
    return rows.map((row) => _invitationFromRow(row)).toList();
  }

  Future<void> saveInvitation(TripInvitation invitation) async {
    await _db.insert(
      'trip_invitations',
      _invitationToRow(invitation),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateInvitationStatus(String invitationId, InvitationStatus status) async {
    await _db.update(
      'trip_invitations',
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [invitationId],
    );
  }

  Future<void> deleteInvitation(String invitationId) async {
    await _db.delete('trip_invitations', where: 'id = ?', whereArgs: [invitationId]);
  }

  Future<void> deleteStoppage(String stoppageId) async {
    await _db.delete('stoppages', where: 'id = ?', whereArgs: [stoppageId]);
  }

  Future<void> deleteExpense(String expenseId) async {
    await _db.delete('expenses', where: 'id = ?', whereArgs: [expenseId]);
  }

  Future<void> deleteMemory(String memoryId) async {
    await _db.delete('memories', where: 'id = ?', whereArgs: [memoryId]);
  }

  Future<void> deleteSettlement(String settlementId) async {
    await _db.delete('settlements', where: 'id = ?', whereArgs: [settlementId]);
  }

  // --- TRANSACTION HELPER ---
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) {
    return _db.transaction(action);
  }

  // ===================== ROW MAPPERS =====================

  Map<String, dynamic> _tripToRow(Trip t) => {
    'id': t.id,
    'title': t.title,
    'description': t.description,
    'coverImageUrl': t.coverImageUrl,
    'startDate': t.startDate.toIso8601String(),
    'endDate': t.endDate.toIso8601String(),
    'defaultCurrency': t.defaultCurrency,
    'budget': t.budget,
    'shareCode': t.shareCode,
    'tripType': t.tripType,
    'membersJson': jsonEncode(t.members.map((m) => m.toJson()).toList()),
    'createdByMemberId': t.createdByMemberId,
    'createdAt': t.createdAt.toIso8601String(),
    'isCompleted': t.isCompleted ? 1 : 0,
    'rating': t.rating,
    'experienceReview': t.experienceReview,
    'completedAt': t.completedAt?.toIso8601String(),
  };

  Trip _tripFromRow(Map<String, dynamic> r) {
    final membersRaw = jsonDecode(r['membersJson'] as String) as List<dynamic>;
    return Trip(
      id: r['id'] as String,
      title: r['title'] as String,
      description: r['description'] as String?,
      coverImageUrl: r['coverImageUrl'] as String?,
      startDate: DateTime.parse(r['startDate'] as String),
      endDate: DateTime.parse(r['endDate'] as String),
      defaultCurrency: r['defaultCurrency'] as String? ?? 'USD',
      budget: (r['budget'] as num?)?.toDouble(),
      shareCode: r['shareCode'] as String?,
      tripType: r['tripType'] as String? ?? 'group',
      members: membersRaw.map((m) => TripMember.fromJson(m as Map<String, dynamic>)).toList(),
      createdByMemberId: r['createdByMemberId'] as String? ?? '',
      createdAt: DateTime.parse(r['createdAt'] as String),
      isCompleted: (r['isCompleted'] as int) == 1,
      rating: (r['rating'] as num?)?.toDouble(),
      experienceReview: r['experienceReview'] as String?,
      completedAt: r['completedAt'] != null ? DateTime.parse(r['completedAt'] as String) : null,
    );
  }

  Map<String, dynamic> _stoppageToRow(Stoppage s) => {
    'id': s.id,
    'tripId': s.tripId,
    'name': s.name,
    'latitude': s.latitude,
    'longitude': s.longitude,
    'address': s.address,
    'category': s.category,
    'arrivedAt': s.arrivedAt.toIso8601String(),
    'departedAt': s.departedAt?.toIso8601String(),
    'notes': s.notes,
    'createdBy': s.createdBy,
    'orderIndex': s.orderIndex,
  };

  Stoppage _stoppageFromRow(Map<String, dynamic> r) => Stoppage(
    id: r['id'] as String,
    tripId: r['tripId'] as String,
    name: r['name'] as String,
    latitude: (r['latitude'] as num).toDouble(),
    longitude: (r['longitude'] as num).toDouble(),
    address: r['address'] as String?,
    category: r['category'] as String,
    arrivedAt: DateTime.parse(r['arrivedAt'] as String),
    departedAt: r['departedAt'] != null ? DateTime.parse(r['departedAt'] as String) : null,
    notes: r['notes'] as String?,
    createdBy: r['createdBy'] as String,
    orderIndex: r['orderIndex'] as int,
  );

  Map<String, dynamic> _expenseToRow(Expense e) => {
    'id': e.id,
    'tripId': e.tripId,
    'stoppageId': e.stoppageId,
    'title': e.title,
    'totalAmount': e.totalAmount,
    'currency': e.currency,
    'category': e.category,
    'paidByMemberId': e.paidByMemberId,
    'splitType': e.splitType.name,
    'splitsJson': jsonEncode(e.splits.map((s) => s.toJson()).toList()),
    'receiptImagePath': e.receiptImagePath,
    'notes': e.notes,
    'createdAt': e.createdAt.toIso8601String(),
  };

  Expense _expenseFromRow(Map<String, dynamic> r) => Expense(
    id: r['id'] as String,
    tripId: r['tripId'] as String,
    stoppageId: r['stoppageId'] as String?,
    title: r['title'] as String,
    totalAmount: (r['totalAmount'] as num).toDouble(),
    currency: r['currency'] as String,
    category: r['category'] as String,
    paidByMemberId: r['paidByMemberId'] as String,
    splitType: SplitType.values.firstWhere((st) => st.name == r['splitType'], orElse: () => SplitType.equal),
    splits: (jsonDecode(r['splitsJson'] as String) as List<dynamic>)
        .map((s) => ExpenseSplit.fromJson(s as Map<String, dynamic>))
        .toList(),
    receiptImagePath: r['receiptImagePath'] as String?,
    notes: r['notes'] as String?,
    createdAt: DateTime.parse(r['createdAt'] as String),
  );

  Map<String, dynamic> _memoryToRow(Memory m) => {
    'id': m.id,
    'tripId': m.tripId,
    'stoppageId': m.stoppageId,
    'uploadedByMemberId': m.uploadedByMemberId,
    'mediaPath': m.mediaPath,
    'localPath': m.localPath,
    'remoteUrl': m.remoteUrl,
    'uploadStatus': m.uploadStatus.name,
    'caption': m.caption,
    'createdAt': m.createdAt.toIso8601String(),
    'likedByMemberIdsJson': jsonEncode(m.likedByMemberIds),
  };

  Memory _memoryFromRow(Map<String, dynamic> r) => Memory(
    id: r['id'] as String,
    tripId: r['tripId'] as String,
    stoppageId: r['stoppageId'] as String,
    uploadedByMemberId: r['uploadedByMemberId'] as String,
    mediaPath: r['mediaPath'] as String,
    localPath: r['localPath'] as String?,
    remoteUrl: r['remoteUrl'] as String?,
    uploadStatus: MediaUploadStatus.values.firstWhere(
      (us) => us.name == r['uploadStatus'],
      orElse: () => MediaUploadStatus.local,
    ),
    caption: r['caption'] as String?,
    createdAt: DateTime.parse(r['createdAt'] as String),
    likedByMemberIds: (jsonDecode(r['likedByMemberIdsJson'] as String) as List<dynamic>).cast<String>(),
  );

  Map<String, dynamic> _settlementToRow(Settlement s) => {
    'id': s.id,
    'tripId': s.tripId,
    'payerMemberId': s.payerMemberId,
    'receiverMemberId': s.receiverMemberId,
    'amount': s.amount,
    'currency': s.currency,
    'settledAt': s.settledAt.toIso8601String(),
    'notes': s.notes,
    'paymentMethod': s.paymentMethod,
  };

  Settlement _settlementFromRow(Map<String, dynamic> r) => Settlement(
    id: r['id'] as String,
    tripId: r['tripId'] as String,
    payerMemberId: r['payerMemberId'] as String,
    receiverMemberId: r['receiverMemberId'] as String,
    amount: (r['amount'] as num).toDouble(),
    currency: r['currency'] as String,
    settledAt: DateTime.parse(r['settledAt'] as String),
    notes: r['notes'] as String?,
    paymentMethod: r['paymentMethod'] as String? ?? 'Cash',
  );

  Map<String, dynamic> _auditLogToRow(TripAuditLog a) => {
    'id': a.id,
    'tripId': a.tripId,
    'actionType': a.actionType,
    'itemTitle': a.itemTitle,
    'performedByMemberId': a.performedByMemberId,
    'performedByName': a.performedByName,
    'timestamp': a.timestamp.toIso8601String(),
    'changeDetails': a.changeDetails,
  };

  TripAuditLog _auditLogFromRow(Map<String, dynamic> r) => TripAuditLog(
    id: r['id'] as String,
    tripId: r['tripId'] as String,
    actionType: r['actionType'] as String,
    itemTitle: r['itemTitle'] as String,
    performedByMemberId: r['performedByMemberId'] as String,
    performedByName: r['performedByName'] as String,
    timestamp: DateTime.parse(r['timestamp'] as String),
    changeDetails: r['changeDetails'] as String,
  );

  Map<String, dynamic> _mutationToRow(SyncMutation m) => {
    'id': m.id,
    'tripId': m.tripId,
    'action': m.action.name,
    'entityType': m.entityType,
    'entityId': m.entityId,
    'payloadJson': jsonEncode(m.payload),
    'createdAt': m.createdAt.toIso8601String(),
    'status': m.status.name,
    'retryCount': m.retryCount,
    'errorMessage': m.errorMessage,
  };

  SyncMutation _mutationFromRow(Map<String, dynamic> r) => SyncMutation(
    id: r['id'] as String,
    tripId: r['tripId'] as String,
    action: MutationAction.values.firstWhere((a) => a.name == r['action'], orElse: () => MutationAction.createTrip),
    entityType: r['entityType'] as String,
    entityId: r['entityId'] as String,
    payload: jsonDecode(r['payloadJson'] as String) as Map<String, dynamic>,
    createdAt: DateTime.parse(r['createdAt'] as String),
    status: SyncStatus.values.firstWhere((s) => s.name == r['status'], orElse: () => SyncStatus.pending),
    retryCount: r['retryCount'] as int? ?? 0,
    errorMessage: r['errorMessage'] as String?,
  );

  Map<String, dynamic> _alertToRow(ProximityAlert a) => {
    'id': a.id,
    'tripId': a.tripId,
    'type': a.type.name,
    'title': a.title,
    'message': a.message,
    'senderMemberId': a.senderMemberId,
    'senderName': a.senderName,
    'latitude': a.latitude,
    'longitude': a.longitude,
    'distanceMeters': a.distanceMeters,
    'timestamp': a.timestamp.toIso8601String(),
    'urgency': a.urgency.name,
    'isRead': a.isRead ? 1 : 0,
  };

  ProximityAlert _alertFromRow(Map<String, dynamic> r) => ProximityAlert(
    id: r['id'] as String,
    tripId: r['tripId'] as String,
    type: AlertType.values.firstWhere((t) => t.name == r['type'], orElse: () => AlertType.general),
    title: r['title'] as String,
    message: r['message'] as String,
    senderMemberId: r['senderMemberId'] as String,
    senderName: r['senderName'] as String,
    latitude: (r['latitude'] as num?)?.toDouble(),
    longitude: (r['longitude'] as num?)?.toDouble(),
    distanceMeters: (r['distanceMeters'] as num?)?.toDouble(),
    timestamp: DateTime.parse(r['timestamp'] as String),
    urgency: AlertUrgency.values.firstWhere((u) => u.name == r['urgency'], orElse: () => AlertUrgency.normal),
    isRead: (r['isRead'] as int) == 1,
  );

  Map<String, dynamic> _invitationToRow(TripInvitation i) => {
    'id': i.id,
    'tripId': i.tripId,
    'tripTitle': i.tripTitle,
    'inviterId': i.inviterId,
    'inviterName': i.inviterName,
    'inviteeUsername': i.inviteeUsername,
    'inviteePhone': i.inviteePhone,
    'createdAt': i.createdAt.toIso8601String(),
    'status': i.status.name,
    'tripJson': i.tripJson != null ? jsonEncode(i.tripJson) : null,
  };

  TripInvitation _invitationFromRow(Map<String, dynamic> r) => TripInvitation(
    id: r['id'] as String,
    tripId: r['tripId'] as String,
    tripTitle: r['tripTitle'] as String,
    inviterId: r['inviterId'] as String,
    inviterName: r['inviterName'] as String,
    inviteeUsername: r['inviteeUsername'] as String,
    inviteePhone: r['inviteePhone'] as String?,
    createdAt: DateTime.parse(r['createdAt'] as String),
    status: InvitationStatus.values.firstWhere((s) => s.name == r['status'], orElse: () => InvitationStatus.pending),
    tripJson: r['tripJson'] != null ? jsonDecode(r['tripJson'] as String) as Map<String, dynamic> : null,
  );

  /// Forensically wipes all tables and entries from the local database
  Future<void> wipeDatabase() async {
    final tables = [
      'trips',
      'stoppages',
      'expenses',
      'memories',
      'settlements',
      'audit_logs',
      'sync_mutations',
      'proximity_alerts',
      'auth_session',
      'registered_users',
      'trip_invitations',
    ];
    for (final table in tables) {
      try {
        await _db.delete(table);
      } catch (_) {}
    }
  }
}
