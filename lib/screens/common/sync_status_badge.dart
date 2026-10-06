import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/offline_sync_engine.dart';
import '../../core/theme/app_theme.dart';
import '../../core/design_system/design_system.dart';

class SyncStatusBadge extends ConsumerWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(offlineSyncEngineProvider);
    final pendingCount = engine.pendingCount;
    final isSyncing = engine.isSyncing;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color badgeColor;
    Color textColor;
    IconData icon;
    String label;

    if (isSyncing) {
      badgeColor = AppTheme.primary.withAlpha(30);
      textColor = AppTheme.primary;
      icon = Icons.sync_rounded;
      label = 'Syncing...';
    } else if (pendingCount > 0) {
      badgeColor = Colors.amber.withAlpha(40);
      textColor = isDark ? Colors.amber[300]! : Colors.amber[900]!;
      icon = Icons.cloud_queue_rounded;
      label = '$pendingCount offline';
    } else {
      badgeColor = Colors.green.withAlpha(25);
      textColor = isDark ? Colors.green[300]! : Colors.green[800]!;
      icon = Icons.cloud_done_rounded;
      label = 'Synced';
    }

    return Tooltip(
      message: 'Cloud Sync: $label. Tap for details',
      child: Semantics(
        button: true,
        label: 'Sync Status: $label',
        child: GestureDetector(
          onTap: () => _showSyncDetailsSheet(context, ref, engine),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: textColor.withAlpha(50), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSyncing)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  )
                else
                  Icon(icon, size: 13, color: textColor),
                const SizedBox(width: 5),
                AppResilientText.badge(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSyncDetailsSheet(BuildContext context, WidgetRef ref, OfflineSyncEngine engine) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final pending = engine.pendingMutations;
            final isSyncing = engine.isSyncing;

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.cloud_sync_rounded, color: AppTheme.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Offline Sync Outbox',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              pending.isEmpty
                                  ? 'All changes are safely backed up to cloud'
                                  : '${pending.length} changes queued locally on your device',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (pending.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.green.withAlpha(40)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your trips, stops, and bills are 100% up to date with the server.',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    if (engine.lastSyncError != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withAlpha(80)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                engine.lastSyncError!,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.amber[200] : const Color(0xFF92400E),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: pending.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, idx) {
                          final m = pending[idx];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.schedule_rounded, size: 16, color: Colors.amber),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${m.action.name.toUpperCase()} (${m.entityType})',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Text(
                                  'Pending',
                                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                                  tooltip: 'Dismiss mutation',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () async {
                                    await engine.removeMutation(m.id);
                                    setModalState(() {});
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Action Buttons: Sync Now & Mark All as Synced
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isSyncing
                                ? null
                                : () async {
                                    await engine.resolveAllLocally();
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Offline outbox cleared. All records marked synced!'),
                                          backgroundColor: AppTheme.primary,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.done_all_rounded, size: 16),
                            label: const Text('Mark All Synced', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1), width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: isSyncing
                                ? null
                                : () async {
                                    setModalState(() {});
                                    final success = await engine.syncPendingMutationsNow();
                                    if (!context.mounted) return;
                                    setModalState(() {});
                                    if (success) {
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('All pending changes successfully synced!'),
                                          backgroundColor: Colors.green,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                            icon: isSyncing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.sync_rounded, size: 16),
                            label: Text(
                              isSyncing ? 'Syncing...' : 'Sync Now',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
