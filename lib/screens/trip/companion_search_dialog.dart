import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/trip_member.dart';
import '../../models/user_profile.dart';
import '../../core/services/user_service.dart';

class CompanionSearchDialog extends ConsumerStatefulWidget {
  final List<TripMember> currentMembers;
  final Function(TripMember member) onCompanionSelected;

  const CompanionSearchDialog({
    super.key,
    required this.currentMembers,
    required this.onCompanionSelected,
  });

  static Future<TripMember?> show(
    BuildContext context, {
    required List<TripMember> currentMembers,
    required Function(TripMember member) onCompanionSelected,
  }) {
    return showModalBottomSheet<TripMember>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CompanionSearchDialog(
        currentMembers: currentMembers,
        onCompanionSelected: onCompanionSelected,
      ),
    );
  }

  @override
  ConsumerState<CompanionSearchDialog> createState() => _CompanionSearchDialogState();
}

class _CompanionSearchDialogState extends ConsumerState<CompanionSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isAlreadyMember(UserProfile user) {
    return widget.currentMembers.any(
      (m) => m.id == user.id || m.name.toLowerCase() == user.displayName.toLowerCase(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchResultsAsync = ref.watch(userSearchProvider(_query));

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
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
                      Text(
                        'Search by @username, name, email, or mobile',
                        style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[400] : AppTheme.textMutedLight),
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

          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (val) => setState(() => _query = val),
              decoration: InputDecoration(
                hintText: 'Search @sarah, 9876543210, Mike...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.primary),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
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

          const Divider(height: 1),

          // Results List
          Expanded(
            child: searchResultsAsync.when(
              data: (users) {
                if (users.isEmpty && _query.isNotEmpty) {
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
                              final newMember = TripMember(
                                id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                                name: _query.replaceAll('@', '').trim(),
                                isCurrentUser: false,
                                colorHex: '0xFFF97316',
                              );
                              widget.onCompanionSelected(newMember);
                              Navigator.of(context).pop(newMember);
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isMember = _isAlreadyMember(user);
                    final colorInt = int.tryParse(user.colorHex ?? '0xFF0D9488') ?? 0xFF0D9488;
                    final color = Color(colorInt);

                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isMember
                              ? Colors.green.withAlpha(80)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          width: 1.2,
                        ),
                      ),
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
                                      'Added',
                                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11.5),
                                    ),
                                  ],
                                ),
                              )
                            : FilledButton(
                                onPressed: () {
                                  final newMember = TripMember(
                                    id: user.id,
                                    name: user.displayName,
                                    isCurrentUser: false,
                                    colorHex: user.colorHex,
                                    latitude: user.latitude,
                                    longitude: user.longitude,
                                    lastSeen: user.lastSeen ?? DateTime.now(),
                                  );
                                  widget.onCompanionSelected(newMember);
                                  Navigator.of(context).pop(newMember);
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
