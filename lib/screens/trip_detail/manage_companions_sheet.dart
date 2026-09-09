import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../models/trip.dart';
import '../../models/trip_member.dart';
import '../../providers/trip_provider.dart';

class ManageCompanionsSheet extends ConsumerStatefulWidget {
  final Trip trip;

  const ManageCompanionsSheet({super.key, required this.trip});

  static void show(BuildContext context, Trip trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ManageCompanionsSheet(trip: trip),
    );
  }

  @override
  ConsumerState<ManageCompanionsSheet> createState() => _ManageCompanionsSheetState();
}

class _ManageCompanionsSheetState extends ConsumerState<ManageCompanionsSheet> {
  late List<TripMember> _members;
  late String _tripType;
  final _newCompanionController = TextEditingController();

  final List<String> _avatarColors = [
    '0xFF0F766E', // Teal
    '0xFFF97316', // Orange
    '0xFF3B82F6', // Blue
    '0xFFEC4899', // Pink
    '0xFF10B981', // Green
    '0xFF8B5CF6', // Purple
    '0xFFEAB308', // Yellow
    '0xFF6366F1', // Indigo
  ];

  @override
  void initState() {
    super.initState();
    _members = List.from(widget.trip.members);
    _tripType = widget.trip.tripType;
  }

  @override
  void dispose() {
    _newCompanionController.dispose();
    super.dispose();
  }

  void _addCompanion() {
    final name = _newCompanionController.text.trim();
    if (name.isEmpty) return;

    final color = _avatarColors[_members.length % _avatarColors.length];
    final newMember = TripMember(
      id: 'member_${const Uuid().v4().substring(0, 8)}',
      name: name,
      colorHex: color,
    );

    setState(() {
      _members.add(newMember);
      _newCompanionController.clear();
    });
    _saveChanges();
  }

  void _editMemberDialog(TripMember member) {
    final nameController = TextEditingController(text: member.name);
    String selectedColor = member.colorHex ?? '0xFF0F766E';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Traveler / Companion'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Avatar Color:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _avatarColors.map((hex) {
                  final color = Color(int.parse(hex));
                  final isSelected = selectedColor == hex;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = hex),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withAlpha(150), blurRadius: 6, spreadRadius: 1)]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = nameController.text.trim();
                if (newName.isEmpty) return;
                Navigator.of(ctx).pop();

                setState(() {
                  _members = _members.map((m) {
                    if (m.id == member.id) {
                      return m.copyWith(name: newName, colorHex: selectedColor);
                    }
                    return m;
                  }).toList();
                });
                _saveChanges();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _removeMember(TripMember member) {
    if (_members.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one traveler must remain on the trip.')),
      );
      return;
    }

    setState(() {
      _members.removeWhere((m) => m.id == member.id);
    });
    _saveChanges();
  }

  void _setActiveMember(TripMember member) {
    setState(() {
      _members = _members.map((m) {
        return m.copyWith(isCurrentUser: m.id == member.id);
      }).toList();
    });
    _saveChanges();
  }

  void _saveChanges() {
    final updated = widget.trip.copyWith(
      members: _members,
      tripType: _tripType,
    );
    ref.read(tripListProvider.notifier).updateTrip(updated);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 14,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.people_alt_rounded, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Manage Companions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

          // Trip Mode Selector (Group, Family, Solo)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                _buildModeOption(
                  'group',
                  'Group',
                  Icons.groups_rounded,
                  const Color(0xFF0F766E),
                  isDark,
                ),
                const SizedBox(width: 4),
                _buildModeOption(
                  'family',
                  'Family',
                  Icons.family_restroom_rounded,
                  const Color(0xFFD97706),
                  isDark,
                ),
                const SizedBox(width: 4),
                _buildModeOption(
                  'solo',
                  'Solo',
                  Icons.backpack_rounded,
                  const Color(0xFF2563EB),
                  isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Companions List
          const Text(
            'Travelers on this Trip:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _members.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final member = _members[index];
                final color = Color(int.tryParse(member.colorHex ?? '') ?? 0xFF0F766E);

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: color,
                    child: Text(
                      member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (member.isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'This Device',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: member.isCurrentUser
                      ? const Text('Your active profile', style: TextStyle(fontSize: 11, color: Colors.grey))
                      : InkWell(
                          onTap: () => _setActiveMember(member),
                          child: const Text('Tap to switch device profile', style: TextStyle(fontSize: 11, color: AppTheme.secondary)),
                        ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Edit name & color',
                        onPressed: () => _editMemberDialog(member),
                      ),
                      if (_members.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                          tooltip: 'Remove companion',
                          onPressed: () => _removeMember(member),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Add Companion Input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newCompanionController,
                  decoration: const InputDecoration(
                    hintText: 'Add new companion name...',
                    prefixIcon: Icon(Icons.person_add_alt_1_rounded, size: 18),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: (_) => _addCompanion(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addCompanion,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

  Widget _buildModeOption(
    String mode,
    String title,
    IconData icon,
    Color activeColor,
    bool isDark,
  ) {
    final isSelected = _tripType == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _tripType = mode);
          _saveChanges();
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : (isDark ? Colors.black26 : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : (isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1)),
              width: isSelected ? 1.4 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withAlpha(50),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : activeColor,
              ),
              const SizedBox(width: 5),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
