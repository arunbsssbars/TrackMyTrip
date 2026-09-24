import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../models/user_profile.dart';

class UserProfileSheet extends ConsumerStatefulWidget {
  const UserProfileSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const UserProfileSheet(),
    );
  }

  @override
  ConsumerState<UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends ConsumerState<UserProfileSheet> {
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _emailController;
  bool _isSigningOut = false;
  bool _isSaving = false;

  Timer? _debounceTimer;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String? _usernameFeedback;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    final user = UserService.getCurrentUser();
    _nameController = TextEditingController(text: user.displayName != 'Traveler' ? user.displayName : '');
    _usernameController = TextEditingController(text: user.username != 'traveler' ? user.username.replaceAll('@', '') : '');
    _bioController = TextEditingController(text: user.bio ?? '');
    _emailController = TextEditingController(text: user.email ?? '');

    _usernameController.addListener(_onUsernameChanged);
  }

  void _populateIfEmpty(UserProfile user) {
    if (_hasInitialized) return;
    final session = ref.read(authServiceProvider).currentSession;

    final realName = (session?.displayName.isNotEmpty == true && session!.displayName != 'Traveler')
        ? session.displayName
        : (user.displayName != 'Traveler' ? user.displayName : '');
    if (_nameController.text.isEmpty && realName.isNotEmpty) {
      _nameController.text = realName;
    }

    final realUsername = (session?.username.isNotEmpty == true && session!.username != 'traveler')
        ? session.username.replaceAll('@', '')
        : (user.username != 'traveler' ? user.username.replaceAll('@', '') : '');
    if (_usernameController.text.isEmpty && realUsername.isNotEmpty) {
      _usernameController.text = realUsername;
    }

    final realBio = session?.bio ?? user.bio ?? '';
    if (_bioController.text.isEmpty && realBio.isNotEmpty) {
      _bioController.text = realBio;
    }

    final realEmail = session?.email ?? user.email ?? '';
    if (_emailController.text.isEmpty && realEmail.isNotEmpty) {
      _emailController.text = realEmail;
    }

    if (_nameController.text.isNotEmpty || _usernameController.text.isNotEmpty) {
      _hasInitialized = true;
    }
  }

  void _onUsernameChanged() {
    final raw = _usernameController.text.trim().replaceAll('@', '').toLowerCase();
    final current = UserService.getCurrentUser();
    final session = ref.read(authServiceProvider).currentSession;
    final myUsername = (session?.username ?? current.username).trim().replaceAll('@', '').toLowerCase();

    _debounceTimer?.cancel();
    if (raw.isEmpty) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = null;
        _usernameFeedback = null;
      });
      return;
    }

    if (raw == myUsername) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = true;
        _usernameFeedback = '✓ Your current handle';
      });
      return;
    }

    if (raw.length < 3) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameFeedback = 'Handle must be at least 3 characters';
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameFeedback = 'Checking availability...';
    });

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      final available = await UserService.isUsernameAvailable(
        raw,
        excludeUserId: session?.id ?? current.id,
      );
      if (mounted && _usernameController.text.trim().replaceAll('@', '').toLowerCase() == raw) {
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = available;
          _usernameFeedback = available ? '✓ Handle is available' : '✗ Handle is already taken';
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final current = UserService.getCurrentUser();
    final authService = ref.read(authServiceProvider);
    final session = authService.currentSession;

    final enteredUsername = _usernameController.text.trim().replaceAll('@', '');
    final effectiveUsername = enteredUsername.isNotEmpty
        ? enteredUsername
        : (session?.username ?? current.username).replaceAll('@', '');

    final myCurrentUsername = (session?.username ?? current.username).replaceAll('@', '').toLowerCase();
    if (effectiveUsername.toLowerCase() != myCurrentUsername) {
      final available = await UserService.isUsernameAvailable(
        effectiveUsername,
        excludeUserId: session?.id ?? current.id,
      );
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('The handle @$effectiveUsername is already taken. Please choose another.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final enteredName = _nameController.text.trim();
      final enteredBio = _bioController.text.trim();
      final enteredEmail = _emailController.text.trim();

      final updatedName = enteredName.isNotEmpty
          ? enteredName
          : (session?.displayName.isNotEmpty == true ? session!.displayName : current.displayName);
      final updatedBio = enteredBio.isNotEmpty ? enteredBio : (session?.bio ?? current.bio);
      final updatedEmail = enteredEmail.isNotEmpty ? enteredEmail : (session?.email ?? current.email);

      final updated = current.copyWith(
        displayName: updatedName.isNotEmpty ? updatedName : 'Traveler',
        username: effectiveUsername.isNotEmpty ? effectiveUsername : 'traveler',
        bio: updatedBio?.isNotEmpty == true ? updatedBio : null,
        email: updatedEmail?.isNotEmpty == true ? updatedEmail : null,
      );

      UserService.updateCurrentUser(updated);
      ref.read(currentUserProvider.notifier).state = updated;

      if (session != null) {
        final updatedAuth = session.copyWith(
          displayName: updated.displayName,
          username: updated.username,
          bio: updated.bio,
        );
        final storage = ref.read(localStorageServiceProvider);
        await storage.saveAuthSession(updatedAuth);
      }

      await authService.syncCurrentUserToFirestore();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    _populateIfEmpty(currentUser);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    currentUser.initials,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUser.displayName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        currentUser.handle,
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Persona Switcher Bar


                  // Display Name
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      prefixIcon: Icon(Icons.badge_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Username / Handle
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username (@handle)',
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                      prefixText: '@',
                      suffixIcon: _isCheckingUsername
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : (_isUsernameAvailable == true
                              ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20)
                              : (_isUsernameAvailable == false
                                  ? const Icon(Icons.cancel_rounded, color: Colors.red, size: 20)
                                  : null)),
                      helperText: _usernameFeedback,
                      helperStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _isUsernameAvailable == true
                            ? const Color(0xFF10B981)
                            : (_isUsernameAvailable == false ? Colors.red : Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Email
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Bio
                  TextField(
                    controller: _bioController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Travel Bio & Status',
                      prefixIcon: Icon(Icons.mode_comment_rounded),
                    ),
                  ),

                  const SizedBox(height: 24),

                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveProfile,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      _isSaving ? 'Saving Profile...' : 'Save Profile & Changes',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

                  const SizedBox(height: 10),

                  OutlinedButton.icon(
                    onPressed: _isSigningOut
                        ? null
                        : () async {
                            setState(() => _isSigningOut = true);
                            try {
                              await ref.read(authNotifierProvider.notifier).logout();
                            } finally {
                              if (mounted) {
                                setState(() => _isSigningOut = false);
                              }
                            }
                          },
                    icon: _isSigningOut
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                          )
                        : const Icon(Icons.logout_rounded, size: 18, color: Colors.red),
                    label: Text(
                      _isSigningOut ? 'Signing Out...' : 'Sign Out',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.withAlpha(80)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
