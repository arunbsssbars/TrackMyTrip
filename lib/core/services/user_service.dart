import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_profile.dart';

class UserService {
  // Pre-populated directory of mock companion users for local & cloud testing
  static final List<UserProfile> _mockDirectory = [
    const UserProfile(
      id: 'usr_sarah_101',
      username: 'sarah_travels',
      displayName: 'Sarah Jenkins',
      email: 'sarah.j@example.com',
      phone: '+1 (555) 234-5678',
      colorHex: '0xFFEC4899', // Pink
      bio: 'Mountain hiker, road trip enthusiast & amateur photographer 🏔️',
      latitude: 37.7749,
      longitude: -122.4194,
    ),
    const UserProfile(
      id: 'usr_mike_102',
      username: 'mike_trekker',
      displayName: 'Mike Chen',
      email: 'mike.chen@example.com',
      phone: '+1 (555) 345-6789',
      colorHex: '0xFF3B82F6', // Blue
      bio: 'Always seeking the next scenic route and best local coffee ☕',
      latitude: 37.7849,
      longitude: -122.4094,
    ),
    const UserProfile(
      id: 'usr_elena_103',
      username: 'elena_hikes',
      displayName: 'Elena Rostova',
      email: 'elena.r@example.com',
      phone: '+1 (555) 456-7890',
      colorHex: '0xFF10B981', // Emerald
      bio: 'Campfire storyteller, navigator, foodie ⛺',
      latitude: 37.7649,
      longitude: -122.4294,
    ),
    const UserProfile(
      id: 'usr_alex_104',
      username: 'alex_explorer',
      displayName: 'Alex Morgan',
      email: 'alex.m@example.com',
      phone: '+1 (555) 567-8901',
      colorHex: '0xFFF59E0B', // Amber
      bio: 'National Parks explorer & drone videographer 🚁',
      latitude: 37.7949,
      longitude: -122.4394,
    ),
    const UserProfile(
      id: 'usr_priya_105',
      username: 'priya_wanderer',
      displayName: 'Priya Sharma',
      email: 'priya.s@example.com',
      phone: '+1 (555) 678-9012',
      colorHex: '0xFF8B5CF6', // Purple
      bio: 'Weekend road-tripper & budget master 🚗💨',
      latitude: 37.7549,
      longitude: -122.3994,
    ),
  ];

  static UserProfile _currentUser = const UserProfile(
    id: 'usr_me_001',
    username: 'traveler_me',
    displayName: 'You (Trip Lead)',
    email: 'me@triptracker.app',
    colorHex: '0xFF0D9488', // Teal
    bio: 'Explorer & Trip Planner',
  );

  static UserProfile getCurrentUser() => _currentUser;

  static void updateCurrentUser(UserProfile updated) {
    _currentUser = updated;
  }

  /// Searches for companions matching a query by @username, display name, email, or mobile number
  static Future<List<UserProfile>> searchUsers(String query) async {
    final cleanQuery = query.trim().toLowerCase().replaceAll('@', '');
    if (cleanQuery.isEmpty) {
      return List.unmodifiable(_mockDirectory);
    }

    // Extract digits for phone number matching
    final digitsQuery = cleanQuery.replaceAll(RegExp(r'\D'), '');

    // Simulate fast local network search
    await Future.delayed(const Duration(milliseconds: 60));

    return _mockDirectory.where((user) {
      final matchUsername = user.username.toLowerCase().contains(cleanQuery);
      final matchName = user.displayName.toLowerCase().contains(cleanQuery);
      final matchEmail = user.email?.toLowerCase().contains(cleanQuery) ?? false;

      final cleanPhone = user.phone?.replaceAll(RegExp(r'\D'), '') ?? '';
      final matchPhone = (user.phone != null && user.phone!.toLowerCase().contains(cleanQuery)) ||
          (digitsQuery.length >= 3 && cleanPhone.contains(digitsQuery));

      return matchUsername || matchName || matchEmail || matchPhone;
    }).toList();
  }

  /// Finds a specific user by their ID
  static UserProfile? findUserById(String id) {
    if (id == _currentUser.id) return _currentUser;
    try {
      return _mockDirectory.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Adds a newly created custom companion user to the local directory
  static void registerUser(UserProfile newUser) {
    if (!_mockDirectory.any((u) => u.id == newUser.id || u.username == newUser.username)) {
      _mockDirectory.add(newUser);
    }
  }
}

final userSearchProvider = FutureProvider.autoDispose.family<List<UserProfile>, String>((ref, query) async {
  return UserService.searchUsers(query);
});

final currentUserProvider = StateProvider<UserProfile>((ref) {
  return UserService.getCurrentUser();
});
