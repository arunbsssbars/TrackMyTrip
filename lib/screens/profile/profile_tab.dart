import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final user = UserService.getCurrentUser();
    _nameController = TextEditingController(text: user.displayName);
    _usernameController = TextEditingController(text: user.username.replaceAll('@', ''));
    _bioController = TextEditingController(text: user.bio ?? '');
    _emailController = TextEditingController(text: user.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    final current = UserService.getCurrentUser();
    final updated = current.copyWith(
      displayName: _nameController.text.trim().isEmpty ? 'Traveler' : _nameController.text.trim(),
      username: _usernameController.text.trim().isEmpty ? 'traveler' : _usernameController.text.trim(),
      bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
      email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
    );

    UserService.updateCurrentUser(updated);
    ref.read(currentUserProvider.notifier).state = updated;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _switchPersona(UserProfile persona) {
    UserService.updateCurrentUser(persona);
    ref.read(currentUserProvider.notifier).state = persona;

    setState(() {
      _nameController.text = persona.displayName;
      _usernameController.text = persona.username.replaceAll('@', '');
      _bioController.text = persona.bio ?? '';
      _emailController.text = persona.email ?? '';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched persona to ${persona.displayName} (${persona.handle})'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);
    final mockUsersAsync = ref.watch(userSearchProvider(''));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Profile Pic
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: AppTheme.primary,
                child: Text(
                  currentUser.initials,
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                currentUser.displayName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ),
            Center(
              child: Text(
                currentUser.handle,
                style: const TextStyle(fontSize: 14, color: AppTheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 30),

            // Persona Switcher Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.switch_account_rounded, size: 16, color: AppTheme.primary),
                      SizedBox(width: 6),
                      Text(
                        'SWITCH TRAVELER PERSONA (SIMULATION)',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  mockUsersAsync.when(
                    data: (users) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: users.map((u) {
                          final isSelected = u.id == currentUser.id;
                          final color = Color(int.tryParse(u.colorHex ?? '0xFF0D9488') ?? 0xFF0D9488);

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              avatar: CircleAvatar(
                                backgroundColor: color,
                                child: Text(u.initials, style: const TextStyle(color: Colors.white, fontSize: 9)),
                              ),
                              label: Text(u.displayName.split(' ')[0]),
                              selected: isSelected,
                              onSelected: (_) => _switchPersona(u),
                              selectedColor: AppTheme.primary.withAlpha(40),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

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
              decoration: const InputDecoration(
                labelText: 'Username (@handle)',
                prefixIcon: Icon(Icons.alternate_email_rounded),
                prefixText: '@',
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
              onPressed: _saveProfile,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Save Profile & Changes', style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authNotifierProvider.notifier).logout();
              },
              icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.red),
              label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.withAlpha(80)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
