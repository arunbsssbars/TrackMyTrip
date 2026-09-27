import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/cloud_trip_sync_service.dart';
import '../../core/services/trip_share_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/trip_member.dart';
import '../../models/trip_audit_log.dart';
import '../../providers/audit_log_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/settlement_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';
import '../trip_detail/trip_detail_screen.dart';
import '../../providers/auth_provider.dart';
import '../../core/services/firestore_sync_service.dart';
import '../../core/services/user_service.dart';
import '../../core/services/proximity_alert_service.dart';
import '../../models/proximity_alert.dart';
import 'qr_scanner_screen.dart';
import '../common/sheet_drag_handle.dart';

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
  final TextEditingController _displayNameController = TextEditingController();

  TripPackage? _parsedPackage;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final authUser = ref.read(authNotifierProvider).valueOrNull;
    final currentProfile = UserService.getCurrentUser();
    final initialName = authUser?.displayName.isNotEmpty == true
        ? authUser!.displayName
        : (currentProfile.displayName.isNotEmpty ? currentProfile.displayName : '');
    _displayNameController.text = initialName;

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
    _displayNameController.dispose();
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

    final authUser = ref.read(authNotifierProvider).valueOrNull;
    final currentProfile = UserService.getCurrentUser();
    final String currentUid = (authUser != null && authUser.id.isNotEmpty) ? authUser.id : currentProfile.id;
    final String currentEmail = (authUser != null && authUser.email.isNotEmpty) ? authUser.email : (currentProfile.email ?? '');
    final customName = _displayNameController.text.trim();
    final currentDisplayName = customName.isNotEmpty
        ? customName
        : ((authUser?.displayName.isNotEmpty == true)
            ? authUser!.displayName
            : (currentProfile.displayName.isNotEmpty ? currentProfile.displayName : 'Co-Traveler'));

    // Ensure all existing members have isCurrentUser = false initially
    final updatedMembers = pkg.trip.members.map((m) => m.copyWith(isCurrentUser: false)).toList();

    // Check if current user already exists in this trip
    final existingIndex = updatedMembers.indexWhere((m) =>
        (currentUid.isNotEmpty && m.id == currentUid) ||
        (currentEmail.isNotEmpty && m.email != null && m.email!.trim().toLowerCase() == currentEmail.trim().toLowerCase())
    );

    String activeMemberId;
    if (existingIndex != -1) {
      updatedMembers[existingIndex] = updatedMembers[existingIndex].copyWith(
        id: currentUid,
        name: currentDisplayName,
        email: currentEmail.isNotEmpty ? currentEmail : updatedMembers[existingIndex].email,
        isCurrentUser: true,
      );
      activeMemberId = updatedMembers[existingIndex].id;
    } else {
      const colors = ['0xFF10B981', '0xFFEC4899', '0xFF3B82F6', '0xFFF97316', '0xFF8B5CF6'];
      final color = colors[updatedMembers.length % colors.length];
      final newMember = TripMember(
        id: currentUid.isNotEmpty ? currentUid : 'member_${DateTime.now().millisecondsSinceEpoch}',
        name: currentDisplayName.isNotEmpty ? currentDisplayName : 'Traveler',
        email: currentEmail.isNotEmpty ? currentEmail : null,
        colorHex: color,
        isCurrentUser: true,
      );
      updatedMembers.add(newMember);
      activeMemberId = newMember.id;
    }

    final resolvedShareCode = pkg.trip.shareCode ?? _codeController.text.trim();
    final updatedTrip = pkg.trip.copyWith(
      members: updatedMembers,
      shareCode: resolvedShareCode.isNotEmpty ? resolvedShareCode : pkg.trip.shareCode,
    );
    final updatedPkg = TripPackage(
      trip: updatedTrip,
      stoppages: pkg.stoppages,
      expenses: pkg.expenses,
      memories: pkg.memories,
      settlements: pkg.settlements,
      auditLogs: pkg.auditLogs,
    );

    final importedTrip = await ref.read(tripListProvider.notifier).importTrip(
      updatedPkg,
      activeMemberId: activeMemberId,
    );

    // Register room code so live sync connects to the exact same room
    if (resolvedShareCode.isNotEmpty) {
      CloudTripSyncService.registerRoomCode(importedTrip.id, resolvedShareCode);
    }

    // Sync to Cloud Live Room so all co-travelers see the joined member immediately
    await CloudTripSyncService.publishTrip(updatedPkg);
    try {
      ref.read(firestoreSyncServiceProvider).pushTrip(importedTrip);
    } catch (_) {}

    try {
      ref.read(proximityAlertServiceProvider).broadcastActivityAlert(
        tripId: importedTrip.id,
        type: AlertType.memberJoined,
        title: 'New Member Joined',
        message: '${currentDisplayName.isNotEmpty ? currentDisplayName : "A companion"} joined "${importedTrip.title}" using the trip code',
        senderMemberId: activeMemberId,
        senderName: currentDisplayName,
      );
    } catch (_) {}

    try {
      ref.read(allAuditLogsProvider.notifier).logAction(
        TripAuditLog(
          id: 'log_${const Uuid().v4().substring(0, 8)}',
          tripId: importedTrip.id,
          actionType: 'join_trip',
          itemTitle: importedTrip.title,
          performedByMemberId: activeMemberId,
          performedByName: currentDisplayName.isNotEmpty ? currentDisplayName : 'Traveler',
          timestamp: DateTime.now(),
          changeDetails: 'Joined expedition "${importedTrip.title}" using room code',
        ),
      );
    } catch (_) {}

    // Refresh child providers
    ref.read(allStoppagesProvider.notifier).reload();
    ref.read(allExpensesProvider.notifier).reload();
    ref.read(allMemoriesProvider.notifier).reload();
    ref.read(allSettlementsProvider.notifier).reload();
    ref.read(allAuditLogsProvider.notifier).reload();

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
    final authUser = ref.watch(authNotifierProvider).valueOrNull;
    final currentProfile = UserService.getCurrentUser();
    final activeDisplayName = _displayNameController.text.trim().isNotEmpty
        ? _displayNameController.text.trim()
        : ((authUser?.displayName.isNotEmpty == true)
            ? authUser!.displayName
            : (currentProfile.displayName.isNotEmpty ? currentProfile.displayName : 'Traveler'));

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
            const SheetDragHandle(margin: EdgeInsets.only(bottom: 14)),

            // Header Banner
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_location_alt_rounded, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Join Friends' & Family Journey",
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Enter 6-digit room code or scan QR to sync live',
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

            // 1. Text Input for 6-Digit Share Code (First)
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [_UpperCaseTextFormatter()],
              decoration: InputDecoration(
                labelText: 'Enter 6-Digit Share Code',
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
            const SizedBox(height: 12),

            // 2. Quick Actions: Paste Code (Left) + Scan QR Code (Right)
            Row(
              children: [
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
                const SizedBox(width: 10),
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
              ],
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

            // Trip Preview Card with Smooth Micro-motion
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 320),
              firstCurve: Curves.easeOutCubic,
              secondCurve: Curves.easeInCubic,
              crossFadeState: _parsedPackage != null
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              secondChild: const SizedBox.shrink(),
              firstChild: _parsedPackage == null
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
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
                              const SizedBox(height: 10),
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

                        // Professional Joining Identity Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF161F2E) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppTheme.primary,
                                    child: Text(
                                      activeDisplayName.isNotEmpty
                                          ? activeDisplayName[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                activeDisplayName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withAlpha(30),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'You',
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (authUser?.email != null && authUser!.email.isNotEmpty)
                                          Text(
                                            authUser.email,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _displayNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Your Trip Nickname',
                                  hintText: 'e.g. Enter your nickname',
                                  prefixIcon: Icon(Icons.badge_rounded, color: AppTheme.secondary, size: 20),
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Action Button
                        ElevatedButton.icon(
                          onPressed: _importAndOpenTrip,
                          icon: const Icon(Icons.check_circle_rounded),
                          label: Text(
                            'Join Journey as $activeDisplayName',
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
                    ),
            ),
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
