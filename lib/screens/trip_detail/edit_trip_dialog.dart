import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/trip_guard_helper.dart';
import '../../models/trip.dart';
import '../common/user_avatar.dart';
import '../../models/trip_member.dart';
import '../../models/trip_audit_log.dart';
import '../../providers/audit_log_provider.dart';
import '../../providers/invitation_provider.dart';
import '../../providers/trip_provider.dart';
import '../trip/companion_search_dialog.dart';

class EditTripDialog extends ConsumerStatefulWidget {
  final Trip trip;

  const EditTripDialog({super.key, required this.trip});

  static Future<void> show(BuildContext context, Trip trip) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditTripDialog(trip: trip),
    );
  }

  @override
  ConsumerState<EditTripDialog> createState() => _EditTripDialogState();
}

class _EditTripDialogState extends ConsumerState<EditTripDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newCompanionController = TextEditingController();

  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _budgetController;
  late DateTime _startDate;
  late DateTime _endDate;
  late String _selectedCurrency;
  late String _tripType;
  late List<TripMember> _members;

  static const List<String> _companionColors = [
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
    _titleController = TextEditingController(text: widget.trip.title);
    _descController = TextEditingController(text: widget.trip.description ?? '');
    _budgetController = TextEditingController(
      text: widget.trip.budget != null ? widget.trip.budget!.toStringAsFixed(0) : '',
    );
    _startDate = widget.trip.startDate;
    _endDate = widget.trip.endDate;
    _selectedCurrency = widget.trip.defaultCurrency;
    _tripType = widget.trip.tripType;
    _members = List.from(widget.trip.members);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _budgetController.dispose();
    _newCompanionController.dispose();
    super.dispose();
  }

  void _addCompanion() {
    final name = _newCompanionController.text.trim();
    if (name.isEmpty) return;

    final color = _companionColors[_members.length % _companionColors.length];
    final newMember = TripMember(
      id: 'member_${const Uuid().v4().substring(0, 8)}',
      name: name,
      colorHex: color,
    );

    setState(() {
      _members.add(newMember);
      _newCompanionController.clear();
      if (_tripType == 'solo') {
        _tripType = 'group';
      }
    });
  }

  void _openCompanionSearch() {
    CompanionSearchDialog.show(
      context,
      tripId: widget.trip.id,
      currentMembers: _members,
      actionLabel: 'Invite',
      onUserSelected: (user) async {
        if (user.id.startsWith('custom_') || user.id.startsWith('offline_') || user.id.startsWith('member_') || user.email == null || user.email!.isEmpty) {
          final newMember = TripMember(
            id: user.id.isNotEmpty ? user.id : 'custom_${DateTime.now().millisecondsSinceEpoch}',
            name: user.displayName,
            colorHex: user.colorHex ?? '0xFFF97316',
            isCurrentUser: false,
          );
          if (!_members.any((m) => m.id == newMember.id)) {
            setState(() => _members.add(newMember));
            if (mounted) {
              AppSnackBar.showSuccess(context, 'Added "${user.displayName}" to trip roster.');
            }
          }
          return;
        }

        final cleanEmail = (user.email != null && user.email!.trim().isNotEmpty) ? user.email!.trim().toLowerCase() : null;
        final username = user.username.isNotEmpty ? user.username.trim().toLowerCase() : (cleanEmail?.split('@').first ?? user.displayName);
        final inviteeId = user.id.isNotEmpty ? user.id : null;

        await ref.read(invitationProvider.notifier).sendInvitation(
          tripId: widget.trip.id,
          tripTitle: widget.trip.title,
          inviteeId: inviteeId,
          inviteeUsername: username,
          inviteeEmail: cleanEmail,
          tripJson: widget.trip.toJson(),
        );

        if (mounted) {
          AppSnackBar.showSuccess(context, 'Trip invitation sent to "${user.displayName}"! They will join once accepted.');
        }
      },
      onCompanionSelected: (member) async {
        if (member.id.startsWith('custom_') || member.id.startsWith('offline_')) {
          if (!_members.any((m) => m.id == member.id)) {
            setState(() => _members.add(member));
            if (mounted) {
              AppSnackBar.showSuccess(context, 'Added "${member.name}" to trip roster.');
            }
          }
          return;
        }

        final cleanEmail = member.email?.trim().toLowerCase();
        final username = cleanEmail != null
            ? cleanEmail.split('@').first
            : member.name.replaceAll(' ', '_').toLowerCase();
        final inviteeId = member.id;

        await ref.read(invitationProvider.notifier).sendInvitation(
          tripId: widget.trip.id,
          tripTitle: widget.trip.title,
          inviteeId: inviteeId,
          inviteeUsername: username,
          inviteeEmail: cleanEmail,
          tripJson: widget.trip.toJson(),
        );

        if (mounted) {
          AppSnackBar.showSuccess(context, 'Trip invitation sent to "${member.name}"! They will join once accepted.');
        }
      },

    );
  }

  void _removeCompanion(TripMember member) {
    if (member.isCurrentUser) {
      AppSnackBar.showWarning(context, 'Cannot remove yourself (creator) from the trip.');
      return;
    }
    setState(() {
      _members.removeWhere((m) => m.id == member.id);
      if (_members.length <= 1 && _tripType != 'solo') {
        // Can stay group or switch
      }
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_endDate.isBefore(_startDate)) {
      AppSnackBar.showError(context, 'Trip end date cannot be earlier than start date.');
      return;
    }

    final budgetVal = double.tryParse(_budgetController.text.trim());
    if (budgetVal != null && budgetVal < 0) {
      AppSnackBar.showError(context, 'Trip budget cannot be negative.');
      return;
    }

    final canProceed = await TripGuardHelper.ensureTripOpenForEdit(
      context,
      ref,
      widget.trip,
      actionLabel: 'edit trip details',
    );
    if (!canProceed || !mounted) return;

    final updated = widget.trip.copyWith(
      title: _titleController.text.trim(),
      description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
      startDate: _startDate,
      endDate: _endDate,
      defaultCurrency: _selectedCurrency,
      budget: budgetVal,
      tripType: _tripType,
      members: _members,
    );

    final oldBudget = widget.trip.budget;
    ref.read(tripListProvider.notifier).updateTrip(updated);

    if (oldBudget != budgetVal && budgetVal != null) {
      final currentMember = widget.trip.currentUserMember;
      final curSymbol = CurrencyFormatter.getCurrencySymbol(updated.defaultCurrency);
      final changeText = oldBudget == null
          ? 'Set trip budget to $curSymbol${budgetVal.toStringAsFixed(2)}'
          : 'Updated trip budget from $curSymbol${oldBudget.toStringAsFixed(2)} to $curSymbol${budgetVal.toStringAsFixed(2)}';

      ref.read(allAuditLogsProvider.notifier).logAction(
        TripAuditLog(
          id: const Uuid().v4(),
          tripId: widget.trip.id,
          actionType: oldBudget == null ? 'set_budget' : 'update_budget',
          itemTitle: 'Trip Budget',
          performedByMemberId: currentMember?.id ?? 'User',
          performedByName: currentMember?.name ?? 'Companion',
          timestamp: DateTime.now(),
          changeDetails: changeText,
        ),
      );
    }

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Updated trip "${updated.title}" with ${_members.length} member(s)'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withAlpha(80),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_rounded, color: AppTheme.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Edit Trip Details',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      padding: const EdgeInsets.all(10),
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Trip Mode Selector
                Row(
                  children: [
                    _buildModeChip('group', 'Group', Icons.groups_rounded, const Color(0xFF0F766E), isDark),
                    const SizedBox(width: 6),
                    _buildModeChip('family', 'Family', Icons.family_restroom_rounded, const Color(0xFFD97706), isDark),
                    const SizedBox(width: 6),
                    _buildModeChip('solo', 'Solo', Icons.backpack_rounded, const Color(0xFF2563EB), isDark),
                  ],
                ),
                const SizedBox(height: 14),

                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Trip Destination / Title *',
                    hintText: 'e.g. Manali & Solang Valley, Roadtrip to Goa',
                    prefixIcon: Icon(Icons.flight_takeoff_rounded),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter trip title' : null,
                ),
                const SizedBox(height: 12),

                // Description
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description / Itinerary Notes',
                    hintText: 'e.g. Exploring mountain cafes, river rafting, sightseeing',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 12),

                // Dates & Currency Row
                Row(
                  children: [
                    // Date Picker Tile
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: _pickDateRange,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Dates', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 1),
                                    Text(
                                      DateFormatter.formatTripDateRange(_startDate, _endDate),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Currency Dropdown
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: AppConstants.defaultCurrencies.contains(_selectedCurrency) ? _selectedCurrency : AppConstants.defaultCurrencies.first,
                            isExpanded: true,
                            items: AppConstants.defaultCurrencies.map((c) {
                              final sym = CurrencyFormatter.getCurrencySymbol(c).trim();
                              return DropdownMenuItem(
                                value: c,
                                child: Text(
                                  sym.isNotEmpty ? '$c ($sym)' : c,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCurrency = val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Budget Target
                TextFormField(
                  controller: _budgetController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Budget Target (${CurrencyFormatter.getCurrencySymbol(_selectedCurrency)})',
                    hintText: 'e.g. 5000',
                    prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
                  ),
                ),
                const SizedBox(height: 16),

                // Companions & Co-Travelers Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Travelers & Companions (${_members.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (_tripType == 'solo')
                      const Text('(Solo Mode)', style: TextStyle(fontSize: 11.5, color: Colors.blue, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),

                // Companion Chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _members.map((m) {
                    final isMe = m.isCurrentUser;
                    return Chip(
                      avatar: UserAvatar(
                        name: m.name,
                        colorHex: m.colorHex,
                        size: 20,
                        fontSize: 9,
                      ),
                      label: Text(
                        isMe ? '${m.name} (You)' : m.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      deleteIcon: isMe ? null : const Icon(Icons.close_rounded, size: 14),
                      onDeleted: isMe ? null : () => _removeCompanion(m),
                      backgroundColor: isMe
                          ? AppTheme.primary.withAlpha(25)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),

                // Search Users (@username) Button
                OutlinedButton.icon(
                  onPressed: _openCompanionSearch,
                  icon: const Icon(Icons.person_search_rounded, size: 18),
                  label: const Text(
                    'Invite via App (@username)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),

                // Add Companion Input Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newCompanionController,
                        decoration: const InputDecoration(
                          hintText: 'Add co-traveler name...',
                          prefixIcon: Icon(Icons.person_add_alt_1_rounded, size: 18),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addCompanion(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _addCompanion,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_add_alt_1_rounded, size: 15),
                          SizedBox(width: 4),
                          Text('Add Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Save Action
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeChip(String type, String label, IconData icon, Color color, bool isDark) {
    final isSelected = _tripType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _tripType = type;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withAlpha(25) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? color : Colors.grey),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? color : (isDark ? Colors.grey[300] : Colors.grey[700]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
