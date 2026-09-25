import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/trip.dart';
import '../../providers/trip_provider.dart';
import '../theme/app_theme.dart';

class TripGuardHelper {
  /// Checks if [trip] is concluded/ended.
  /// If it is ended, shows a professional modal explaining that editing requires reopening the trip to live status.
  /// Returns `true` if the trip is active (or was successfully reopened by the user), allowing the edit/add action to proceed.
  /// Returns `false` if the trip is ended and user cancelled.
  static Future<bool> ensureTripOpenForEdit(
    BuildContext context,
    WidgetRef ref,
    Trip trip, {
    String actionLabel = 'make changes',
  }) async {
    final liveTrip = ref.read(tripListProvider).where((t) => t.id == trip.id).firstOrNull ?? trip;
    final isEnded = liveTrip.isCompleted || liveTrip.status == 'completed';

    if (!isEnded) return true;

    // Show reopening dialog
    final shouldReopen = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_clock_rounded, color: Color(0xFFD97706), size: 28),
          ),
          title: const Text(
            'Journey Concluded',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This trip is currently marked as concluded. To $actionLabel, you must first reopen this journey to active / live status.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.primary),
                    SizedBox(width: 6),
                    Text(
                      'Reopening enables all edits & real-time sync',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text('Reopen Journey', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (shouldReopen == true && context.mounted) {
      // Reopen trip to live status
      final updated = liveTrip.copyWith(isCompleted: false);
      await ref.read(tripListProvider.notifier).updateTrip(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Journey reopened to live status. Edits enabled!'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return true;
    }

    return false;
  }
}
