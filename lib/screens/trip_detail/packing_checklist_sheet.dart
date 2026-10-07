import 'package:flutter/material.dart';
import '../../core/services/packing_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/packing_item.dart';

class PackingChecklistSheet extends StatefulWidget {
  final String tripId;
  final String tripTitle;

  const PackingChecklistSheet({
    super.key,
    required this.tripId,
    required this.tripTitle,
  });

  static Future<void> show(BuildContext context, {required String tripId, required String tripTitle}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PackingChecklistSheet(tripId: tripId, tripTitle: tripTitle),
    );
  }

  @override
  State<PackingChecklistSheet> createState() => _PackingChecklistSheetState();
}

class _PackingChecklistSheetState extends State<PackingChecklistSheet> {
  String _selectedCategory = 'All';
  late List<PackingItem> _items;
  final TextEditingController _newItemController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }

  void _loadItems() {
    setState(() {
      _items = List.from(PackingService.getItemsForTrip(widget.tripId));
    });
  }

  void _toggle(String itemId) {
    PackingService.togglePacked(widget.tripId, itemId);
    _loadItems();
  }

  void _delete(String itemId) {
    PackingService.deleteItem(widget.tripId, itemId);
    _loadItems();
  }

  void _addNewItem() {
    final title = _newItemController.text.trim();
    if (title.isEmpty) return;

    final cat = _selectedCategory == 'All' ? 'Gear' : _selectedCategory;
    PackingService.addItem(widget.tripId, title: title, category: cat);
    _newItemController.clear();
    _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stats = PackingService.getStats(widget.tripId);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    final filteredItems = _selectedCategory == 'All'
        ? _items
        : _items.where((i) => i.category == _selectedCategory).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: (screenHeight * 0.9).clamp(450.0, 800.0),
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 20 + bottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(100),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.backpack_rounded, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Packing Checklist',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${stats.packedCount}/${stats.totalCount} Packed • ${(stats.progress * 100).toInt()}% Ready',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: stats.progress,
              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 14),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: PackingService.categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
                    selected: isSelected,
                    selectedColor: AppTheme.primary,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Add item input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newItemController,
                  decoration: InputDecoration(
                    hintText: 'Add gear to $_selectedCategory...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addNewItem(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.add, size: 20),
                tooltip: 'Add item',
                style: IconButton.styleFrom(backgroundColor: AppTheme.primary),
                onPressed: _addNewItem,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Checklist items list
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Text(
                      'No items in $_selectedCategory',
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: item.isPacked
                                    ? AppTheme.primary.withAlpha(100)
                                    : Colors.grey.withAlpha(40),
                              ),
                            ),
                            child: CheckboxListTile(
                              value: item.isPacked,
                              activeColor: AppTheme.primary,
                              title: Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  decoration: item.isPacked ? TextDecoration.lineThrough : null,
                                  color: item.isPacked ? Colors.grey : null,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${item.category} • Qty: ${item.quantity}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                              secondary: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                tooltip: 'Remove',
                                onPressed: () => _delete(item.id),
                              ),
                              onChanged: (_) => _toggle(item.id),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
