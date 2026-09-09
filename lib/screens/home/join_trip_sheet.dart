import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/cloud_trip_sync_service.dart';
import '../../core/services/trip_share_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/trip_member.dart';
import '../../providers/expense_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/settlement_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';
import '../trip_detail/trip_detail_screen.dart';

import 'qr_scanner_screen.dart';

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class JoinTripSheet extends ConsumerStatefulWidget {
  final String? initialCode;

  const JoinTripSheet({super.key, this.initialCode});

  @override
  ConsumerState<JoinTripSheet> createState() => _JoinTripSheetState();
}

class _JoinTripSheetState extends ConsumerState<JoinTripSheet> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newMemberNameController = TextEditingController();

  TripPackage? _parsedPackage;
  String? _selectedMemberId;
  bool _isCreatingNewMember = false;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _codeController.text = widget.initialCode!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _analyzeInput(widget.initialCode!);
      });
    } else {
      _codeController.text = 'TRIP-';
      _codeController.selection = TextSelection.fromPosition(
        TextPosition(offset: _codeController.text.length),
      );
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _newMemberNameController.dispose();
    super.dispose();
  }

  void _scanQrCode() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );
    if (scanned != null && mounted) {
      _codeController.text = scanned;
      _analyzeInput(scanned);
    }
  }

  void _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && data.text!.trim().isNotEmpty) {
        final text = data.text!.trim();
        _codeController.text = text;
        _analyzeInput(text);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clipboard is empty. Copy a trip code or invite first.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  void _analyzeInput(String text) async {
    var clean = text.trim();
    if (clean.isEmpty) {
      setState(() {
        _parsedPackage = null;
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }

    // Auto-extract 6-character room code from invite messages if pasted
    final match = RegExp(r'TRIP-[A-Z0-9]{4}', caseSensitive: false).firstMatch(clean);
    if (match != null) {
      clean = match.group(0)!.toUpperCase();
    } else if (clean.length == 4 && !clean.contains(':')) {
      clean = 'TRIP-${clean.toUpperCase()}';
    }

    // 1. Try local snapshot decoder
    final pkg = TripShareService.decodePackage(clean);
    if (pkg != null) {
      setState(() {
        _parsedPackage = pkg;
        _errorMessage = null;
        _isLoading = false;
        if (pkg.trip.members.isNotEmpty) {
          _selectedMemberId = pkg.trip.members.first.id;
          _isCreatingNewMember = false;
        } else {
          _isCreatingNewMember = true;
        }
      });
      return;
    }

    // 2. Try fetching from Cloud Live Room by code
    if (clean.toUpperCase().startsWith('TRIP-') || clean.length == 4 || clean.length == 9) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final cloudPkg = await CloudTripSyncService.fetchTripByCode(clean);
      if (!mounted) return;
      if (cloudPkg != null) {
        setState(() {
          _parsedPackage = cloudPkg;
          _errorMessage = null;
          _isLoading = false;
          if (cloudPkg.trip.members.isNotEmpty) {
            _selectedMemberId = cloudPkg.trip.members.first.id;
            _isCreatingNewMember = false;
          } else {
            _isCreatingNewMember = true;
          }
        });
        return;
      }
    }

    setState(() {
      _parsedPackage = null;
      _isLoading = false;
      _errorMessage = 'Could not find trip for "$clean". Please verify the 6-character room code or scan the QR code.';
    });
  }

  void _importAndOpenTrip() async {
    final pkg = _parsedPackage;
    if (pkg == null) return;

    String? activeMemberId = _selectedMemberId;

    // If user chose to create a new traveler
    if (_isCreatingNewMember) {
      final customName = _newMemberNameController.text.trim();
      final name = customName.isNotEmpty ? customName : 'Co-Traveler';
      const colors = ['0xFF10B981', '0xFFEC4899', '0xFF3B82F6', '0xFFF97316', '0xFF8B5CF6'];
      final color = colors[pkg.trip.members.length % colors.length];

      final newMember = TripMember(
        id: 'member_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        colorHex: color,
        isCurrentUser: true,
      );
      pkg.trip.members.add(newMember);
      activeMemberId = newMember.id;
    }

    final importedTrip = await ref.read(tripListProvider.notifier).importTrip(
          pkg,
          activeMemberId: activeMemberId,
        );

    // Broadcast new traveler to cloud room
    if (_isCreatingNewMember) {
      CloudTripSyncService.publishTrip(pkg);
    }

    // Refresh child providers
    ref.read(allStoppagesProvider.notifier).reload();
    ref.read(allExpensesProvider.notifier).reload();
    ref.read(allMemoriesProvider.notifier).reload();
    ref.read(allSettlementsProvider.notifier).reload();

    if (!mounted) return;
    Navigator.of(context).pop(); // Close bottom sheet

    // Navigate to Trip Details
    ref.read(selectedTripIdProvider.notifier).state = importedTrip.id;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TripDetailScreen(tripId: importedTrip.id),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Joined "${importedTrip.title}" successfully!'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedMemberName = _isCreatingNewMember
        ? (_newMemberNameController.text.trim().isNotEmpty
            ? _newMemberNameController.text.trim()
            : 'New Traveler')
        : (_parsedPackage?.trip.getMemberName(_selectedMemberId ?? '') ?? 'Traveler');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.group_add_rounded, color: AppTheme.secondary, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Join Shared Trip',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Enter 6-digit room code or scan QR',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
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
            const SizedBox(height: 16),

            // Quick Actions: Camera Scan + 1-Tap Paste
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _scanQrCode,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text(
                      'Scan QR Code',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: AppTheme.secondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.paste_rounded, size: 18, color: AppTheme.primary),
                    label: const Text(
                      'Paste Code',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppTheme.primary, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Text Input for Code
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [_UpperCaseTextFormatter()],
              decoration: InputDecoration(
                labelText: 'Live Room Code',
                hintText: 'e.g. TRIP-3PNU or 3PNU',
                prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppTheme.secondary),
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : (_codeController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _codeController.text = 'TRIP-';
                              _codeController.selection = TextSelection.fromPosition(
                                const TextPosition(offset: 5),
                              );
                              _analyzeInput('TRIP-');
                            },
                          )
                        : null),
              ),
              onChanged: _analyzeInput,
            ),
            const SizedBox(height: 10),

            // Error Message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Step 1: Trip Preview Card
            if (_parsedPackage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primary.withAlpha(80), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _parsedPackage!.trip.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormatter.formatTripDateRange(
                        _parsedPackage!.trip.startDate,
                        _parsedPackage!.trip.endDate,
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildBadge(
                          icon: Icons.place_rounded,
                          label: '${_parsedPackage!.stoppages.length} stops',
                          color: AppTheme.primary,
                        ),
                        _buildBadge(
                          icon: Icons.receipt_rounded,
                          label: '${_parsedPackage!.expenses.length} bills',
                          color: AppTheme.secondary,
                        ),
                        _buildBadge(
                          icon: Icons.group_rounded,
                          label: '${_parsedPackage!.trip.members.length} travelers',
                          color: const Color(0xFF8B5CF6),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Step 2: Choose Traveler Persona (Super Easy 1-Tap Selection)
              const Text(
                'Who is using this device?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Select your name to log stops and bills under your identity:',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),

              // Traveler Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._parsedPackage!.trip.members.map((m) {
                    final isSelected = !_isCreatingNewMember && _selectedMemberId == m.id;
                    final color = m.colorHex != null
                        ? Color(int.parse(m.colorHex!))
                        : AppTheme.primary;

                    return ChoiceChip(
                      selected: isSelected,
                      label: Text(m.name),
                      avatar: CircleAvatar(
                        radius: 10,
                        backgroundColor: isSelected ? Colors.white : color,
                        child: Text(
                          m.name.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? color : Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      selectedColor: AppTheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _isCreatingNewMember = false;
                            _selectedMemberId = m.id;
                          });
                        }
                      },
                    );
                  }),
                  ActionChip(
                    avatar: const Icon(Icons.person_add_rounded, size: 16, color: AppTheme.secondary),
                    label: const Text('+ New Traveler', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
                    backgroundColor: _isCreatingNewMember ? AppTheme.secondary.withAlpha(30) : null,
                    side: _isCreatingNewMember ? const BorderSide(color: AppTheme.secondary, width: 1.5) : null,
                    onPressed: () {
                      setState(() {
                        _isCreatingNewMember = true;
                        _selectedMemberId = null;
                      });
                    },
                  ),
                ],
              ),

              if (_isCreatingNewMember) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _newMemberNameController,
                  decoration: const InputDecoration(
                    labelText: 'Your Name (Co-Traveler)',
                    hintText: 'e.g. Liam, Maya, Chloe',
                    prefixIcon: Icon(Icons.badge_rounded, color: AppTheme.secondary),
                  ),
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                ),
              ],

              const SizedBox(height: 20),

              // Action Button
              ElevatedButton.icon(
                onPressed: _importAndOpenTrip,
                icon: const Icon(Icons.check_circle_rounded),
                label: Text(
                  'Join Trip as $selectedMemberName',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
