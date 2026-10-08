import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/trip_invitation.dart';
import '../../models/trip_member.dart';
import '../../models/user_profile.dart';
import '../../core/services/user_service.dart';
import '../../providers/invitation_provider.dart';

class CompanionSearchDialog extends ConsumerStatefulWidget {
  final String? tripId;
  final List<TripMember> currentMembers;
  final Function(TripMember member) onCompanionSelected;
  final Function(UserProfile user)? onUserSelected;
  final String actionLabel;

  const CompanionSearchDialog({
    super.key,
    this.tripId,
    required this.currentMembers,
    required this.onCompanionSelected,
    this.onUserSelected,
    this.actionLabel = 'Invite',
  });

  static Future<TripMember?> show(
    BuildContext context, {
    String? tripId,
    required List<TripMember> currentMembers,
    required Function(TripMember member) onCompanionSelected,
    Function(UserProfile user)? onUserSelected,
    String actionLabel = 'Invite',
  }) {
    return showModalBottomSheet<TripMember>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CompanionSearchDialog(
        tripId: tripId,
        currentMembers: currentMembers,
        onCompanionSelected: onCompanionSelected,
        onUserSelected: onUserSelected,
        actionLabel: actionLabel,
      ),
    );
  }

  @override
  ConsumerState<CompanionSearchDialog> createState() => _CompanionSearchDialogState();
}

class _CompanionSearchDialogState extends ConsumerState<CompanionSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _query = '';
  final Set<String> _locallyInvitedIds = {};
  Timer? _debounceTimer;
  bool _isSearching = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isAlreadyMember(UserProfile user) {
    return widget.currentMembers.any(
      (m) =>
          m.id == user.id ||
          (user.email != null &&
              m.email != null &&
              m.email!.trim().toLowerCase() == user.email!.trim().toLowerCase()) ||
          m.name.toLowerCase().trim() == user.displayName.toLowerCase().trim(),
    );
  }

  bool _hasPendingInvitation(UserProfile user, List<TripInvitation> sentInvitations) {
    if (_locallyInvitedIds.contains(user.id)) return true;
    return sentInvitations.any((inv) {
      if (inv.status != InvitationStatus.pending) return false;
      if (widget.tripId != null && inv.tripId != widget.tripId) return false;

      final matchId = inv.inviteeId != null && inv.inviteeId == user.id;
      final matchEmail = user.email != null &&
          inv.inviteeEmail != null &&
          inv.inviteeEmail!.trim().toLowerCase() == user.email!.trim().toLowerCase();
      final matchUsername = inv.inviteeUsername.trim().toLowerCase() == user.username.trim().toLowerCase();

      return matchId || matchEmail || matchUsername;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchResultsAsync = ref.watch(userSearchProvider(_query));

    final viewInsets = MediaQuery.of(context).viewInsets;
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.85,
        ),
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_search_rounded, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Find Travel Companions',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Search by @username, name, email, or mobile',
                        style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[400] : AppTheme.textMutedLight),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                  icon: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.grey.withAlpha(35),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              onChanged: (val) {
                _debounceTimer?.cancel();
                setState(() => _isSearching = true);
                _debounceTimer = Timer(const Duration(milliseconds: 320), () {
                  if (mounted) {
                    setState(() {
                      _query = val;
                      _isSearching = false;
                    });
                  }
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by username, email, or mobile',
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.primary),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                        ),
                      )
                    : (_searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _debounceTimer?.cancel();
                              _searchController.clear();
                              setState(() {
                                _query = '';
                                _isSearching = false;
                              });
                            },
                          )
                        : null),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          if (_isSearching || searchResultsAsync.isLoading)
            const LinearProgressIndicator(
              minHeight: 2.5,
              color: AppTheme.primary,
              backgroundColor: Colors.transparent,
            )
          else
            const Divider(height: 1),

          // Results List
          Expanded(
            child: searchResultsAsync.when(
              data: (rawUsers) {
                final currentProfile = UserService.getCurrentUser();
                final users = rawUsers.where((u) {
                  if (u.id == currentProfile.id) return false;
                  if (currentProfile.email != null &&
                      u.email != null &&
                      u.email!.toLowerCase().trim() == currentProfile.email!.toLowerCase().trim()) {
                    return false;
                  }
                  if (u.username.toLowerCase().trim() == currentProfile.username.toLowerCase().trim()) {
                    return false;
                  }
                  return true;
                }).toList();

                final isSuggested = _query.trim().length < 2;

                if (isSuggested && users.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search_rounded, size: 52, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                          const SizedBox(height: 12),
                          const Text(
                            'Search Companions',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Type at least 2 characters to search registered users by @username, name, email, or mobile number.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : AppTheme.textMutedLight),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!isSuggested && users.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'No companion found for "$_query"',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'You can still add "$_query" as an offline companion:',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: () {
                              final customName = _query.replaceAll('@', '').trim();
                              final newMember = TripMember(
                                id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                                name: customName,
                                isCurrentUser: false,
                                colorHex: '0xFFF97316',
                              );
                              widget.onCompanionSelected(newMember);
                              setState(() {
                                _locallyInvitedIds.add(newMember.id);
                                _searchController.clear();
                                _query = '';
                              });
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added "$customName" to companions'),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: const Icon(Icons.person_add_rounded, size: 16),
                            label: Text('Add "${_query.replaceAll('@', '').trim()}"'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: users.length + (isSuggested ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (isSuggested && index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4, left: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.people_alt_rounded, size: 14, color: AppTheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Suggested Companions (Recent Co-Travelers)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final user = users[isSuggested ? index - 1 : index];
                    final isMember = _isAlreadyMember(user);
                    final sentInvitations = ref.watch(sentInvitationsProvider);
                    final isInvited = !isMember && _hasPendingInvitation(user, sentInvitations);
                    final colorInt = int.tryParse(user.colorHex ?? '0xFF0D9488') ?? 0xFF0D9488;
                    final color = Color(colorInt);

                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isMember
                              ? Colors.green.withAlpha(80)
                              : (isInvited
                                  ? Colors.amber.withAlpha(80)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                          width: 1.2,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: color,
                          child: Text(
                            user.initials,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.displayName,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: color.withAlpha(25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                user.handle,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (user.bio != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  user.bio!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (user.phone != null || user.email != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  user.phone ?? user.email!,
                                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                ),
                              ),
                          ],
                        ),
                        trailing: isMember
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.withAlpha(20),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                                    SizedBox(width: 4),
                                    Text(
                                      'Joined',
                                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11.5),
                                    ),
                                  ],
                                ),
                              )
                            : (isInvited
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withAlpha(25),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.mark_email_read_rounded, size: 14, color: Colors.amber[800]),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Invited',
                                          style: TextStyle(color: Colors.amber[800], fontWeight: FontWeight.bold, fontSize: 11.5),
                                        ),
                                      ],
                                    ),
                                  )
                                 : FilledButton.icon(
                                     onPressed: () {
                                       final newMember = TripMember(
                                         id: user.id,
                                         name: user.displayName,
                                         email: user.email,
                                         isCurrentUser: false,
                                         colorHex: user.colorHex,
                                         latitude: user.latitude,
                                         longitude: user.longitude,
                                         lastSeen: user.lastSeen ?? DateTime.now(),
                                       );
                                       if (widget.onUserSelected != null) {
                                         widget.onUserSelected!(user);
                                       } else {
                                         widget.onCompanionSelected(newMember);
                                       }
                                       setState(() {
                                         _locallyInvitedIds.add(user.id);
                                         _searchController.clear();
                                         _query = '';
                                         _isSearching = false;
                                       });
                                       HapticFeedback.lightImpact();
                                     },

                                     style: FilledButton.styleFrom(
                                       backgroundColor: AppTheme.primary,
                                       foregroundColor: Colors.white,
                                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                     ),
                                     icon: const Icon(Icons.send_rounded, size: 14),
                                     label: const Text('Invite', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                   )),
                      ),
                        ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary),
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error loading users: $err', style: const TextStyle(fontSize: 12, color: Colors.red)),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
