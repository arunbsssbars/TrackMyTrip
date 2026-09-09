import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/services/cloud_trip_sync_service.dart';
import '../../core/services/trip_share_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/trip.dart';
import '../../models/trip_member.dart';
import '../../providers/audit_log_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/settlement_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';

class ShareTripSheet extends ConsumerStatefulWidget {
  final Trip trip;

  const ShareTripSheet({super.key, required this.trip});

  @override
  ConsumerState<ShareTripSheet> createState() => _ShareTripSheetState();
}

class _ShareTripSheetState extends ConsumerState<ShareTripSheet> {
  int _selectedTabIndex = 0; // 0: Quick Share, 1: QR Code, 2: Travelers
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final package = _buildTripPackage();
      CloudTripSyncService.publishTrip(package);
    });
  }

  TripPackage _buildTripPackage() {
    final stoppages = ref.read(currentTripStoppagesProvider);
    final expenses = ref.read(currentTripExpensesProvider);
    final memories = ref.read(currentTripMemoriesProvider);
    final settlements = ref.read(currentTripSettlementsProvider);
    final auditLogs = ref.read(currentTripAuditLogsProvider);

    return TripPackage(
      trip: widget.trip,
      stoppages: stoppages,
      expenses: expenses,
      memories: memories,
      settlements: settlements,
      auditLogs: auditLogs,
    );
  }

  void _shareViaApps() async {
    final package = _buildTripPackage();
    final activeMember = widget.trip.currentUserMember;
    await TripShareService.shareTrip(
      package,
      senderName: activeMember?.name,
    );
  }

  void _copyCode() async {
    final package = _buildTripPackage();
    await TripShareService.copyCodeToClipboard(package);
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Trip share code copied to clipboard! Share it with your friends.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.primary,
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _showAddTravelerDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Co-Traveler'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add a friend or co-traveler to this trip so they can log shared bills and stops.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Companion Name',
                hintText: 'e.g. Maya, David, Sam',
                prefixIcon: Icon(Icons.person_add_rounded),
              ),
              autofocus: true,
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
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                const colors = [
                  '0xFFF97316',
                  '0xFF3B82F6',
                  '0xFFEC4899',
                  '0xFF10B981',
                  '0xFF8B5CF6',
                  '0xFFEAB308'
                ];
                final color = colors[widget.trip.members.length % colors.length];
                final newMember = TripMember(
                  id: 'member_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  colorHex: color,
                );
                ref.read(tripListProvider.notifier).addMemberToTrip(widget.trip.id, newMember);
                Navigator.of(ctx).pop();
                setState(() {});
              }
            },
            child: const Text('Add Member'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripListProvider).firstWhere(
          (t) => t.id == widget.trip.id,
          orElse: () => widget.trip,
        );
    final stoppages = ref.watch(currentTripStoppagesProvider);
    final expenses = ref.watch(currentTripExpensesProvider);
    final totalSpent = expenses.fold<double>(0, (s, e) => s + e.totalAmount);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final package = _buildTripPackage();
    final shareCode = TripShareService.encodePackage(package);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                  color: AppTheme.primary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.share_rounded, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Share Trip with Friends',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      trip.title,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

          // Segmented Control Tabs
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Share Link'),
                icon: Icon(Icons.send_rounded, size: 16),
              ),
              ButtonSegment(
                value: 1,
                label: Text('QR Code'),
                icon: Icon(Icons.qr_code_2_rounded, size: 16),
              ),
              ButtonSegment(
                value: 2,
                label: Text('Travelers'),
                icon: Icon(Icons.group_rounded, size: 16),
              ),
            ],
            selected: {_selectedTabIndex},
            onSelectionChanged: (val) {
              setState(() => _selectedTabIndex = val.first);
            },
          ),
          const SizedBox(height: 16),

          // Tab Content
          Expanded(
            child: SingleChildScrollView(
              child: _selectedTabIndex == 0
                  ? _buildQuickShareTab(trip, stoppages.length, expenses.length, totalSpent, shareCode, isDark)
                  : _selectedTabIndex == 1
                      ? _buildQrCodeTab(shareCode, isDark)
                      : _buildTravelersTab(trip, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickShareTab(
    Trip trip,
    int stopsCount,
    int billsCount,
    double totalSpent,
    String shareCode,
    bool isDark,
  ) {
    final roomCode = CloudTripSyncService.generateRoomCode(trip.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live Cloud Room Join Code Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.secondary.withAlpha(25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.secondary.withAlpha(100), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppTheme.secondary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_tethering_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LIVE CLOUD JOIN CODE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.secondary, letterSpacing: 1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      roomCode,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: AppTheme.secondary),
                tooltip: 'Copy Room Code',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: roomCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Join code $roomCode copied to clipboard!'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppTheme.secondary,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Trip Highlights Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
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
                  const Icon(Icons.calendar_month_rounded, size: 15, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    DateFormatter.formatTripDateRange(trip.startDate, trip.endDate),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$stopsCount Stops  •  $billsCount Bills',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    'Total: ${CurrencyFormatter.format(totalSpent, currency: trip.defaultCurrency)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Primary Action: Share via WhatsApp / SMS / Apps
        ElevatedButton.icon(
          onPressed: _shareViaApps,
          icon: const Icon(Icons.send_rounded),
          label: const Text(
            'Share Invite via Apps (WhatsApp / SMS)',
            style: TextStyle(fontWeight: FontWeight.bold),
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
        const SizedBox(height: 10),

        // Action Buttons Row
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: roomCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Room code $roomCode copied!'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppTheme.secondary,
                    ),
                  );
                },
                icon: const Icon(Icons.vpn_key_rounded, size: 18, color: AppTheme.secondary),
                label: Text(
                  'Copy $roomCode',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: AppTheme.secondary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copyCode,
                icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, size: 18),
                label: Text(
                  _copied ? 'Copied!' : 'Copy Full Invite',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Share Code Preview Box
        Text(
          'Share Code Preview:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFCBD5E1),
            ),
          ),
          child: Text(
            shareCode,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Co-travelers can tap "Join Trip" on their device and paste this code to import the full itinerary and split bills.',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQrCodeTab(String shareCode, bool isDark) {
    return Column(
      children: [
        const Text(
          'Scan to Join Trip',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Ask your friend to scan this QR code using their camera or Trip Tracker app.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: QrImageView(
            data: shareCode,
            version: QrVersions.auto,
            size: 240,
            backgroundColor: Colors.white,
            padding: const EdgeInsets.all(8),
            errorCorrectionLevel: QrErrorCorrectLevel.L,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Fast Scan: Compressed for instant camera detection',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _copyCode,
          icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, size: 18),
          label: Text(_copied ? 'Code Copied!' : 'Copy Code as Text'),
        ),
      ],
    );
  }

  Widget _buildTravelersTab(Trip trip, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Trip Companions (${trip.members.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            TextButton.icon(
              onPressed: _showAddTravelerDialog,
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Add New'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: trip.members.length,
          separatorBuilder: (c, i) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final member = trip.members[index];
            final color = member.colorHex != null
                ? Color(int.parse(member.colorHex!))
                : AppTheme.primary;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              leading: CircleAvatar(
                backgroundColor: color,
                child: Text(
                  member.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                member.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                member.isCurrentUser ? 'You (Active Traveler)' : 'Co-Traveler',
                style: TextStyle(
                  fontSize: 12,
                  color: member.isCurrentUser ? AppTheme.primary : Colors.grey,
                  fontWeight: member.isCurrentUser ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: member.isCurrentUser
                  ? const Chip(
                      label: Text('Active', style: TextStyle(fontSize: 11, color: Colors.white)),
                      backgroundColor: AppTheme.primary,
                      visualDensity: VisualDensity.compact,
                    )
                  : OutlinedButton(
                      onPressed: () {
                        ref.read(tripListProvider.notifier).switchActiveMember(trip.id, member.id);
                        setState(() {});
                      },
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: const Text('Switch to Me', style: TextStyle(fontSize: 11)),
                    ),
            );
          },
        ),
      ],
    );
  }
}
