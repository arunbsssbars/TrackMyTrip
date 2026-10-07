import 'package:flutter/material.dart';
import '../../models/trip_archive_bundle.dart';

class TripArchiveDialog extends StatelessWidget {
  final TripArchiveBundle bundle;
  final VoidCallback? onShareOrSave;

  const TripArchiveDialog({
    super.key,
    required this.bundle,
    this.onShareOrSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    final shortChecksum = bundle.checksumSha256.length > 16
        ? '${bundle.checksumSha256.substring(0, 8)}...${bundle.checksumSha256.substring(bundle.checksumSha256.length - 8)}'
        : bundle.checksumSha256;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 440, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.archive_rounded, color: theme.colorScheme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Offline Trip Archive (.tmt)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            bundle.tripTitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Info card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Stoppages Recorded', '${bundle.stoppages.length}'),
                      const SizedBox(height: 6),
                      _buildInfoRow('Expenses & Splits', '${bundle.expenses.length}'),
                      const SizedBox(height: 6),
                      _buildInfoRow('Packing Checklist', '${bundle.packingItems.length} items'),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.verified_user_rounded, size: 16, color: Colors.teal.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'SHA-256: $shortChecksum',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: Colors.teal.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'This archive can be transferred directly peer-to-peer or stored offline for full disaster recovery.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // Action buttons - Responsive Wrap
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context, rootNavigator: true).maybePop(),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                        ),
                        child: const Text('Close'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          onShareOrSave?.call();
                          Navigator.of(context, rootNavigator: true).maybePop();
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('Export & Share'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
