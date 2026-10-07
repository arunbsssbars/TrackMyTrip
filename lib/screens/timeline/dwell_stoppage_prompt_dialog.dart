import 'package:flutter/material.dart';
import '../../models/dwell_detection_event.dart';

class DwellStoppagePromptDialog extends StatefulWidget {
  final DwellDetectionEvent event;
  final ValueChanged<String>? onConfirmStoppage;
  final VoidCallback? onDismiss;

  const DwellStoppagePromptDialog({
    super.key,
    required this.event,
    this.onConfirmStoppage,
    this.onDismiss,
  });

  @override
  State<DwellStoppagePromptDialog> createState() => _DwellStoppagePromptDialogState();
}

class _DwellStoppagePromptDialogState extends State<DwellStoppagePromptDialog> {
  String _selectedTag = 'Food & Rest';
  final List<String> _quickTags = [
    'Food & Rest',
    'Fuel Station',
    'Scenic View',
    'Toll Plaza',
    'Hotel Stay',
    'Maintenance',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = widget.event;

    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxHeight),
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
                      child: Icon(Icons.location_on_rounded, color: theme.colorScheme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stoppage Detected?',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Stationary for ${event.formattedDuration}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
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

                // Coords & detail text
                Text(
                  'Your expedition convoy has paused here. Would you like to record this waypoint on the trip timeline?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),

                // Quick Tag Selector
                Text(
                  'Select Stoppage Tag:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickTags.map((tag) {
                    final isSelected = _selectedTag == tag;
                    return ChoiceChip(
                      label: Text(tag, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedTag = tag);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Action buttons - Responsive Wrap avoids overflow on narrow screen / 1.5x font
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () {
                          widget.onDismiss?.call();
                          Navigator.of(context, rootNavigator: true).maybePop();
                        },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                        ),
                        child: const Text('Dismiss'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          widget.onConfirmStoppage?.call(_selectedTag);
                          Navigator.of(context, rootNavigator: true).maybePop();
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Log Stoppage'),
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
}
