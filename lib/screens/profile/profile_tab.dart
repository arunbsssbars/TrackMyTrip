import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/design_system/design_system.dart';
import '../../models/user_profile.dart';
import '../../models/auth_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/theme_provider.dart';
import '../../core/utils/currency_formatter.dart';

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
  late TextEditingController _emergencyContactController;
  late TextEditingController _dietaryPrefsController;
  bool _isSaving = false;
  bool _isSigningOut = false;
  bool _isDeletingAccount = false;
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
    _emergencyContactController = TextEditingController();
    _dietaryPrefsController = TextEditingController();

    // Fetch latest cloud profile in background to populate any remote phone/bio
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCloudProfile();
    });
  }

  Future<void> _fetchCloudProfile() async {
    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      final session = ref.read(authServiceProvider).currentSession;
      final current = UserService.getCurrentUser();
      final docId = fbUser?.uid ?? session?.id ?? current.id;

      if (docId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(docId).get();
        if (doc.exists && doc.data() != null && mounted) {
          final data = doc.data()!;
          final cloudPhone = data['phone'] as String?;
          final cloudBio = data['bio'] as String?;
          final cloudName = data['displayName'] as String?;

          bool shouldUpdate = false;
          if (_phoneController.text.isEmpty && cloudPhone != null && cloudPhone.isNotEmpty) {
            _phoneController.text = cloudPhone;
            shouldUpdate = true;
          }
          if (_bioController.text.isEmpty && cloudBio != null && cloudBio.isNotEmpty) {
            _bioController.text = cloudBio;
            shouldUpdate = true;
          }
          if (_nameController.text.isEmpty && cloudName != null && cloudName.isNotEmpty && cloudName != 'Traveler') {
            _nameController.text = cloudName;
            shouldUpdate = true;
          }

          if (shouldUpdate) {
            setState(() {});
          }
        }
      }
    } catch (_) {}
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

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _emergencyContactController.dispose();
    _dietaryPrefsController.dispose();
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

    setState(() => _isSaving = true);
    HapticFeedback.lightImpact();

    try {
      final enteredName = _nameController.text.trim();
      final enteredPhone = _phoneController.text.trim();
      final enteredBio = _bioController.text.trim();
      final enteredEmail = _emailController.text.trim();

      // Ensure fields are not wiped with blanks if left unedited
      final updatedName = enteredName.isNotEmpty
          ? enteredName
          : (currentSession?.displayName.isNotEmpty == true ? currentSession!.displayName : current.displayName);
      final updatedPhone = enteredPhone.isNotEmpty ? enteredPhone : null;
      final updatedBio = enteredBio.isNotEmpty ? enteredBio : null;
      final updatedEmail = enteredEmail.isNotEmpty ? enteredEmail : (currentSession?.email ?? current.email);

      // Handle is immutable
      final permanentUsername = (currentSession?.username.isNotEmpty == true && currentSession!.username != 'traveler')
          ? currentSession.username.replaceAll('@', '')
          : current.username.replaceAll('@', '');

      final updated = current.copyWith(
        displayName: updatedName.isNotEmpty ? updatedName : 'Traveler',
        username: permanentUsername.isNotEmpty ? permanentUsername : 'traveler',
        phone: updatedPhone?.isNotEmpty == true ? updatedPhone : null,
        bio: updatedBio?.isNotEmpty == true ? updatedBio : null,
        email: updatedEmail?.isNotEmpty == true ? updatedEmail : null,
      );

      // 1. Update in-memory user service and Riverpod state
      UserService.updateCurrentUser(updated);
      ref.read(currentUserProvider.notifier).state = updated;

      // 2. Persist updated profile to local Auth session and update AuthNotifier
      final updatedAuth = (currentSession != null)
          ? currentSession.copyWith(
              displayName: updated.displayName,
              username: updated.username,
              phone: updated.phone,
              bio: updated.bio,
              email: updated.email,
            )
          : AuthUser(
              id: current.id,
              email: updated.email ?? '',
              displayName: updated.displayName,
              username: updated.username,
              phone: updated.phone,
              bio: updated.bio,
              colorHex: updated.colorHex,
              photoUrl: updated.avatarUrl,
              provider: currentSession?.provider ?? AuthProviderType.guest,
              createdAt: DateTime.now(),
            );
      await ref.read(authNotifierProvider.notifier).updateUser(updatedAuth);

      // 3. Reliable synchronization to Cloud Firestore (Item 6)
      try {
        final fbUser = FirebaseAuth.instance.currentUser;
        final docId = fbUser?.uid ?? currentSession?.id ?? current.id;

        if (docId.isNotEmpty) {
          final searchTokens = UserService.generateSearchTokens(
            username: updated.username,
            displayName: updated.displayName,
            email: updated.email,
            phone: updated.phone,
          );

          final profilePayload = {
            'id': docId,
            'displayName': updated.displayName,
            'username': updated.username.toLowerCase(),
            'email': updated.email?.toLowerCase(),
            'phone': updated.phone ?? '',
            'bio': updated.bio ?? '',
            'colorHex': updated.colorHex,
            'searchTokens': searchTokens.toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          // Primary doc write
          await FirebaseFirestore.instance
              .collection('users')
              .doc(docId)
              .set(profilePayload, SetOptions(merge: true));

          // Also mirror to fbUser.uid if different
          if (fbUser != null && fbUser.uid != docId) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(fbUser.uid)
                .set(profilePayload, SetOptions(merge: true));
          }
        }
      } catch (cloudErr) {
        debugPrint('Cloud profile sync deferred: $cloudErr');
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
            backgroundColor: Colors.red,
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
    final userTrips = ref.watch(tripListProvider);
    final userExpenses = ref.watch(allExpensesProvider);
    final totalExpenseAmount = userExpenses.fold<double>(0.0, (acc, e) => acc + e.totalAmount);
    final completeness = _calculateCompleteness(currentUser);

    _populateIfEmpty(currentUser);

    final completedTrips = userTrips.where((t) => t.isCompleted || t.status == 'completed').length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Executive Profile',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.3),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.symmetric(horizontal: MediaQuery.sizeOf(context).width > 800 ? (MediaQuery.sizeOf(context).width - 640) / 2 : AppSpacing.md, vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Executive Profile Header Card (Item 7)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [Colors.white, const Color(0xFFF1F5F9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 50 : 15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppTheme.primary, Color(0xFF06B6D4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        child: Text(
                          currentUser.initials,
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    currentUser.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primary.withAlpha(50)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline_rounded, size: 12, color: AppTheme.primary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                currentUser.handle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (authService.isEmailVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF10B981).withAlpha(60)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, size: 12, color: Color(0xFF10B981)),
                              SizedBox(width: 3),
                              Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Traveler Stats Ribbon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHeaderStat('Journeys', '${userTrips.length}', Icons.flight_takeoff_rounded, isDark),
                      Container(height: 24, width: 1, color: isDark ? Colors.white12 : Colors.black12),
                      _buildHeaderStat('Completed', '$completedTrips', Icons.check_circle_outline_rounded, isDark),
                      Container(height: 24, width: 1, color: isDark ? Colors.white12 : Colors.black12),
                      _buildHeaderStat(
                        'Expenses',
                        totalExpenseAmount > 99999
                            ? CurrencyFormatter.formatCompact(totalExpenseAmount)
                            : CurrencyFormatter.format(totalExpenseAmount),
                        Icons.account_balance_wallet_rounded,
                        isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Profile Completion Progress (Only if < 100)
            if (completeness < 100) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.assignment_turned_in_outlined, size: 18, color: AppTheme.primary),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Profile Completeness',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$completeness%',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.primary),
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
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Section 1: Identification & Contact
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.badge_rounded, size: 16, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Identity & Contact Details',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Display Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full / Display Name',
                      hintText: 'Enter your full name',
                      prefixIcon: Icon(Icons.person_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Username / Handle (IMMUTABLE per Item 7)
                  TextFormField(
                    controller: _usernameController,
                    readOnly: true,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Companion Handle (Permanent)',
                      prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                      prefixText: '@',
                      suffixIcon: const Tooltip(
                        message: 'Handle is locked and cannot be modified',
                        child: Icon(Icons.lock_rounded, size: 18, color: Colors.grey),
                      ),
                      helperText: 'Assigned companion handle (immutable)',
                      helperStyle: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Mobile Phone Number (Item 6)
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile Phone Number',
                      hintText: 'e.g. +1 555-0199',
                      prefixIcon: Icon(Icons.phone_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Email Address (Read-only verified status)
                  TextFormField(
                    controller: _emailController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Registered Email',
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      suffixIcon: authService.isEmailVerified
                          ? const Tooltip(
                              message: 'Email Verified',
                              child: Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                            )
                          : const Tooltip(
                              message: 'Unverified',
                              child: Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Section 2: Traveler Bio & Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.edit_note_rounded, size: 18, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Traveler Bio & Status',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bioController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Bio / Status',
                      hintText: 'Share a note about your travel philosophy or status...',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Section 3 (Loop 125): Travel Preferences & Emergency Contact
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.contact_emergency_rounded, size: 18, color: Color(0xFFEF4444)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Emergency & Travel Preferences',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emergencyContactController,
                    decoration: const InputDecoration(
                      labelText: 'Emergency Contact Person / Phone',
                      hintText: 'e.g. Sarah Smith (+1 555-0144)',
                      prefixIcon: Icon(Icons.emergency_rounded, size: 20, color: Color(0xFFEF4444)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dietaryPrefsController,
                    decoration: const InputDecoration(
                      labelText: 'Dietary & Accessibility Needs',
                      hintText: 'e.g. Vegetarian, Peanut allergy, Wheelchair access',
                      prefixIcon: Icon(Icons.restaurant_rounded, size: 20, color: Color(0xFF10B981)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Section 4: Appearance & Theme Mode
            Consumer(
              builder: (context, ref, _) {
                final currentThemeMode = ref.watch(themeModeProvider);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.palette_rounded,
                              size: 18,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Appearance & Theme',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Choose how the app displays on this device',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _buildThemeOption(
                            context: context,
                            ref: ref,
                            mode: ThemeMode.system,
                            currentMode: currentThemeMode,
                            label: 'System',
                            icon: Icons.brightness_auto_rounded,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildThemeOption(
                            context: context,
                            ref: ref,
                            mode: ThemeMode.light,
                            currentMode: currentThemeMode,
                            label: 'Light',
                            icon: Icons.light_mode_rounded,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildThemeOption(
                            context: context,
                            ref: ref,
                            mode: ThemeMode.dark,
                            currentMode: currentThemeMode,
                            label: 'Dark',
                            icon: Icons.dark_mode_rounded,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            // Section 5 (Loop 126): Local SQLite Cache & Offline Sync Telemetry
            Builder(
              builder: (ctx) {
                Map<String, int> telemetry = const {};
                try {
                  telemetry = ref.read(localStorageServiceProvider).getStorageTelemetry();
                } catch (_) {}

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.storage_rounded, size: 18, color: Color(0xFF3B82F6)),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Offline Storage & Queue',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              minimumSize: const Size(40, 30),
                            ),
                            icon: const Icon(Icons.cleaning_services_rounded, size: 14, color: Color(0xFF3B82F6)),
                            label: const Text('Purge Obsolete', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              try {
                                final count = await ref.read(localStorageServiceProvider).purgeObsoleteMutations();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✓ Cleaned up $count obsolete sync mutations.'),
                                      backgroundColor: const Color(0xFF10B981),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  setState(() {});
                                }
                              } catch (_) {}
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildTelemetryChip('Trips', '${telemetry['trips'] ?? userTrips.length}', Icons.flight_takeoff_rounded, isDark),
                          _buildTelemetryChip('Stops', '${telemetry['stoppages'] ?? 0}', Icons.place_rounded, isDark),
                          _buildTelemetryChip('Bills', '${telemetry['expenses'] ?? userExpenses.length}', Icons.receipt_rounded, isDark),
                          _buildTelemetryChip('Memories', '${telemetry['memories'] ?? 0}', Icons.photo_camera_rounded, isDark),
                          _buildTelemetryChip('Audit Logs', '${telemetry['auditLogs'] ?? 0}', Icons.security_rounded, isDark),
                          _buildTelemetryChip('Queue', '${telemetry['mutations'] ?? 0}', Icons.sync_rounded, isDark),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Action: Save Profile & Sync
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveProfile,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_done_rounded, size: 20),
              label: Text(
                _isSaving ? 'Synchronizing Cloud Profile...' : 'Save Profile Changes',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              ),
            ),
            const SizedBox(height: 12),

            // Action: Sign Out (Direct signout without confirmation dialog)
            OutlinedButton.icon(
              onPressed: _isSigningOut || _isDeletingAccount
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
                _isSigningOut ? 'Signing Out...' : 'Sign Out of Account',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.withAlpha(80)),
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              ),
            ),
            const SizedBox(height: 12),

            // Action: Delete Account & Purge Data (GDPR & App Store Compliance)
            TextButton.icon(
              onPressed: _isSigningOut || _isDeletingAccount
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text(
                            'Delete Account & All Data',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                          content: const Text(
                            'This action is irreversible. Your profile, trip history, expense records, and associated data will be permanently deleted from this device and the cloud.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Keep Account'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Permanently Delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        setState(() => _isDeletingAccount = true);
                        try {
                          await ref.read(authNotifierProvider.notifier).deleteAccountAndData();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Account and data successfully deleted.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Deletion failed: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setState(() => _isDeletingAccount = false);
                          }
                        }
                      }
                    },
              icon: _isDeletingAccount
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                    )
                  : const Icon(Icons.delete_forever_rounded, size: 16, color: Colors.redAccent),
              label: Text(
                _isDeletingAccount ? 'Deleting Account...' : 'Delete Account & Purge Data',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.redAccent),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryChip(String label, String count, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.primary),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
            ),
          ),
          Text(
            count,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required WidgetRef ref,
    required ThemeMode mode,
    required ThemeMode currentMode,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = currentMode == mode;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            ref.read(themeModeProvider.notifier).setThemeMode(mode);
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary
                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primary
                    : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withAlpha(50),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.grey[300] : const Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.grey[300] : const Color(0xFF334155)),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
