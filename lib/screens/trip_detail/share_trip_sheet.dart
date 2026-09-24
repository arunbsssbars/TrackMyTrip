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
import '../../providers/invitation_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/settlement_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';
import '../trip/companion_search_dialog.dart';

class ShareTripSheet extends ConsumerStatefulWidget {
  final Trip trip;

  const ShareTripSheet({super.key, required this.trip});

  @override
  ConsumerState<ShareTripSheet> createState() => _ShareTripSheetState();
}

class _ShareTripSheetState extends ConsumerState<ShareTripSheet> {
  int _selectedTabIndex = 0; // 0: Quick Share, 1: QR Code, 2: Travelers

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
                label: Text('Share Link', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                icon: Icon(Icons.send_rounded, size: 15),
              ),
              ButtonSegment(
                value: 1,
                label: Text('QR Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                icon: Icon(Icons.qr_code_2_rounded, size: 15),
              ),
              ButtonSegment(
                value: 2,
                label: Text('Members', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                icon: Icon(Icons.group_rounded, size: 15),
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
    final roomCode = CloudTripSyncService.getRoomCode(trip.id, trip: trip);

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
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Co-travelers can tap "Join Trip" on their device and enter this room code to follow route & split expenses.',
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
          'Ask your friend to scan this QR code using their camera or Track My Trip app.',
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
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                final roomCode = CloudTripSyncService.getRoomCode(widget.trip.id, trip: widget.trip);
                Clipboard.setData(ClipboardData(text: roomCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Join code $roomCode copied to clipboard!'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppTheme.secondary,
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy Code', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _shareViaApps,
              icon: const Icon(Icons.share_rounded, size: 16),
              label: const Text('Share Invite', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _openCompanionSearch(BuildContext context, Trip trip) {
    CompanionSearchDialog.show(
      context,
      tripId: trip.id,
      currentMembers: trip.members,
      onCompanionSelected: (member) async {
        await ref.read(invitationProvider.notifier).sendInvitation(
          tripId: trip.id,
          tripTitle: trip.title,
          inviteeId: member.id,
          inviteeUsername: member.name,
          inviteeEmail: member.email,
          tripJson: trip.toJson(),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Trip invitation sent to ${member.name}! They will join once accepted.'),
              backgroundColor: AppTheme.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
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
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _showAddTravelerDialog,
                  icon: const Icon(Icons.person_add_rounded, size: 14),
                  label: const Text('Manual', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                const SizedBox(width: 6),
                FilledButton.tonalIcon(
                  onPressed: () => _openCompanionSearch(context, trip),
                  icon: const Icon(Icons.person_search_rounded, size: 15),
                  label: const Text('Invite', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ],
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
                member.isCurrentUser ? 'You (Active Traveler)' : (member.id == trip.createdByMemberId ? 'Trip Host' : 'Co-Traveler'),
                style: TextStyle(
                  fontSize: 12,
                  color: member.isCurrentUser ? AppTheme.primary : Colors.grey,
                  fontWeight: member.isCurrentUser ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: member.isCurrentUser
                      ? AppTheme.primary.withAlpha(25)
                      : (isDark ? Colors.white.withAlpha(15) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: member.isCurrentUser
                        ? AppTheme.primary
                        : (isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1)),
                  ),
                ),
                child: Text(
                  member.isCurrentUser
                      ? 'You (Active)'
                      : (member.id == trip.createdByMemberId ? 'Host' : 'Companion'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: member.isCurrentUser
                        ? AppTheme.primary
                        : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
