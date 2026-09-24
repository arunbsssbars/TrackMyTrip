import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;
  late TextEditingController _emailController;
  bool _isSaving = false;
  bool _isSigningOut = false;

  Timer? _debounceTimer;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String? _usernameFeedback;
  bool _hasInitializedValues = false;

  @override
  void initState() {
    super.initState();
    final user = UserService.getCurrentUser();
    _nameController = TextEditingController(text: user.displayName != 'Traveler' ? user.displayName : '');
    _usernameController = TextEditingController(text: user.username != 'traveler' ? user.username.replaceAll('@', '') : '');
    _phoneController = TextEditingController(text: user.phone ?? '');
    _bioController = TextEditingController(text: user.bio ?? '');
    _emailController = TextEditingController(text: user.email ?? '');

    _usernameController.addListener(_onUsernameChanged);
  }

  void _populateIfEmpty(UserProfile user) {
    if (_hasInitializedValues) return;
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

    final realPhone = session?.phone ?? user.phone ?? '';
    if (_phoneController.text.isEmpty && realPhone.isNotEmpty) {
      _phoneController.text = realPhone;
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
      _hasInitializedValues = true;
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
    _phoneController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  int _calculateCompleteness(UserProfile user) {
    int score = 0;
    if (user.displayName.trim().isNotEmpty && user.displayName.trim() != 'Traveler') score += 25;
    if (user.username.trim().isNotEmpty && !user.username.startsWith('user_') && user.username != 'traveler') score += 25;
    if (user.phone != null && user.phone!.trim().isNotEmpty) score += 25;
    if (user.bio != null && user.bio!.trim().isNotEmpty) score += 25;
    return score;
  }

  Future<void> _saveProfile() async {
    final current = UserService.getCurrentUser();
    final authService = ref.read(authServiceProvider);
    final currentSession = authService.currentSession;

    final enteredUsername = _usernameController.text.trim().replaceAll('@', '');
    final effectiveUsername = enteredUsername.isNotEmpty
        ? enteredUsername
        : (currentSession?.username ?? current.username).replaceAll('@', '');

    // Check availability if changed
    final myCurrentUsername = (currentSession?.username ?? current.username).replaceAll('@', '').toLowerCase();
    if (effectiveUsername.toLowerCase() != myCurrentUsername) {
      final available = await UserService.isUsernameAvailable(
        effectiveUsername,
        excludeUserId: currentSession?.id ?? current.id,
      );
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('The handle @$effectiveUsername is already taken. Please choose another handle.'),
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
      final enteredPhone = _phoneController.text.trim();
      final enteredBio = _bioController.text.trim();
      final enteredEmail = _emailController.text.trim();

      // Ensure fields are not wiped with blanks if left unedited
      final updatedName = enteredName.isNotEmpty
          ? enteredName
          : (currentSession?.displayName.isNotEmpty == true ? currentSession!.displayName : current.displayName);
      final updatedPhone = enteredPhone.isNotEmpty ? enteredPhone : (currentSession?.phone ?? current.phone);
      final updatedBio = enteredBio.isNotEmpty ? enteredBio : (currentSession?.bio ?? current.bio);
      final updatedEmail = enteredEmail.isNotEmpty ? enteredEmail : (currentSession?.email ?? current.email);

      final updated = current.copyWith(
        displayName: updatedName.isNotEmpty ? updatedName : 'Traveler',
        username: effectiveUsername.isNotEmpty ? effectiveUsername : 'traveler',
        phone: updatedPhone?.isNotEmpty == true ? updatedPhone : null,
        bio: updatedBio?.isNotEmpty == true ? updatedBio : null,
        email: updatedEmail?.isNotEmpty == true ? updatedEmail : null,
      );

      // 1. Update in-memory user service and Riverpod state
      UserService.updateCurrentUser(updated);
      ref.read(currentUserProvider.notifier).state = updated;

      // 2. Persist updated profile to local Auth session
      if (currentSession != null) {
        final updatedAuth = currentSession.copyWith(
          displayName: updated.displayName,
          username: updated.username,
          phone: updated.phone,
          bio: updated.bio,
        );
        final storage = ref.read(localStorageServiceProvider);
        await storage.saveAuthSession(updatedAuth);
      }

      // 3. Sync to Firebase if connected
      try {
        final fbUser = FirebaseAuth.instance.currentUser;
        if (fbUser != null) {
          final searchTokens = UserService.generateSearchTokens(
            username: updated.username,
            displayName: updated.displayName,
            email: updated.email,
            phone: updated.phone,
          );

          await FirebaseFirestore.instance.collection('users').doc(fbUser.uid).set({
            'id': fbUser.uid,
            'displayName': updated.displayName,
            'username': updated.username.toLowerCase(),
            'email': updated.email?.toLowerCase(),
            'phone': updated.phone,
            'bio': updated.bio,
            'colorHex': updated.colorHex,
            'searchTokens': searchTokens.toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (_) {
        // Ignored if offline or Firebase not configured
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Profile details saved and synchronized successfully!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
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
    final authService = ref.watch(authServiceProvider);
    final completeness = _calculateCompleteness(currentUser);

    _populateIfEmpty(currentUser);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Account'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 16 * (1 - value)),
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Header Profile Card
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: AppTheme.primary,
                    child: Text(
                      currentUser.initials,
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.surfaceDark : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(30),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.edit_rounded, size: 16, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                currentUser.displayName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 2),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentUser.handle,
                    style: const TextStyle(fontSize: 14, color: AppTheme.primary, fontWeight: FontWeight.bold),
                  ),
                  if (authService.isEmailVerified) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, size: 12, color: Color(0xFF10B981)),
                          SizedBox(width: 3),
                          Text(
                            'Verified',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Profile Completion Progress Banner (Only show if not 100% completed)
            if (completeness < 100) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.account_box_outlined,
                          size: 20,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Profile Completion ($completeness%)',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: completeness / 100,
                        backgroundColor: isDark ? Colors.black26 : const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete your profile details below (full name, phone, bio) so travel companions easily recognize you.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            const Text(
              'Personal Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Display Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full / Display Name',
                hintText: 'Enter your full name',
                prefixIcon: Icon(Icons.badge_rounded),
              ),
            ),
            const SizedBox(height: 14),

            // Username / Handle
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username Handle',
                hintText: 'Choose a unique username handle',
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

            // Mobile Phone Number
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile Phone Number',
                hintText: 'Enter mobile phone number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 14),

            // Email Address (Read only with verified indicator)
            TextFormField(
              controller: _emailController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Icons.email_outlined),
                suffixIcon: authService.isEmailVerified
                    ? const Tooltip(
                        message: 'Email Verified',
                        child: Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
                      )
                    : const Tooltip(
                        message: 'Unverified',
                        child: Icon(Icons.warning_amber_rounded, color: Colors.amber),
                      ),
              ),
            ),
            const SizedBox(height: 14),

            // Bio & Status
            TextFormField(
              controller: _bioController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Traveler Bio & Status',
                hintText: 'Add a short bio or status',
                prefixIcon: Icon(Icons.mode_comment_outlined),
              ),
            ),

            const SizedBox(height: 28),

            // Save Profile Button
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveProfile,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_rounded, size: 20),
              label: Text(
                _isSaving ? 'Saving Changes...' : 'Save Profile & Changes',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),

            const SizedBox(height: 14),

            // Sign Out Button
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
  }
}
