import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/cloud_trip_sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/trip.dart';
import '../../models/trip_member.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settlement_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/invitation_provider.dart';
import '../trip/companion_search_dialog.dart';
import 'share_trip_sheet.dart';

class CompanionsDetailSheet extends ConsumerWidget {
  final Trip trip;

  const CompanionsDetailSheet({super.key, required this.trip});

  static void show(BuildContext context, Trip trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => CompanionsDetailSheet(trip: trip),
    );
  }

  void _showAddCompanionDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 16),
            const Text(
              'Add Companion to Trip',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_search_rounded, color: AppTheme.primary),
              ),
              title: const Text('Search & Send Trip Invitation', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Search by mobile phone, @username, or email and send an invitation they accept on their app.', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                Navigator.of(ctx).pop();
                CompanionSearchDialog.show(
                  context,
                  currentMembers: trip.members,
                  onCompanionSelected: (member) async {
                    await ref.read(invitationProvider.notifier).sendInvitation(
                      tripId: trip.id,
                      tripTitle: trip.title,
                      inviteeUsername: member.name,
                      tripJson: trip.toJson(),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Trip invitation sent to ${member.name}! They will receive it on their app to accept.'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_add_rounded, color: Colors.orange),
              ),
              title: const Text('Quick Add Custom Companion', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Add an offline companion manually (for splitting bills immediately).', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                Navigator.of(ctx).pop();
                _showManualAddDialog(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showManualAddDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Travel Companion'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Companion Name',
            hintText: 'e.g. Maya, Liam, Sarah',
            prefixIcon: Icon(Icons.person_add_rounded, color: AppTheme.primary),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                const colors = ['0xFF10B981', '0xFFEC4899', '0xFF3B82F6', '0xFFF97316', '0xFF8B5CF6', '0xFF14B8A6'];
                final color = colors[trip.members.length % colors.length];
                final newMember = TripMember(
                  id: 'member_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  colorHex: color,
                );
                ref.read(tripListProvider.notifier).addMemberToTrip(trip.id, newMember);
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(); // Refresh bottom sheet
                CompanionsDetailSheet.show(context, trip.copyWith(members: [...trip.members, newMember]));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allExpenses = ref.watch(allExpensesProvider).where((e) => e.tripId == trip.id).toList();
    final netBalances = ref.watch(tripNetBalancesProvider);
    final roomCode = CloudTripSyncService.getRoomCode(trip.id, trip: trip);

    // Calculate total spend & member contributions
    final double totalTripSpent = allExpenses.fold<double>(0, (s, e) => s + e.totalAmount);
    final double perPersonAvg = trip.members.isNotEmpty ? totalTripSpent / trip.members.length : 0.0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
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
                    color: AppTheme.primary.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.groups_rounded, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Travelers (${trip.members.length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Text(
                            'Room: $roomCode',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.secondary),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: roomCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Room code $roomCode copied!'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppTheme.secondary,
                                ),
                              );
                            },
                            child: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.secondary),
                          ),
                        ],
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
            const SizedBox(height: 14),

            // Financial Summary Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        'Total Spent',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(totalTripSpent, currency: trip.defaultCurrency),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ],
                  ),
                  Container(height: 28, width: 1, color: Colors.grey.withAlpha(80)),
                  Column(
                    children: [
                      Text(
                        'Avg / Person',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(perPersonAvg, currency: trip.defaultCurrency),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Individual Contributions & Balances:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Travelers Cards List
            ...trip.members.map((member) {
              final color = member.colorHex != null
                  ? Color(int.parse(member.colorHex!))
                  : AppTheme.primary;
              final isHost = member.id == trip.createdByMemberId;
              final isCurrentUser = member.isCurrentUser;

              // Calculate member paid
              final paidAmount = allExpenses
                  .where((e) => e.paidByMemberId == member.id)
                  .fold<double>(0, (s, e) => s + e.totalAmount);

              // Calculate member share
              double memberShare = 0;
              for (final exp in allExpenses) {
                for (final split in exp.splits) {
                  if (split.memberId == member.id) {
                    memberShare += split.allocatedAmount;
                  }
                }
              }

              // Net Balance
              final netBalance = netBalances[member.id] ?? (paidAmount - memberShare);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isCurrentUser
                      ? AppTheme.primary.withAlpha(20)
                      : (isDark ? const Color(0xFF0F172A) : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCurrentUser
                        ? AppTheme.primary
                        : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                    width: isCurrentUser ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: color,
                          child: Text(
                            member.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
                                      member.name,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isCurrentUser ? AppTheme.primary : null,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isCurrentUser) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'YOU',
                                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ],
                                  if (isHost && !isCurrentUser) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withAlpha(40),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'HOST',
                                        style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Paid: ${CurrencyFormatter.format(paidAmount, currency: trip.defaultCurrency)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Share: ${CurrencyFormatter.format(memberShare, currency: trip.defaultCurrency)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Balance Chip
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              netBalance > 0.01
                                  ? '+${CurrencyFormatter.format(netBalance, currency: trip.defaultCurrency)}'
                                  : (netBalance < -0.01
                                      ? CurrencyFormatter.format(netBalance, currency: trip.defaultCurrency)
                                      : 'Settled'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: netBalance > 0.01
                                    ? Colors.green
                                    : (netBalance < -0.01 ? Colors.red : Colors.grey),
                              ),
                            ),
                            Text(
                              netBalance > 0.01 ? 'gets back' : (netBalance < -0.01 ? 'owes group' : 'all settled'),
                              style: TextStyle(
                                fontSize: 10,
                                color: netBalance > 0.01
                                    ? Colors.green
                                    : (netBalance < -0.01 ? Colors.red : Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (!isCurrentUser) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () async {
                            await ref.read(tripListProvider.notifier).switchActiveMember(trip.id, member.id);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Switched active traveler to ${member.name}!'),
                                  backgroundColor: AppTheme.primary,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                          label: Text('Use this device as ${member.name}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),

            const SizedBox(height: 10),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddCompanionDialog(context, ref),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Add Companion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Theme.of(context).cardColor,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        builder: (context) => ShareTripSheet(trip: trip),
                      );
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share Room Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
