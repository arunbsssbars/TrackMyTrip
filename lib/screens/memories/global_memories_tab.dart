import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/memory.dart';
import '../../providers/memory_provider.dart';
import '../../providers/trip_provider.dart';
import '../trip_detail/trip_detail_screen.dart';
import '../../core/utils/page_transitions.dart';

class GlobalMemoriesTab extends ConsumerStatefulWidget {
  const GlobalMemoriesTab({super.key});

  @override
  ConsumerState<GlobalMemoriesTab> createState() => _GlobalMemoriesTabState();
}

class _GlobalMemoriesTabState extends ConsumerState<GlobalMemoriesTab> {
  String? _selectedTripId; // null = all trips

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allMemories = ref.watch(allMemoriesProvider);
    final trips = ref.watch(tripListProvider);

    final filteredMemories = _selectedTripId == null
        ? allMemories
        : allMemories.where((m) => m.tripId == _selectedTripId).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFEC4899).withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.photo_library_rounded, color: Color(0xFFEC4899), size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Trip Memories',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.3),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Trip Filter Selector
          if (trips.isNotEmpty)
            Container(
              height: 48,
              color: isDark ? const Color(0xFF1E293B).withAlpha(140) : Colors.white,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                children: [
                  ChoiceChip(
                    showCheckmark: false,
                    selected: _selectedTripId == null,
                    label: const Text('All Trips', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    onSelected: (_) => setState(() => _selectedTripId = null),
                  ),
                  const SizedBox(width: 8),
                  ...trips.map((t) {
                    final isSelected = _selectedTripId == t.id;
                    final tripMemoriesCount = allMemories.where((m) => m.tripId == t.id).length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        showCheckmark: false,
                        selected: isSelected,
                        label: Text(
                          '${t.title} ($tripMemoriesCount)',
                          style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                        ),
                        onSelected: (_) => setState(() => _selectedTripId = t.id),
                      ),
                    );
                  }),
                ],
              ),
            ),
          const Divider(height: 1),

          // Grid of Photos
          Expanded(
            child: filteredMemories.isEmpty
                ? _buildEmptyState(isDark)
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: filteredMemories.length,
                    itemBuilder: (context, index) {
                      final memory = filteredMemories[index];
                      final trip = trips.where((t) => t.id == memory.tripId).firstOrNull;

                      return _buildMemoryCard(context, memory, trip, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(BuildContext context, Memory memory, dynamic trip, bool isDark) {
    return GestureDetector(
      onTap: () {
        if (trip != null) {
          AppNavigator.push(context, TripDetailScreen(tripId: trip.id, initialTabIndex: 5));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 40 : 12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(memory),
                  if (trip != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(140),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          trip.title,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (memory.caption != null && memory.caption!.isNotEmpty)
                    Text(
                      memory.caption!,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    const Text(
                      'Trip Memory',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    '${memory.createdAt.day}/${memory.createdAt.month}/${memory.createdAt.year}',
                    style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(Memory memory) {
    final path = memory.displayPath;
    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.primary.withAlpha(30),
      child: const Center(
        child: Icon(Icons.photo_rounded, size: 36, color: AppTheme.primary),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_camera_back_rounded, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              'No travel memories yet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Photos and notes captured at stoppages during your trips will appear here in your gallery.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
