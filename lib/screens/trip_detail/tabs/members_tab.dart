import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/services/cloud_trip_sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/trip.dart';
import '../../../models/trip_invitation.dart';
import '../../../models/trip_member.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/expense_provider.dart';
import '../../../providers/invitation_provider.dart';
import '../../../providers/trip_provider.dart';
import '../../../widgets/app_floating_button.dart';
import '../../trip/companion_search_dialog.dart';
import '../../../core/utils/trip_guard_helper.dart';

class MembersTab extends ConsumerStatefulWidget {
  final Trip trip;

  const MembersTab({super.key, required this.trip});

  @override
  ConsumerState<MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends ConsumerState<MembersTab> {
  void _openCompanionSearch() async {
    final canProceed = await TripGuardHelper.ensureTripOpenForEdit(
      context,
      ref,
      widget.trip,
      actionLabel: 'invite companions',
    );
    if (!canProceed || !mounted) return;

    final currentTrip = ref.read(tripListProvider).where((t) => t.id == widget.trip.id).firstOrNull ?? widget.trip;
    CompanionSearchDialog.show(
      context,
      tripId: currentTrip.id,
      currentMembers: currentTrip.members,
      actionLabel: 'Invite',
      onUserSelected: (user) async {
        final cleanEmail = (user.email != null && user.email!.trim().isNotEmpty) ? user.email!.trim().toLowerCase() : null;
        final username = user.username.isNotEmpty ? user.username.trim().toLowerCase() : (cleanEmail?.split('@').first ?? user.displayName);
        final inviteeId = user.id.isNotEmpty ? user.id : null;

        await ref.read(invitationProvider.notifier).sendInvitation(
          tripId: currentTrip.id,
          tripTitle: currentTrip.title,
          inviteeId: inviteeId,
          inviteeUsername: username,
          inviteeEmail: cleanEmail,
          tripJson: currentTrip.toJson(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Trip invitation sent to "${user.displayName}"! They will join once accepted.'),
              backgroundColor: AppTheme.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      onCompanionSelected: (newMember) async {
        // If it's a custom or offline companion, add directly to trip
        if (newMember.id.startsWith('custom_') || newMember.id.startsWith('offline_') || newMember.id.startsWith('member_')) {
          await ref.read(tripListProvider.notifier).addMemberToTrip(currentTrip.id, newMember);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added "${newMember.name}" as custom companion!'),
                backgroundColor: AppTheme.primary,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        // Otherwise send invitation
        final cleanEmail = newMember.email?.trim().toLowerCase();
        final username = cleanEmail != null
            ? cleanEmail.split('@').first
            : newMember.name.replaceAll(' ', '_').toLowerCase();
        final inviteeId = newMember.id;

        await ref.read(invitationProvider.notifier).sendInvitation(
          tripId: currentTrip.id,
          tripTitle: currentTrip.title,
          inviteeId: inviteeId,
          inviteeUsername: username,
          inviteeEmail: cleanEmail,
          tripJson: currentTrip.toJson(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Trip invitation sent to "${newMember.name}"! They will join once accepted.'),
              backgroundColor: AppTheme.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  void _showAddOfflineMemberDialog() async {
    final canProceed = await TripGuardHelper.ensureTripOpenForEdit(
      context,
      ref,
      widget.trip,
      actionLabel: 'add a custom companion',
    );
    if (!canProceed || !mounted) return;

    final nameController = TextEditingController();
    final currentTrip = ref.read(tripListProvider).where((t) => t.id == widget.trip.id).firstOrNull ?? widget.trip;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Add Custom Member',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add an offline companion (e.g. driver, guide, family member without the app) to split expenses and track attendance.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Companion Name',
                  hintText: 'e.g. Driver Ramesh, Tour Guide',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop();
              const colors = ['0xFF10B981', '0xFFEC4899', '0xFF3B82F6', '0xFFF97316', '0xFF8B5CF6', '0xFF14B8A6'];
              final color = colors[currentTrip.members.length % colors.length];
              final offlineMember = TripMember(
                id: 'offline_${DateTime.now().millisecondsSinceEpoch}',
                name: name,
                isCurrentUser: false,
                colorHex: color,
              );
              await ref.read(tripListProvider.notifier).addMemberToTrip(currentTrip.id, offlineMember);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added "$name" as custom companion!'),
                    backgroundColor: AppTheme.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Add Member'),
          ),
        ],
      ),
    );
  }


  void _shareTripCode(String code, String tripTitle) {
    final text = 'Join my trip "$tripTitle" on Track My Trip!\nUse code: $code\nDownload the app to follow route & split expenses.';
    Share.share(text, subject: 'Track My Trip Invite: $tripTitle');
  }


  void _confirmRemoveMember(TripMember member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Remove ${member.name}?'),
        content: Text(
          'Are you sure you want to remove ${member.name} from this trip? They will lose access to shared expenses and route tracking.',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(tripListProvider.notifier).removeMemberFromTrip(widget.trip.id, member.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Removed ${member.name}')),
                );
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveTrip() {
    if (widget.trip.isCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Concluded journeys cannot be abandoned. All splits and member records are preserved.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Leave Trip?'),
        content: const Text(
          'Are you sure you want to leave this trip? You will stop sharing location and viewing trip updates.',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(tripListProvider.notifier).leaveTrip(widget.trip.id);
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Leave Trip'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trips = ref.watch(tripListProvider);
    final currentTrip = trips.where((t) => t.id == widget.trip.id).firstOrNull ?? widget.trip;
    final authUser = ref.watch(authNotifierProvider).valueOrNull;
    final currentUid = authUser?.id;
    final isCreator = currentTrip.isCreator(currentUid) || currentTrip.isCreator(currentTrip.currentUserMember?.id);

    final shareCode = (currentTrip.shareCode != null && currentTrip.shareCode!.isNotEmpty)
        ? currentTrip.shareCode!
        : CloudTripSyncService.getRoomCode(currentTrip.id, trip: currentTrip);

    if (currentTrip.shareCode != shareCode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(tripListProvider.notifier).updateTrip(currentTrip.copyWith(shareCode: shareCode));
        }
      });
    }

    // Get pending sent invitations for this trip
    final sentInvitations = ref.watch(sentInvitationsProvider);
    final tripInvitations = sentInvitations.where((inv) => inv.tripId == currentTrip.id && inv.status == InvitationStatus.pending).toList();

    final allExpenses = ref.watch(allExpensesProvider);
    final tripExpenses = allExpenses.where((e) => e.tripId == currentTrip.id).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: AppFloatingActionButton.extended(
        heroTag: 'members_share_fab',
        icon: Icons.share_rounded,
        label: 'Share Code',
        onPressed: () => _shareTripCode(shareCode, currentTrip.title),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
        children: [
          // 1. Members Header & Add Actions (Invite & Custom)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.groups_rounded, size: 20, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Travelers (${currentTrip.members.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ],
            ),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _showAddOfflineMemberDialog,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                  label: const Text('+ Custom', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _openCompanionSearch,
                  icon: const Icon(Icons.person_search_rounded, size: 14),
                  label: const Text('Invite', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),


        const SizedBox(height: 10),

        // 3. Members List
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: currentTrip.members.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
            ),
            itemBuilder: (context, index) {
              final member = currentTrip.members[index];
              final isMemberCreator = currentTrip.isCreator(member.id);
              final isMe = (currentUid != null && member.id == currentUid) ||
                  (authUser?.email != null && member.email != null && authUser!.email.toLowerCase() == member.email!.toLowerCase());

              final memberPaid = tripExpenses
                  .where((e) => e.paidByMemberId == member.id || e.paidByMemberId == member.name)
                  .fold<double>(0.0, (sum, e) => sum + e.totalAmount);

              final colorInt = int.tryParse(member.colorHex ?? '0xFF0D9488') ?? 0xFF0D9488;
              final avatarColor = Color(colorInt);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Stack(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: avatarColor,
                      child: Text(
                        member.initials,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    if (isMemberCreator)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star_rounded, size: 10, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isMemberCreator ? Colors.amber.withAlpha(25) : Colors.blue.withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isMemberCreator ? 'Trip Lead' : 'Companion',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isMemberCreator ? Colors.amber[800] : Colors.blue[700],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: memberPaid > 0 ? const Color(0xFF10B981).withAlpha(25) : (isDark ? Colors.white10 : Colors.grey.withAlpha(30)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Paid: ${CurrencyFormatter.format(memberPaid, currency: currentTrip.defaultCurrency)}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: memberPaid > 0 ? const Color(0xFF059669) : (isDark ? Colors.grey[400] : Colors.grey[700]),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (member.email != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        member.email!,
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : AppTheme.textMutedLight),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
                trailing: isCreator && !isMe
                    ? IconButton(
                        icon: const Icon(Icons.person_remove_rounded, size: 20, color: Colors.redAccent),
                        onPressed: () => _confirmRemoveMember(member),
                        tooltip: 'Remove companion',
                      )
                    : (isMe && !isMemberCreator
                        ? TextButton.icon(
                            onPressed: _confirmLeaveTrip,
                            icon: const Icon(Icons.exit_to_app_rounded, size: 16, color: Colors.red),
                            label: const Text('Leave', style: TextStyle(color: Colors.red, fontSize: 12)),
                          )
                        : null),
              );
            },
          ),
        ),

        const SizedBox(height: 20),

        // 4. Pending Invitations Section (if any)
        if (tripInvitations.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.outgoing_mail, size: 18, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'Pending Invitations (${tripInvitations.length})',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tripInvitations.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final inv = tripInvitations[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.withAlpha(25),
                    child: const Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 18),
                  ),
                  title: Text(
                    inv.inviteeEmail ?? inv.inviteeUsername,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Status: Pending • Sent recently',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : AppTheme.textMutedLight),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      ref.read(invitationProvider.notifier).cancelInvitation(inv.id);
                    },
                    child: const Text('Cancel', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    ),
  );
}
}
