import '../../providers/settlement_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/cloud_trip_sync_service.dart';
import '../../core/services/pdf_export_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_dialogs.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/utils/page_transitions.dart';
import '../../models/trip.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';
import '../stats/trip_analytics_screen.dart';
import '../trip_detail/edit_trip_dialog.dart';
import '../trip_detail/share_trip_sheet.dart';
import '../../core/services/user_service.dart';

/// Unified senior-developer trip options menu button.
/// Provides identical, clean trip management capabilities on both
/// CurrentTripTab and TripDetailScreen.
class TripMenuButton extends ConsumerWidget {
  final Trip trip;
  final VoidCallback? onTripDeleted;
  final double iconSize;
  final Color? iconColor;

  const TripMenuButton({
    super.key,
    required this.trip,
    this.onTripDeleted,
    this.iconSize = 22,
    this.iconColor,
  });

  void _openShareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => ShareTripSheet(trip: trip),
    );
  }

  void _showEndTripExperienceDialog(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.read(authNotifierProvider).valueOrNull?.id ?? UserService.getCurrentUser().id;
    double rating = trip.memberRatings[currentUserId] ?? trip.rating ?? 5.0;
    final reviewController = TextEditingController(text: trip.memberReviews[currentUserId] ?? trip.experienceReview ?? '');
    final quickHighlights = [
      '⛰️ Scenic Views',
      '🍜 Delicious Food',
      '🛣️ Smooth Drive',
      '💰 Budget Friendly',
      '🏕️ Great Stay',
      '🎉 Fun Companions',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 14,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.flag_circle_rounded, color: Colors.amber, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.isCompleted ? 'Trip Experience & Memories' : 'End Expedition & Review',
                              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                            ),
                            Text(
                              trip.title,
                              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Rating Stars with FittedBox (Item 13 & 14)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'How was your journey experience?',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final starValue = (index + 1).toDouble();
                              final isFilled = rating >= starValue;
                              return GestureDetector(
                                onTap: () => setSheetState(() => rating = starValue),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(
                                    isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                                    size: 32,
                                    color: isFilled ? Colors.amber[600] : Colors.grey[400],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        if (trip.reviewCount > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                '${trip.averageRating ?? 0.0} avg • Reviewed by ${trip.reviewCount} of ${trip.members.length} traveler${trip.members.length == 1 ? "" : "s"}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey[300] : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Quick Highlight Tags
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: quickHighlights.map((tag) {
                      final hasTag = reviewController.text.contains(tag);
                      return ChoiceChip(
                        showCheckmark: false,
                        label: Text(tag, style: const TextStyle(fontSize: 11)),
                        selected: hasTag,
                        selectedColor: Colors.amber.withAlpha(40),
                        labelStyle: TextStyle(
                          color: hasTag ? Colors.amber[900] : null,
                          fontWeight: hasTag ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          setSheetState(() {
                            if (selected) {
                              if (reviewController.text.isEmpty) {
                                reviewController.text = tag;
                              } else {
                                reviewController.text = '${reviewController.text} • $tag';
                              }
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Review Text Field
                  TextField(
                    controller: reviewController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Trip Notes / Overall Experience',
                      hintText: 'Memorable moments, highlights, recommendations...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Save & Complete Button
                  FilledButton.icon(
                    onPressed: () {
                      final updatedMemberRatings = Map<String, double>.from(trip.memberRatings);
                      updatedMemberRatings[currentUserId] = rating;

                      final updatedMemberReviews = Map<String, String>.from(trip.memberReviews);
                      final reviewText = reviewController.text.trim();
                      if (reviewText.isNotEmpty) {
                        updatedMemberReviews[currentUserId] = reviewText;
                      }

                      final totalStars = updatedMemberRatings.values.fold<double>(0.0, (sum, r) => sum + r);
                      final avgRating = double.parse((totalStars / updatedMemberRatings.length).toStringAsFixed(1));

                      final updated = trip.copyWith(
                        isCompleted: true,
                        rating: avgRating,
                        experienceReview: reviewText.isNotEmpty ? reviewText : trip.experienceReview,
                        memberRatings: updatedMemberRatings,
                        memberReviews: updatedMemberReviews,
                        completedAt: trip.completedAt ?? DateTime.now(),
                      );
                      ref.read(tripListProvider.notifier).updateTrip(updated);
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🎉 Trip experience recorded & journey completed!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      trip.isCompleted ? 'Update Review' : 'Complete Expedition',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

                  if (trip.isCompleted) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        ref.read(tripListProvider.notifier).reopenTrip(trip.id);
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🔄 Trip reopened as active live journey.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: const Text('Reopen Trip as Ongoing / Live', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmReopenTrip(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Reopen Journey?',
      message: 'Reopening "${trip.title}" will set its status back to active, enabling live GPS convoy tracking, itinerary additions, and expense logging.',
      confirmLabel: 'Reopen Journey',
      icon: Icons.restart_alt_rounded,
    );

    if (confirmed && context.mounted) {
      await ref.read(tripListProvider.notifier).reopenTrip(trip.id);
      if (context.mounted) {
        AppSnackBar.showSuccess(context, '🔄 Journey reactivated! Ready for tracking.');
      }
    }
  }

  void _confirmDeleteTrip(BuildContext context, WidgetRef ref) {
    if (trip.isCompleted) {
      AppSnackBar.showError(context, '🔒 Concluded journeys are permanently preserved for auditing and cannot be deleted.');
      return;
    }
    final expenses = ref.read(allExpensesProvider).where((e) => e.tripId == trip.id).toList();
    final companionCount = trip.members.where((m) => m.id != trip.createdByMemberId).length;
    final hasExpenses = expenses.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Delete for Everyone?',
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
              Text('Are you sure you want to permanently delete "${trip.title}"?'),
              const SizedBox(height: 12),
              if (companionCount > 0)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⚠️ This will remove the trip for you and all $companionCount companion(s). All shared logs and memories will be permanently deleted.',
                    style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500),
                  ),
                ),
              if (hasExpenses)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Note: ${expenses.length} recorded expense(s) will be erased.',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
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
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(tripListProvider.notifier).deleteTrip(trip.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Trip deleted permanently.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                onTripDeleted?.call();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Trip'),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveTrip(BuildContext context, WidgetRef ref) async {
    if (trip.isCompleted) {
      AppSnackBar.showError(context, '🔒 Concluded journeys cannot be abandoned. All splits and member records are preserved.');
      return;
    }

    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Leave Journey?',
      message: 'You will no longer receive live location updates or shared ledger sync for "${trip.title}".',
      confirmLabel: 'Leave Journey',
      isDestructive: true,
      icon: Icons.exit_to_app_rounded,
    );

    if (confirmed && context.mounted) {
      ref.read(tripListProvider.notifier).leaveTrip(trip.id);
      if (context.mounted) {
        AppSnackBar.showInfo(context, 'You left the trip.');
        onTripDeleted?.call();
      }
    }
  }

  Future<void> _exportPdf(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preparing detailed Travel Summary PDF...'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
    try {
      final stoppages = ref.read(currentTripStoppagesProvider);
      final expenses = ref.read(currentTripExpensesProvider);
      final netBalances = ref.read(tripNetBalancesProvider);
      final transfers = ref.read(simplifiedTransfersProvider);
      await PdfExportService.exportTripSummaryPdf(
        trip: trip,
        stoppages: stoppages,
        expenses: expenses,
        netBalances: netBalances,
        transfers: transfers,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF Export failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authNotifierProvider).valueOrNull;
    final isLead = trip.isCreator(authUser?.id);

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, size: iconSize, color: iconColor),
      tooltip: 'Trip Options',
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 240),
      position: PopupMenuPosition.under,
      onSelected: (val) async {
        if (val == 'share') {
          _openShareSheet(context);
        } else if (val == 'edit_trip') {
          EditTripDialog.show(context, trip);
        } else if (val == 'end_trip') {
          _showEndTripExperienceDialog(context, ref);
        } else if (val == 'reopen_trip') {
          _confirmReopenTrip(context, ref);
        } else if (val == 'analytics') {
          AppNavigator.push(
            context,
            TripAnalyticsScreen(tripId: trip.id),
          );
        } else if (val == 'pdf') {
          await _exportPdf(context, ref);
        } else if (val == 'delete') {
          _confirmDeleteTrip(context, ref);
        } else if (val == 'leave') {
          _confirmLeaveTrip(context, ref);
        }
      },
      itemBuilder: (context) {
        return [
          // 1. Share & Sync (Disabled if trip is concluded - Item 11)
          if (!trip.isCompleted)
            PopupMenuItem(
              height: 42,
              value: 'share',
              child: Row(
                children: [
                  const Icon(Icons.share_outlined, color: AppTheme.secondary, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Share Trip', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      CloudTripSyncService.getRoomCode(trip.id, trip: trip).replaceAll('TRIP-', ''),
                      style: const TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),

          // 2. Edit Trip Details & Companions
          const PopupMenuItem(
            height: 40,
            value: 'edit_trip',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, color: AppTheme.primary, size: 18),
                SizedBox(width: 10),
                Text('Edit Trip', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          // 3. End Trip / Experience Review / Reopen Journey (Creator Only)
          if (isLead) ...[
            if (trip.isCompleted)
              const PopupMenuItem(
                height: 40,
                value: 'reopen_trip',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt_rounded, color: Color(0xFF10B981), size: 18),
                    SizedBox(width: 10),
                    Text('Reopen Journey', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                  ],
                ),
              )
            else
              const PopupMenuItem(
                height: 40,
                value: 'end_trip',
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      color: Color(0xFFFF8F00),
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'End Trip & Review',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF6F00),
                      ),
                    ),
                  ],
                ),
              ),
            if (trip.isCompleted)
              const PopupMenuItem(
                height: 40,
                value: 'end_trip',
                child: Row(
                  children: [
                    Icon(Icons.star_outline_rounded, color: Colors.amber, size: 18),
                    SizedBox(width: 10),
                    Text('Edit Trip Review', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],

          // 4. Trip Analytics
          const PopupMenuItem(
            height: 40,
            value: 'analytics',
            child: Row(
              children: [
                Icon(Icons.insights_outlined, color: AppTheme.primary, size: 18),
                SizedBox(width: 10),
                Text('Trip Analytics', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          // 5. Export PDF
          const PopupMenuItem(
            height: 40,
            value: 'pdf',
            child: Row(
              children: [
                Icon(Icons.picture_as_pdf_outlined, color: Colors.deepOrange, size: 18),
                SizedBox(width: 10),
                Text('Export PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          // 6. Role-based: Delete for Everyone (Creator) vs Leave Trip (Companion)
          // Concluded trips cannot be deleted or abandoned (Items 9 & 10)
          if (!trip.isCompleted) ...[
            const PopupMenuDivider(height: 8),
            if (isLead)
              const PopupMenuItem(
                height: 38,
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever_rounded, color: Colors.red, size: 18),
                    SizedBox(width: 10),
                    Text('Delete for Everyone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red)),
                  ],
                ),
              )
            else
              const PopupMenuItem(
                height: 38,
                value: 'leave',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app_rounded, color: Color(0xFFFF6F00), size: 18),
                    SizedBox(width: 10),
                    Text('Leave Trip', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFFF6F00))),
                  ],
                ),
              ),
          ],
        ];
      },
    );
  }
}
