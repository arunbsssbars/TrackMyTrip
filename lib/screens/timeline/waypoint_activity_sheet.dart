import 'package:flutter/material.dart';
import '../../models/waypoint_activity_item.dart';
import '../../core/services/waypoint_activity_service.dart';

class WaypointActivitySheet extends StatefulWidget {
  final String stoppageName;
  final List<WaypointActivityItem> initialItems;
  final ValueChanged<List<WaypointActivityItem>>? onItemsChanged;

  const WaypointActivitySheet({
    super.key,
    required this.stoppageName,
    required this.initialItems,
    this.onItemsChanged,
  });

  @override
  State<WaypointActivitySheet> createState() => _WaypointActivitySheetState();
}

class _WaypointActivitySheetState extends State<WaypointActivitySheet> {
  late List<WaypointActivityItem> _items;
  final TextEditingController _addController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.initialItems);
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  void _addItem() {
    final text = _addController.text.trim();
    if (text.isEmpty) return;

    final newItem = WaypointActivityItem(
      id: 'act_${DateTime.now().millisecondsSinceEpoch}',
      stoppageId: widget.stoppageName,
      title: text,
      createdAt: DateTime.now(),
    );

    setState(() {
      _items.add(newItem);
      _addController.clear();
    });
    widget.onItemsChanged?.call(_items);
  }

  void _toggle(int index) {
    setState(() {
      _items[index] = WaypointActivityService().toggleItemCompletion(_items[index]);
    });
    widget.onItemsChanged?.call(_items);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = WaypointActivityService().calculateProgressRatio(_items);
    final completedCount = _items.where((i) => i.isCompleted).length;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      constraints: const BoxConstraints(maxHeight: 600),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              Icon(Icons.checklist_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Waypoint Tasks: ${widget.stoppageName}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$completedCount/${_items.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0 ? Colors.green : theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Task List
          Flexible(
            child: _items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No activities yet. Add one below!',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          dense: true,
                          value: item.isCompleted,
                          onChanged: (_) => _toggle(index),
                          title: Text(
                            item.title,
                            style: TextStyle(
                              decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                              color: item.isCompleted
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.onSurface,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),

          // Add task input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addController,
                  decoration: InputDecoration(
                    hintText: 'Add stoppage task or note...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onSubmitted: (_) => _addItem(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addItem,
                icon: const Icon(Icons.add, size: 20),
                tooltip: 'Add item',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
