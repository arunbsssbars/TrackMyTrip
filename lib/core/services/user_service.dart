import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../../models/user_profile.dart';

class UserService {
  static FirebaseFirestore? _customDb;
  static set customDb(FirebaseFirestore? db) => _customDb = db;
  static FirebaseFirestore? get _firestore {
    if (_customDb != null) return _customDb;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  // Real registered users and companions in the current app session
  static final List<UserProfile> _registeredUsers = [];

  static UserProfile _currentUser = const UserProfile(
    id: 'usr_me',
    username: 'traveler',
    displayName: 'Traveler',
    email: null,
    colorHex: '0xFF0D9488',
    bio: null,
  );

  // Cache of user profiles resolved across app sessions and searches
  static final Map<String, UserProfile> _cachedUsers = {};

  static UserProfile getCurrentUser() => _currentUser;

  static UserProfile? getUserById(String id) {
    if (_currentUser.id == id) return _currentUser;
    return _cachedUsers[id] ?? _registeredUsers.where((u) => u.id == id).firstOrNull;
  }

  static Future<UserProfile?> fetchUserProfile(String id, {bool forceRefresh = false}) async {
    final local = getUserById(id);
    if (!forceRefresh) {
      if (local != null && local.displayName != 'Traveler' && (local.phone != null || local.bio != null)) return local;
    }
    try {
      final fs = _firestore;
      if (fs != null) {
        final doc = await fs.collection('users').doc(id).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final username = (data['username'] as String? ?? 'user').trim();
          final displayName = (data['displayName'] as String? ?? data['name'] as String? ?? username).trim();
          final profile = UserProfile(
            id: id,
            username: username.isNotEmpty ? username : 'user',
            displayName: displayName.isNotEmpty ? displayName : 'Traveler',
            email: data['email'] as String?,
            phone: data['phone'] as String?,
            colorHex: data['colorHex'] as String? ?? '0xFF3B82F6',
            bio: (data['bio'] as String?)?.trim().isNotEmpty == true ? (data['bio'] as String).trim() : null,
            avatarUrl: data['avatarUrl'] as String?,
          );
          _cachedUsers[id] = profile;
          return profile;
        }
      }
    } catch (_) {}
    return local;
  }

  static void updateCurrentUser(UserProfile updated) {
    _currentUser = updated;
    _cachedUsers[updated.id] = updated;
    if (!_registeredUsers.any((u) => u.id == updated.id)) {
      _registeredUsers.add(updated);
    }
  }

  static void resetCurrentUser() {
    _currentUser = const UserProfile(
      id: 'usr_me',
      username: 'traveler',
      displayName: 'Traveler',
      email: null,
      colorHex: '0xFF0D9488',
      bio: null,
    );
    _registeredUsers.clear();
    _cachedUsers.clear();
  }

  /// Generates full tokens and partial prefixes for flexible matching (capped to 20 for storage efficiency)
  static Set<String> generateSearchTokens({
    required String username,
    required String displayName,
    required String? email,
    String? phone,
  }) {
    final tokens = <String>{};
    final u = username.toLowerCase().trim();
    if (u.isNotEmpty) {
      tokens.add(u);
      for (int i = 2; i <= u.length && tokens.length < 8; i++) {
        tokens.add(u.substring(0, i));
      }
    }

    final d = displayName.toLowerCase().trim();
    if (d.isNotEmpty && d != u) {
      tokens.add(d);
      for (final word in d.split(' ')) {
        final w = word.trim();
        if (w.length >= 2 && tokens.length < 14) {
          tokens.add(w);
          if (w.length > 3 && tokens.length < 14) {
            tokens.add(w.substring(0, 3));
          }
        }
      }
    }

    if (email != null && email.trim().isNotEmpty) {
      final e = email.toLowerCase().trim();
      final ePrefix = e.split('@').first;
      if (ePrefix.isNotEmpty && tokens.length < 18) {
        tokens.add(ePrefix);
      }
    }

    if (phone != null && phone.trim().isNotEmpty) {
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 4 && tokens.length < 20) {
        tokens.add(digits);
        if (digits.length >= 10 && tokens.length < 20) {
          tokens.add(digits.substring(digits.length - 4)); // last 4 digits
        }
      }
    }

    return tokens.take(20).toSet();
  }

  /// Gets suggested / recent companions from previous trips and local database
  static Future<List<UserProfile>> getSuggestedUsers() async {
    final currentUserId = _currentUser.id;
    String? fbUid;
    String? fbEmail;
    try {
      fbUid = FirebaseAuth.instance.currentUser?.uid;
      fbEmail = FirebaseAuth.instance.currentUser?.email;
    } catch (_) {}
    final currentUserEmail = (_currentUser.email ?? fbEmail)?.toLowerCase().trim();
    final currentUsername = _currentUser.username.toLowerCase().trim();

    final Map<String, UserProfile> suggested = {};

    try {
      final db = AppDatabase.instance;
      if (db != null) {
        // 1. Companions from existing trips
        final trips = await db.getTrips();
        for (final trip in trips) {
          for (final m in trip.members) {
            final id = m.id;
            final email = m.email?.toLowerCase().trim();
            final username = m.name.toLowerCase().replaceAll(' ', '_');

            if (id.startsWith('custom_') ||
                id.startsWith('offline_') ||
                id.startsWith('member_') ||
                email == null ||
                email.isEmpty) {
              continue;
            }

            if (id == currentUserId ||
                (fbUid != null && id == fbUid) ||
                (currentUserEmail != null && email == currentUserEmail) ||
                (currentUsername.isNotEmpty && username == currentUsername)) {
              continue;
            }

            suggested.putIfAbsent(
              id,
              () => UserProfile(
                id: id,
                username: username,
                displayName: m.name.isNotEmpty ? m.name : 'Traveler',
                email: m.email,
                colorHex: m.colorHex ?? '0xFF0D9488',
                bio: 'Companion in ${trip.title}',
                avatarUrl: m.avatarUrl,
              ),
            );
          }
        }

        // 2. Locally registered users
        final localDbUsers = await db.getRegisteredUsers();
        for (final rec in localDbUsers) {
          final id = rec['id'] as String? ?? rec['email'] as String? ?? '';
          final email = (rec['email'] as String?)?.toLowerCase().trim();
          final username = (rec['username'] as String? ?? '').toLowerCase().trim();
          final displayName = (rec['name'] as String? ?? rec['displayName'] as String? ?? username).trim();

          if (id.isEmpty ||
              id == currentUserId ||
              (fbUid != null && id == fbUid) ||
              (currentUserEmail != null && email == currentUserEmail) ||
              (currentUsername.isNotEmpty && username == currentUsername)) {
            continue;
          }

          suggested.putIfAbsent(
            id,
            () => UserProfile(
              id: id,
              username: username.isNotEmpty ? username : 'user',
              displayName: displayName.isNotEmpty ? displayName : 'Traveler',
              email: rec['email'] as String?,
              phone: rec['phone'] as String?,
              colorHex: rec['colorHex'] as String? ?? '0xFF10B981',
              bio: (rec['bio'] as String?)?.trim().isNotEmpty == true ? (rec['bio'] as String).trim() : null,
              avatarUrl: rec['avatarUrl'] as String?,
            ),
          );
        }
      }
    } catch (_) {}

    // 3. In-memory registered users
    for (final u in _registeredUsers) {
      if (u.id == currentUserId ||
          (currentUserEmail != null && u.email?.toLowerCase().trim() == currentUserEmail) ||
          (currentUsername.isNotEmpty && u.username.toLowerCase().trim() == currentUsername)) {
        continue;
      }
      suggested.putIfAbsent(u.id, () => u);
    }

    return suggested.values.take(15).toList();
  }

  /// Searches for companions matching a query by @username, display name, email, or mobile number
  static Future<List<UserProfile>> searchUsers(String query) async {
    final rawTrimmed = query.trim();
    final rawLower = rawTrimmed.toLowerCase();
    if (rawLower.length < 2) {
      return [];
    }

    final currentUserId = _currentUser.id;
    String? fbUid;
    String? fbEmail;
    try {
      fbUid = FirebaseAuth.instance.currentUser?.uid;
      fbEmail = FirebaseAuth.instance.currentUser?.email;
    } catch (_) {}
    final currentUserEmail = (_currentUser.email ?? fbEmail)?.toLowerCase().trim();
    final currentUsername = _currentUser.username.toLowerCase().trim();

    final isEmailQuery = rawLower.contains('@');
    final usernameQuery = rawLower.startsWith('@') ? rawLower.substring(1).trim() : rawLower;
    final cleanQuery = usernameQuery.replaceAll('@', '');
    final digitsQuery = rawLower.replaceAll(RegExp(r'\D'), '');

    final Map<String, UserProfile> combined = {};

    void parseUserDocs(QuerySnapshot<Map<String, dynamic>> snap) {
      for (final doc in snap.docs) {
        final data = doc.data();
        final id = doc.id;
        final email = (data['email'] as String?)?.toLowerCase().trim();
        final username = (data['username'] as String? ?? '').toLowerCase().trim();
        final displayName = (data['displayName'] as String? ?? data['name'] as String? ?? username).trim();

        // Never show own account in search results
        if (id == currentUserId ||
            (fbUid != null && id == fbUid) ||
            (currentUserEmail != null && email == currentUserEmail) ||
            (currentUsername.isNotEmpty && username == currentUsername)) {
          continue;
        }

        final profile = UserProfile(
          id: id,
          username: username.isNotEmpty ? username : 'user',
          displayName: displayName.isNotEmpty ? displayName : 'Traveler',
          email: data['email'] as String?,
          phone: data['phone'] as String?,
          colorHex: data['colorHex'] as String? ?? '0xFF3B82F6',
          bio: (data['bio'] as String?)?.trim().isNotEmpty == true ? (data['bio'] as String).trim() : null,
          avatarUrl: data['avatarUrl'] as String?,
        );
        combined[id] = profile;
        _cachedUsers[id] = profile;
      }
    }

    // 1. Fetch from Firestore users collection
    final fs = _firestore;
    if (fs != null) {
      final usersRef = fs.collection('users');

      // (A) Search tokens array query
      try {
        final snap = await usersRef.where('searchTokens', arrayContains: cleanQuery).limit(25).get();
        parseUserDocs(snap);
      } catch (_) {}

      // (B) Email direct / prefix query if '@' present
      if (isEmailQuery) {
        try {
          final snap = await usersRef.where('email', isEqualTo: rawLower).limit(5).get();
          parseUserDocs(snap);
        } catch (_) {}
        try {
          final snap = await usersRef
              .where('email', isGreaterThanOrEqualTo: rawLower)
              .where('email', isLessThan: '$rawLower\uf8ff')
              .limit(15)
              .get();
          parseUserDocs(snap);
        } catch (_) {}
      } else {
        // (C) Username prefix range query
        try {
          final snap = await usersRef
              .where('username', isGreaterThanOrEqualTo: cleanQuery)
              .where('username', isLessThan: '$cleanQuery\uf8ff')
              .limit(15)
              .get();
          parseUserDocs(snap);
        } catch (_) {}
      }

      // (D) Broad scan fallback for phone and substring matches
      try {
        final broadSnap = await usersRef.limit(100).get();
        for (final doc in broadSnap.docs) {
          final data = doc.data();
          final id = doc.id;
          final email = (data['email'] as String?)?.toLowerCase().trim();
          final username = (data['username'] as String? ?? '').toLowerCase().trim();
          final displayName = (data['displayName'] as String? ?? data['name'] as String? ?? username).trim();
          final phone = (data['phone'] as String? ?? '').replaceAll(RegExp(r'\D'), '');

          if (id == currentUserId ||
              (fbUid != null && id == fbUid) ||
              (currentUserEmail != null && email == currentUserEmail) ||
              (currentUsername.isNotEmpty && username == currentUsername)) {
            continue;
          }

          final matchName = displayName.toLowerCase().contains(cleanQuery);
          final matchUser = username.contains(cleanQuery);
          final matchEmail = email != null && (email.contains(cleanQuery) || (isEmailQuery && email.contains(rawLower)));
          final matchPhone = digitsQuery.length >= 3 && phone.contains(digitsQuery);

          if (matchName || matchUser || matchEmail || matchPhone) {
            final profile = UserProfile(
              id: id,
              username: username.isNotEmpty ? username : 'user',
              displayName: displayName.isNotEmpty ? displayName : 'Traveler',
              email: data['email'] as String?,
              phone: data['phone'] as String?,
              colorHex: data['colorHex'] as String? ?? '0xFF3B82F6',
              bio: (data['bio'] as String?)?.trim().isNotEmpty == true ? (data['bio'] as String).trim() : null,
              avatarUrl: data['avatarUrl'] as String?,
            );
            combined[id] = profile;
            _cachedUsers[id] = profile;
          }
        }
      } catch (_) {}
    }

    // 2. Fetch locally registered accounts from SQLite database
    try {
      final db = AppDatabase.instance;
      if (db != null) {
        final localDbUsers = await db.getRegisteredUsers();
        for (final rec in localDbUsers) {
          final id = rec['id'] as String? ?? rec['email'] as String? ?? '';
          final email = (rec['email'] as String?)?.toLowerCase().trim();
          final username = (rec['username'] as String? ?? '').toLowerCase().trim();
          final displayName = (rec['name'] as String? ?? rec['displayName'] as String? ?? username).trim();
          final phone = (rec['phone'] as String?)?.replaceAll(RegExp(r'\D'), '');

          if (id.isEmpty ||
              id == currentUserId ||
              (currentUserEmail != null && email == currentUserEmail) ||
              (currentUsername.isNotEmpty && username == currentUsername)) {
            continue;
          }

          final matchName = displayName.toLowerCase().contains(cleanQuery);
          final matchUser = username.contains(cleanQuery);
          final matchEmail = email != null && (email.contains(cleanQuery) || (isEmailQuery && email.contains(rawLower)));
          final matchPhone = digitsQuery.length >= 3 && phone != null && phone.contains(digitsQuery);

          if (matchName || matchUser || matchEmail || matchPhone) {
            combined[id] = UserProfile(
              id: id,
              username: username.isNotEmpty ? username : 'user',
              displayName: displayName.isNotEmpty ? displayName : 'Traveler',
              email: email,
              phone: rec['phone'] as String?,
              colorHex: rec['colorHex'] as String? ?? '0xFF10B981',
              bio: (rec['bio'] as String?)?.trim().isNotEmpty == true ? (rec['bio'] as String).trim() : null,
              avatarUrl: rec['avatarUrl'] as String?,
            );
          }
        }
      }
    } catch (_) {}

    // 3. Harvest members from existing local trips in SQLite
    try {
      final db = AppDatabase.instance;
      if (db != null) {
        final trips = await db.getTrips();
        for (final trip in trips) {
          for (final m in trip.members) {
            final id = m.id;
            final name = m.name.trim();
            final email = m.email?.toLowerCase().trim();
            final username = name.toLowerCase().replaceAll(' ', '_');

            if (id.startsWith('custom_') ||
                id.startsWith('offline_') ||
                id.startsWith('member_') ||
                email == null ||
                email.isEmpty) {
              continue;
            }

            if (id == currentUserId ||
                (currentUserEmail != null && email == currentUserEmail) ||
                (currentUsername.isNotEmpty && username == currentUsername)) {
              continue;
            }

            final matchName = name.toLowerCase().contains(cleanQuery);
            final matchEmail = email.contains(cleanQuery) || (isEmailQuery && email.contains(rawLower));
            final matchUser = username.contains(cleanQuery);

            if (matchName || matchEmail || matchUser) {
              combined.putIfAbsent(
                id,
                () => UserProfile(
                  id: id,
                  username: username,
                  displayName: name.isNotEmpty ? name : 'Traveler',
                  email: email,
                  colorHex: m.colorHex ?? '0xFF0D9488',
                  bio: 'Trip member in ${trip.title}',
                  avatarUrl: m.avatarUrl,
                ),
              );
            }
          }
        }
      }
    } catch (_) {}

    // 4. Include any in-memory directory users
    for (final local in _registeredUsers) {
      if (local.id == currentUserId ||
          (currentUserEmail != null && local.email?.toLowerCase().trim() == currentUserEmail) ||
          (currentUsername.isNotEmpty && local.username.toLowerCase().trim() == currentUsername)) {
        continue;
      }
      final matchUsername = local.username.toLowerCase().contains(cleanQuery);
      final matchName = local.displayName.toLowerCase().contains(cleanQuery);
      final matchEmail = local.email?.toLowerCase().contains(rawLower) ?? false;
      final cleanPhone = local.phone?.replaceAll(RegExp(r'\D'), '') ?? '';
      final matchPhone = (local.phone != null && local.phone!.toLowerCase().contains(cleanQuery)) ||
          (digitsQuery.length >= 3 && cleanPhone.contains(digitsQuery));

      if (matchUsername || matchName || matchEmail || matchPhone) {
        combined.putIfAbsent(local.id, () => local);
      }
    }

    return combined.values.toList();
  }

  /// Finds a specific user by their ID
  static UserProfile? findUserById(String id) {
    if (id == _currentUser.id) return _currentUser;
    try {
      return _registeredUsers.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Checks if a username handle is uniquely available in SQLite and Cloud Firestore
  static Future<bool> isUsernameAvailable(String username, {String? excludeUserId}) async {
    final clean = username.trim().toLowerCase().replaceAll('@', '');
    if (clean.length < 3) return false;

    // Disallow reserved handles
    if (clean == 'admin' || clean == 'traveler' || clean == 'support') return false;

    // 1. Check local registered users in SQLite
    try {
      final db = AppDatabase.instance;
      if (db != null) {
        final localUsers = await db.getRegisteredUsers();
        for (final u in localUsers) {
          final id = u['id'] as String? ?? u['email'] as String? ?? '';
          final un = (u['username'] as String? ?? '').toLowerCase().trim();
          if (id != excludeUserId && un == clean) {
            return false;
          }
        }
      }
    } catch (_) {}

    // 2. Check in-memory session registry
    for (final u in _registeredUsers) {
      if (u.id != excludeUserId && u.username.toLowerCase().trim() == clean) {
        return false;
      }
    }

    // 3. Check Cloud Firestore users collection
    final fs = _firestore;
    if (fs != null) {
      try {
        final snap = await fs
            .collection('users')
            .where('username', isEqualTo: clean)
            .limit(3)
            .get();
        for (final doc in snap.docs) {
          if (doc.id != excludeUserId) {
            return false;
          }
        }
      } catch (_) {}
    }

    return true;
  }

  /// Adds a newly created custom companion user to the local directory and Firestore
  static void registerUser(UserProfile newUser) {
    if (!_registeredUsers.any((u) => u.id == newUser.id || u.username == newUser.username)) {
      _registeredUsers.add(newUser);
    }
    try {
      final fs = _firestore;
      if (fs != null) {
        final searchTokens = generateSearchTokens(
          username: newUser.username,
          displayName: newUser.displayName,
          email: newUser.email,
          phone: newUser.phone,
        );
        fs.collection('users').doc(newUser.id).set({
          'id': newUser.id,
          'username': newUser.username.toLowerCase(),
          'displayName': newUser.displayName,
          'email': newUser.email?.toLowerCase(),
          'phone': newUser.phone,
          'bio': newUser.bio,
          'colorHex': newUser.colorHex,
          'searchTokens': searchTokens.toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }
}

final userSearchProvider = FutureProvider.autoDispose.family<List<UserProfile>, String>((ref, query) async {
  if (query.trim().length < 2) {
    return UserService.getSuggestedUsers();
  }
  return UserService.searchUsers(query);
});

final currentUserProvider = StateProvider<UserProfile>((ref) {
  return UserService.getCurrentUser();
});
