import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/services/cloud_trip_sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/trip.dart';
import '../../../models/trip_invitation.dart';
import '../../../models/trip_member.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/expense_provider.dart';
import '../../../providers/invitation_provider.dart';
import '../../../providers/trip_provider.dart';
import '../../../widgets/app_floating_button.dart';
import '../../common/user_avatar.dart';
import '../../trip/companion_search_dialog.dart';
import '../../../core/utils/trip_guard_helper.dart';
import '../../../core/services/live_companion_tracker_service.dart';
import '../../../core/services/realtime_sync_service.dart';

class MembersTab extends ConsumerStatefulWidget {
  final Trip trip;

  const MembersTab({super.key, required this.trip});

  @override
  ConsumerState<MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends ConsumerState<MembersTab> {
  String _memberSearchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _callMember(String rawPhone, String memberName) async {
    final cleanPhone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) {
      AppSnackBar.showError(context, 'No valid phone number for $memberName');
      return;
    }
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          AppSnackBar.showError(context, 'Could not open phone dialer for $cleanPhone');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Unable to dial phone: $e');
      }
    }
  }
  void _openCompanionSearch() async {
    final canProceed = await TripGuardHelper.ensureTripOpenForEdit(
      context,
      ref,
      widget.trip,
      actionLabel: 'invite members',
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
          AppSnackBar.showSuccess(context, 'Trip invitation sent to "${user.displayName}"! They will join once accepted.');
        }
      },
      onCompanionSelected: (newMember) async {
        // If it's a custom or offline companion, add directly to trip
        if (newMember.id.startsWith('custom_') || newMember.id.startsWith('offline_') || newMember.id.startsWith('member_')) {
          await ref.read(tripListProvider.notifier).addMemberToTrip(currentTrip.id, newMember);
          if (mounted) {
            AppSnackBar.showSuccess(context, 'Added "${newMember.name}" as custom member!');
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
          AppSnackBar.showSuccess(context, 'Trip invitation sent to "${newMember.name}"! They will join once accepted.');
        }
      },
    );
  }

  void _showAddOfflineMemberDialog() async {
    final canProceed = await TripGuardHelper.ensureTripOpenForEdit(
      context,
      ref,
      widget.trip,
      actionLabel: 'add a custom member',
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
                'Add Member',
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
                'Add an offline member (e.g. driver, guide, family member without the app) to split expenses and track attendance.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Member Name',
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
                AppSnackBar.showSuccess(context, 'Added "$name" as custom member!');
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


  void _confirmRemoveMember(TripMember member) async {
    final canProceed = await TripGuardHelper.ensureTripOpenForEdit(
      context,
      ref,
      widget.trip,
      actionLabel: 'remove a member',
    );
    if (!canProceed || !mounted) return;

    final tripExpenses = ref.read(allExpensesProvider).where((e) => e.tripId == widget.trip.id).toList();
    final hasFinancialRecords = tripExpenses.any((e) =>
        e.paidByMemberId == member.id ||
        e.splits.any((s) => s.memberId == member.id && s.allocatedAmount > 0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Remove ${member.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to remove ${member.name} from this trip? They will lose access to shared expenses and route tracking.',
              style: const TextStyle(fontSize: 13.5),
            ),
            if (hasFinancialRecords) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, size: 18, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${member.name} has existing bills or splits. Historical records will remain in the accounting ledger.',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
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
                AppSnackBar.showSuccess(context, 'Removed ${member.name}');
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
      AppSnackBar.showError(context, '🔒 Concluded journeys cannot be abandoned. All splits and member records are preserved.');
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

  // Loop 43: Role permissions guide dialog
  void _showRoleGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primary, size: 22),
            SizedBox(width: 8),
            Text('Role Permissions Guide', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRoleRow(
              icon: Icons.workspace_premium_rounded,
              color: const Color(0xFFF59E0B),
              label: 'Creator',
              permissions: 'Full control: add/remove members, edit all expenses, manage trip settings, and delete trip.',
            ),
            const SizedBox(height: 12),
            _buildRoleRow(
              icon: Icons.person_rounded,
              color: AppTheme.primary,
              label: 'Member',
              permissions: 'Can add expenses, log stops, upload memories, and view all shared trip data.',
            ),
            const SizedBox(height: 12),
            _buildRoleRow(
              icon: Icons.visibility_rounded,
              color: const Color(0xFF64748B),
              label: 'Offline/Custom',
              permissions: 'Read-only placeholder. Cannot authenticate or sync. Managed by Creator.',
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleRow({required IconData icon, required Color color, required String label, required String permissions}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color)),
              const SizedBox(height: 2),
              Text(permissions, style: const TextStyle(fontSize: 11.5, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trips = ref.watch(tripListProvider);
    final currentTrip = trips.where((t) => t.id == widget.trip.id).firstOrNull ?? widget.trip;
    final authUser = ref.watch(authNotifierProvider).valueOrNull;
    final currentUid = authUser?.id;
    final isCreator = (currentTrip.createdByMemberId.isNotEmpty && currentUid != null && currentTrip.createdByMemberId == currentUid) ||
        (currentTrip.createdByMemberId.isNotEmpty && authUser?.email != null && currentTrip.members.any((m) => m.id == currentTrip.createdByMemberId && m.email?.trim().toLowerCase() == authUser!.email.trim().toLowerCase()));

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
    final companionPositions = ref.watch(liveCompanionTrackerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: AppFloatingActionButton.extended(
        heroTag: 'members_share_fab',
        icon: Icons.share_rounded,
        label: 'Share Trip',
        onPressed: () => _shareTripCode(shareCode, currentTrip.title),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final hPad = AppBreakpoints.isMedium(screenWidth) || AppBreakpoints.isExpanded(screenWidth) || AppBreakpoints.isLarge(screenWidth)
              ? ((screenWidth - 760) / 2).clamp(AppSpacing.md, 380.0)
              : (screenWidth < 360 ? 10.0 : AppSpacing.md);
          return ListView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: EdgeInsets.fromLTRB(hPad, AppSpacing.md, hPad, 88),
            children: [
          // 1. Members Header & Add Actions (Unified Add Member & Invite User)
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 360;
            return Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.groups_rounded, size: 20, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Travelers (${currentTrip.members.length})',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Loop 43: Role guide tooltip
                    GestureDetector(
                      onTap: () => _showRoleGuideDialog(context),
                      child: const Icon(Icons.help_outline_rounded, size: 16, color: AppTheme.primary),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showAddOfflineMemberDialog,
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                      label: Text(
                        isCompact ? 'Add' : 'Add Member',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size(0, 34),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _openCompanionSearch,
                      icon: const Icon(Icons.person_search_rounded, size: 14),
                      label: Text(
                        isCompact ? 'Invite' : 'Invite User',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size(0, 34),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),


        if (currentTrip.members.length >= 4) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _memberSearchQuery = val.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search companions by name, email, or phone...',
              hintStyle: const TextStyle(fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _memberSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      tooltip: 'Clear Member Search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _memberSearchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
        ],

        const SizedBox(height: 10),

        // 3. Members List — Individual Container Cards
        () {
          final filteredMembers = _memberSearchQuery.isEmpty
              ? currentTrip.members
              : currentTrip.members.where((m) {
                  final nameMatch = m.name.toLowerCase().contains(_memberSearchQuery);
                  final emailMatch = m.email?.toLowerCase().contains(_memberSearchQuery) ?? false;
                  final phoneMatch = m.phoneNumber?.contains(_memberSearchQuery) ?? false;
                  return nameMatch || emailMatch || phoneMatch;
                }).toList();
          final hasExplicitCreator = filteredMembers.any((m) => currentTrip.isMemberCreator(m));

          if (filteredMembers.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.withAlpha(120)),
                  const SizedBox(height: 8),
                  Text(
                    'No companions match "$_memberSearchQuery"',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              for (int index = 0; index < filteredMembers.length; index++) ...[
                if (index > 0) const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final member = filteredMembers[index];
              final isMe = (currentUid != null && member.id == currentUid) ||
                  (authUser?.email != null && member.email != null && authUser!.email.toLowerCase() == member.email!.toLowerCase());

              final isMemberCreator = (currentTrip.createdByMemberId.isNotEmpty && member.id == currentTrip.createdByMemberId) ||
                  (member.role == TripMember.roleCreator) ||
                  (currentTrip.createdByMemberId.isEmpty && !hasExplicitCreator && index == 0);

              final memberPaid = tripExpenses
                  .where((e) => e.paidByMemberId == member.id || e.paidByMemberId == member.name)
                  .fold<double>(0.0, (sum, e) => sum + e.totalAmount);

              // Action widget for trailing area
              Widget? actionWidget;
              if (isCreator && !isMe) {
                actionWidget = IconButton(
                  icon: const Icon(Icons.person_remove_rounded, size: 20, color: Colors.redAccent),
                  onPressed: () => _confirmRemoveMember(member),
                  tooltip: 'Remove member',
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                );
              } else if (isMe && !isMemberCreator) {
                actionWidget = TextButton.icon(
                  onPressed: _confirmLeaveTrip,
                  icon: const Icon(Icons.exit_to_app_rounded, size: 16, color: Colors.red),
                  label: const Text('Leave', style: TextStyle(color: Colors.red, fontSize: 12)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                );
              }

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isMemberCreator
                      ? (isDark ? const Color(0xFF1F2430) : const Color(0xFFFFFDF5))
                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isMemberCreator
                        ? (isDark ? const Color(0xFFD97706).withAlpha(160) : const Color(0xFFF59E0B))
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    width: isMemberCreator ? 1.5 : 1.0,
                  ),
                  boxShadow: isMemberCreator
                      ? [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withAlpha(isDark ? 28 : 22),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Avatar + Name/Email + Action
                    Row(
                      children: [
                        // Avatar with creator badge
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            UserAvatar(
                              name: member.name,
                              colorHex: member.colorHex,
                              size: 44,
                              border: Border.all(
                                color: isMemberCreator
                                    ? const Color(0xFFF59E0B)
                                    : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                                width: isMemberCreator ? 2.0 : 1.0,
                              ),
                            ),
                            if (isMemberCreator)
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF1F2430) : Colors.white,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(50),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.workspace_premium_rounded, size: 11, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // Name + Email
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 5,
                                runSpacing: 3,
                                children: [
                                  Text(
                                    member.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                      color: isMemberCreator && !isDark ? const Color(0xFF78350F) : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (isMemberCreator)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFD97706).withAlpha(80),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.workspace_premium_rounded, size: 10, color: Colors.white),
                                          SizedBox(width: 3),
                                          Text(
                                            'CREATOR',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (isMe)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppTheme.primary.withAlpha(50) : AppTheme.primary.withAlpha(25),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppTheme.primary.withAlpha(80), width: 0.8),
                                      ),
                                      child: const Text(
                                        'You',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (member.email != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  member.email!,
                                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : AppTheme.textMutedLight),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Action button
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isMe && member.phoneNumber != null && member.phoneNumber!.trim().isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.phone_rounded, size: 18, color: Color(0xFF10B981)),
                                tooltip: 'Call ${member.name}',
                                onPressed: () => _callMember(member.phoneNumber!, member.name),
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              ),
                            if (actionWidget != null) actionWidget,
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Row 2: Role pill + Compact Paid amount pill
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (!isMemberCreator)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withAlpha(12) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_outline_rounded,
                                  size: 11.5,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Member',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (companionPositions.containsKey(member.id) && companionPositions[member.id]?.batteryLevel != null) ...[
                          Builder(
                            builder: (context) {
                              final pos = companionPositions[member.id]!;
                              final batt = pos.batteryLevel!;
                              final isCharging = pos.isCharging == true;
                              final isLow = pos.isLowBattery;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: isLow
                                      ? (isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7))
                                      : (isCharging ? const Color(0xFF10B981).withAlpha(20) : (isDark ? Colors.white10 : Colors.grey.withAlpha(25))),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isLow ? const Color(0xFFF59E0B) : Colors.transparent,
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isCharging
                                          ? Icons.battery_charging_full_rounded
                                          : (isLow ? Icons.battery_alert_rounded : Icons.battery_std_rounded),
                                      size: 11,
                                      color: isLow
                                          ? const Color(0xFFF59E0B)
                                          : (isCharging ? const Color(0xFF10B981) : (isDark ? Colors.grey[400] : Colors.grey[700])),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$batt%',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isLow
                                            ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E))
                                            : (isCharging ? const Color(0xFF059669) : (isDark ? Colors.grey[300] : Colors.grey[700])),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                        // Loop 42: Companion last-seen timestamp + live speed pill
                        if (companionPositions.containsKey(member.id))
                          Builder(
                            builder: (context) {
                              final pos = companionPositions[member.id]!;
                              final diffMins = DateTime.now().difference(pos.lastUpdated).inMinutes;
                              final timeLabel = diffMins < 1
                                  ? 'Just now'
                                  : diffMins < 60
                                      ? '${diffMins}m ago'
                                      : '${(diffMins / 60).round()}h ago';
                              final isStale = diffMins > 10;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: isStale
                                      ? (isDark ? Colors.white.withAlpha(12) : Colors.grey.withAlpha(22))
                                      : (isDark ? const Color(0xFF10B981).withAlpha(25) : const Color(0xFFECFDF5)),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isStale ? Colors.transparent : const Color(0xFF10B981).withAlpha(80),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isStale ? Icons.location_off_rounded : Icons.location_on_rounded,
                                      size: 11,
                                      color: isStale ? Colors.grey : const Color(0xFF059669),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      timeLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isStale
                                            ? (isDark ? Colors.grey[400] : Colors.grey[600])
                                            : const Color(0xFF059669),
                                      ),
                                    ),
                                    if (pos.speedKmh > 2.0) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '• ${pos.speedKmh.toStringAsFixed(0)} km/h',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        if (!isMe && !member.id.startsWith('offline_')) ...[
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () {
                              final myName = authUser?.displayName ?? 'A companion';
                              ref.read(realtimeSyncServiceProvider).nudgeCompanion(currentTrip.id, member.id, myName);
                              AppSnackBar.showSuccess(context, 'Convoy ping sent to ${member.name}');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.primary.withAlpha(30) : AppTheme.primary.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.primary.withAlpha(60), width: 0.8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.notifications_active_outlined, size: 11, color: AppTheme.primary),
                                  SizedBox(width: 3),
                                  Text(
                                    'Nudge',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }(),

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
            child: Column(
              children: [
                for (int index = 0; index < tripInvitations.length; index++) ...[
                  if (index > 0) const Divider(height: 1),
                  Builder(
                    builder: (context) {
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
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  },
),
);
}
}

