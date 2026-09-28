import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/cloud_trip_sync_service.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/trip.dart';
import '../../models/trip_member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/invitation_provider.dart';
import '../../providers/audit_log_provider.dart';
import '../../models/trip_audit_log.dart';
import '../trip/companion_search_dialog.dart';
import '../common/sheet_drag_handle.dart';
import '../common/user_avatar.dart';

class CreateTripSheet extends ConsumerStatefulWidget {
  final String? initialTripType;

  const CreateTripSheet({super.key, this.initialTripType});

  @override
  ConsumerState<CreateTripSheet> createState() => _CreateTripSheetState();
}

class _CreateTripSheetState extends ConsumerState<CreateTripSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _myMemberNameController = TextEditingController(text: 'Alex (Me)');
  final _budgetController = TextEditingController();
  final _companionController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 3));
  String _selectedCurrency = LocationService.detectLocalCurrencyFast();
  late String _tripType; // 'group', 'family', 'solo'
  final List<TripMember> _companions = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initialTripType;
    if (init == 'family' || init == 'solo' || init == 'group') {
      _tripType = init!;
    } else {
      _tripType = 'group';
    }
    final authUser = ref.read(authNotifierProvider).valueOrNull;
    if (authUser != null && authUser.displayName.isNotEmpty) {
      _myMemberNameController.text = authUser.displayName;
    }
    _autoDetectCurrency();
  }

  Future<void> _autoDetectCurrency() async {
    final detected = await LocationService.detectLocalCurrency();
    if (mounted && detected.isNotEmpty) {
      setState(() {
        _selectedCurrency = detected;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _myMemberNameController.dispose();
    _budgetController.dispose();
    _companionController.dispose();
    super.dispose();
  }

  void _addCompanion() {
    final name = _companionController.text.trim();
    if (name.isNotEmpty && !_companions.any((c) => c.name.toLowerCase() == name.toLowerCase())) {
      const uuid = Uuid();
      const colors = ['0xFFF97316', '0xFF3B82F6', '0xFFEC4899', '0xFF10B981', '0xFF8B5CF6'];
      setState(() {
        _companions.add(
          TripMember(
            id: 'custom_${uuid.v4().substring(0, 8)}',
            name: name,
            colorHex: colors[_companions.length % colors.length],
            isCurrentUser: false,
          ),
        );
        _companionController.clear();
      });
    }
  }

  void _removeCompanion(TripMember member) {
    setState(() {
      _companions.removeWhere((c) => c.id == member.id);
    });
  }

  void _openCompanionSearch() {
    final authUser = ref.read(authNotifierProvider).valueOrNull;
    final myMember = TripMember(
      id: authUser?.id ?? 'me',
      name: _myMemberNameController.text.trim().isEmpty ? 'You' : _myMemberNameController.text.trim(),
      email: authUser?.email,
      isCurrentUser: true,
      colorHex: authUser?.colorHex ?? '0xFF0F766E',
    );

    CompanionSearchDialog.show(
      context,
      currentMembers: [myMember, ..._companions],
      actionLabel: 'Add',
      onUserSelected: (user) {
        final cleanEmail = (user.email != null && user.email!.trim().isNotEmpty) ? user.email!.trim().toLowerCase() : null;
        final member = TripMember(
          id: user.id,
          name: user.displayName.isNotEmpty ? user.displayName : user.username,
          email: cleanEmail,
          colorHex: user.colorHex ?? '0xFF3B82F6',
        );
        if (!_companions.any((c) => c.id == member.id || (c.email != null && c.email == member.email))) {
          setState(() {
            _companions.add(member);
          });
        }
      },
      onCompanionSelected: (member) {
        if (!_companions.any((c) => c.id == member.id || c.name.toLowerCase() == member.name.toLowerCase())) {
          setState(() {
            _companions.add(member);
          });
        }
      },
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final authUser = ref.read(authNotifierProvider).valueOrNull;
    final myMemberId = authUser?.id ?? 'member_${const Uuid().v4().substring(0, 8)}';
    final myName = _myMemberNameController.text.trim().isNotEmpty
        ? _myMemberNameController.text.trim()
        : (authUser?.displayName.isNotEmpty == true ? authUser!.displayName : 'You');
    final myEmail = authUser?.email;

    final myMember = TripMember(
      id: myMemberId,
      name: myName,
      email: myEmail,
      isCurrentUser: true,
      colorHex: authUser?.colorHex ?? '0xFF0F766E',
    );

    // Two-Phase Workflow: Only creator and offline manual companions are in initial trip.members.
    // Registered companions receive invitations and join once accepted.
    final offlineCompanions = _companions.where((c) => c.id.startsWith('custom_') && (c.email == null || c.email!.isEmpty)).toList();
    final memberList = <TripMember>[myMember, ...offlineCompanions];

    final newTripId = const Uuid().v4();
    final generatedRoomCode = CloudTripSyncService.generateRoomCode(newTripId);
    CloudTripSyncService.registerRoomCode(newTripId, generatedRoomCode);

    final newTrip = Trip(
      id: newTripId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
      startDate: _startDate,
      endDate: _endDate,
      defaultCurrency: _selectedCurrency,
      tripType: _tripType,
      members: memberList,
      createdByMemberId: myMemberId,
      createdAt: DateTime.now(),
      shareCode: generatedRoomCode,
    );

    ref.read(tripListProvider.notifier).addTrip(newTrip);
    ref.read(selectedTripIdProvider.notifier).state = newTrip.id;

    ref.read(allAuditLogsProvider.notifier).logAction(
      TripAuditLog(
        id: 'log_${const Uuid().v4().substring(0, 8)}',
        tripId: newTrip.id,
        actionType: 'create_trip',
        itemTitle: newTrip.title,
        performedByMemberId: myMemberId,
        performedByName: myName,
        timestamp: DateTime.now(),
        changeDetails: 'Created new ${newTrip.isSolo ? "Solo" : (newTrip.isFamily ? "Family" : "Group")} expedition with ${memberList.length} member(s)',
      ),
    );

    // Two-Phase Workflow: Dispatch invitations in batch (creates exactly 1 consolidated notification for the creator)
    if (_tripType != 'solo' && _companions.isNotEmpty) {
      final registerableCompanions = _companions.where((c) => c.email != null || !c.id.startsWith('custom_')).toList();
      if (registerableCompanions.isNotEmpty) {
        ref.read(invitationProvider.notifier).sendInvitationsBatch(
          tripId: newTrip.id,
          tripTitle: newTrip.title,
          invitees: registerableCompanions,
          tripJson: newTrip.toJson(),
        );
      }
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
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
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              const SheetDragHandle(margin: EdgeInsets.only(bottom: 14)),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_location_alt_rounded, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Plan a New Trip',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
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
              const SizedBox(height: 16),

              // Section 1: Trip Mode Selector & Rules
              _buildSectionHeader('1. Choose Trip Mode & Rules', Icons.tune_rounded),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    _buildModeButton(
                      'group',
                      'Group',
                      Icons.groups_rounded,
                      const Color(0xFF0F766E),
                      isDark,
                    ),
                    const SizedBox(width: 4),
                    _buildModeButton(
                      'family',
                      'Family',
                      Icons.family_restroom_rounded,
                      const Color(0xFFD97706),
                      isDark,
                    ),
                    const SizedBox(width: 4),
                    _buildModeButton(
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

              // Section 2: Destination & Notes
              _buildSectionHeader('2. Destination & Route', Icons.map_outlined),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Trip Destination / Title *',
                  hintText: 'Enter trip title or destination',
                  prefixIcon: Icon(Icons.flight_takeoff_rounded),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a trip title' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description / Route Notes',
                  hintText: 'Add route notes or description (optional)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Section 3: Timeline & Currency
              _buildSectionHeader('3. Dates & Currency', Icons.date_range_rounded),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: _pickDateRange,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withAlpha(40)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_startDate.month}/${_startDate.day} - ${_endDate.month}/${_endDate.day}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withAlpha(40)),
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
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
              const SizedBox(height: 18),

              // Section 4: Companions Section
              if (_tripType == 'solo') ...[
                _buildSectionHeader('4. Solo Traveler', Icons.backpack_rounded),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withAlpha(60)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.backpack_rounded, color: Colors.blue, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '🎒 Solo Mode: All expenses, itinerary stops, and GPS tracking will be tracked exclusively for you without split calculations or debt balances.',
                          style: TextStyle(fontSize: 12, color: Colors.blue, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_tripType == 'family') ...[
                _buildSectionHeader('4. Family Members (Shared Pool)', Icons.family_restroom_rounded),
                const SizedBox(height: 4),
                const Text(
                  'Family trips pool all expenses together for your overall budget. Individual debts are disabled.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const CircleAvatar(
                        backgroundColor: Color(0xFFD97706),
                        child: Icon(Icons.person, size: 14, color: Colors.white),
                      ),
                      label: Text(_myMemberNameController.text.isEmpty ? 'You' : _myMemberNameController.text),
                      backgroundColor: const Color(0xFFD97706).withAlpha(35),
                    ),
                    ..._companions.map(
                      (comp) => Chip(
                        avatar: CircleAvatar(
                          backgroundColor: Color(int.tryParse(comp.colorHex ?? '0xFFD97706') ?? 0xFFD97706),
                          child: Text(
                            comp.name.isNotEmpty ? comp.name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        label: Text(comp.name),
                        onDeleted: () => _removeCompanion(comp),
                        deleteIcon: const Icon(Icons.cancel, size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Search Button + Add by Name
                OutlinedButton.icon(
                  onPressed: _openCompanionSearch,
                  icon: const Icon(Icons.person_search_rounded, size: 18),
                  label: const Text('Search App Users (@username)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _companionController,
                        decoration: const InputDecoration(
                          hintText: 'Or type family member name (e.g. Mom, Brother)',
                          prefixIcon: Icon(Icons.person_add_alt_1_rounded),
                        ),
                        onSubmitted: (_) => _addCompanion(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addCompanion,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ] else ...[
                _buildSectionHeader('4. Companions & Friends (Split & Settle)', Icons.groups_rounded),
                const SizedBox(height: 4),
                const Text(
                  'Group trips calculate fair share splits and track who owes whom with settlement tabs.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const CircleAvatar(
                        backgroundColor: AppTheme.primary,
                        child: Icon(Icons.person, size: 14, color: Colors.white),
                      ),
                      label: Text(_myMemberNameController.text.isEmpty ? 'You' : _myMemberNameController.text),
                      backgroundColor: AppTheme.primary.withAlpha(35),
                    ),
                    ..._companions.map(
                      (comp) => Chip(
                        avatar: UserAvatar(
                          name: comp.name,
                          colorHex: comp.colorHex,
                          size: 20,
                          fontSize: 10,
                        ),
                        label: Text(comp.name),
                        onDeleted: () => _removeCompanion(comp),
                        deleteIcon: const Icon(Icons.cancel, size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Search Button + Add by Name
                OutlinedButton.icon(
                  onPressed: _openCompanionSearch,
                  icon: const Icon(Icons.person_search_rounded, size: 18),
                  label: const Text('Search App Users (@username)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _companionController,
                        decoration: const InputDecoration(
                          hintText: 'Or type companion name (e.g. Friend, Colleague)',
                          prefixIcon: Icon(Icons.person_add_alt_1_rounded),
                        ),
                        onSubmitted: (_) => _addCompanion(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addCompanion,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(
                  _isSubmitting ? 'Creating Trip...' : 'Create & Start Trip',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: -0.2),
        ),
      ],
    );
  }

  Widget _buildModeButton(
    String mode,
    String title,
    IconData icon,
    Color activeColor,
    bool isDark,
  ) {
    final isSelected = _tripType == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tripType = mode),
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
