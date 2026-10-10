import '../../../core/design_system/design_system.dart';
import '../../../core/utils/date_formatter.dart';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/media_cache_service.dart';
import '../../../core/services/realtime_sync_service.dart';
import '../../../widgets/cloudinary_progressive_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/memory.dart';
import '../../../models/stoppage.dart';
import '../../../models/trip.dart';
import '../../../providers/memory_provider.dart';
import '../../../providers/stoppage_provider.dart';
import '../../../core/utils/trip_guard_helper.dart';
import '../../memories/add_memory_dialog.dart';

enum _MemoriesViewMode { byStoppage, allPhotosGrid }

enum _MemoryFilterTab { all, myPhotos, favorites }

class MemoriesTab extends ConsumerStatefulWidget {
  final Trip trip;

  const MemoriesTab({super.key, required this.trip});

  @override
  ConsumerState<MemoriesTab> createState() => _MemoriesTabState();

  static Widget buildMemoryImage(String imagePath, {String? localPath}) {
    return CloudinaryProgressiveImage(
      imageUrl: imagePath,
      localPath: localPath,
      fit: BoxFit.cover,
      errorWidget: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      placeholder: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _MemoriesTabState extends ConsumerState<MemoriesTab> {
  _MemoriesViewMode _viewMode = _MemoriesViewMode.byStoppage;
  _MemoryFilterTab _filterTab = _MemoryFilterTab.all;
  String? _selectedMemberFilterId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _newestFirst = true;
  bool _isSyncingPending = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedMemoryIds = <String>{};

  void _enterSelectionMode(String? initialMemoryId) {
    setState(() {
      _isSelectionMode = true;
      if (initialMemoryId != null) {
        _selectedMemoryIds.add(initialMemoryId);
      }
    });
    HapticFeedback.selectionClick();
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMemoryIds.clear();
    });
  }

  void _toggleMemorySelection(String memoryId) {
    setState(() {
      if (_selectedMemoryIds.contains(memoryId)) {
        _selectedMemoryIds.remove(memoryId);
      } else {
        _selectedMemoryIds.add(memoryId);
      }
    });
    HapticFeedback.selectionClick();
  }

  void _toggleSelectAll(List<Memory> visibleMemories) {
    setState(() {
      if (_selectedMemoryIds.length == visibleMemories.length) {
        _selectedMemoryIds.clear();
      } else {
        _selectedMemoryIds.addAll(visibleMemories.map((m) => m.id));
      }
    });
    HapticFeedback.selectionClick();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAddMemoryDialog(BuildContext context, Stoppage stoppage) async {
    final canProceed = await TripGuardHelper.ensureTripOpenForEdit(
      context,
      ref,
      widget.trip,
      actionLabel: 'add memories / photos',
    );
    if (!canProceed || !context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => AddMemoryDialog(tripId: widget.trip.id, stoppage: stoppage),
    );
  }

  void _openGalleryViewer({
    required List<Memory> memories,
    required int initialIndex,
    required List<Stoppage> stoppages,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, anim1, anim2) => FullScreenGalleryViewer(
          memories: memories,
          initialIndex: initialIndex,
          trip: widget.trip,
          stoppages: stoppages,
        ),
        transitionsBuilder: (context, anim1, anim2, child) {
          return FadeTransition(opacity: anim1, child: child);
        },
      ),
    );
  }

  void _showEditCaptionDialog(BuildContext context, Memory memory) {
    final controller = TextEditingController(text: memory.caption ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Edit Caption', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter caption or travel note...',
            labelText: 'Caption',
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(allMemoriesProvider.notifier).updateCaption(memory.id, controller.text);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Caption updated')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, Memory memory) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Memory?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'This photo will be removed from the trip and deleted from Cloudinary storage.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: const Text('Delete'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(allMemoriesProvider.notifier).deleteMemory(memory.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Memory deleted')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSelected(BuildContext context) {
    if (_selectedMemoryIds.isEmpty) return;
    final count = _selectedMemoryIds.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete $count ${count == 1 ? "Memory" : "Memories"}?',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          count == 1
              ? 'This photo will be permanently removed from the trip and deleted from Cloudinary storage.'
              : 'These $count photos will be permanently removed from the trip and deleted from Cloudinary storage.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.delete_sweep_rounded, size: 16),
            label: Text('Delete ($count)'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final idsToDelete = _selectedMemoryIds.toList();
              _exitSelectionMode();
              final result = await ref.read(allMemoriesProvider.notifier).deleteMemoriesBatch(idsToDelete);
              if (context.mounted) {
                final succeeded = result['succeeded'] ?? count;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$succeeded ${succeeded == 1 ? "memory" : "memories"} deleted'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context, Memory memory, List<Memory> allTripMemories, List<Stoppage> stoppages) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.fullscreen_rounded, color: AppTheme.primary),
              title: const Text('View Full Screen Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(ctx).pop();
                final idx = allTripMemories.indexOf(memory);
                _openGalleryViewer(
                  memories: allTripMemories,
                  initialIndex: idx >= 0 ? idx : 0,
                  stoppages: stoppages,
                );
              },
            ),
            if (memory.localPath != null &&
                memory.uploadStatus != MediaUploadStatus.uploaded)
              ListTile(
                leading: const Icon(Icons.cloud_upload_rounded, color: Colors.blue),
                title: const Text('Retry Cloud Upload', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ref.read(mediaCacheServiceProvider).retryFailed(tripId: widget.trip.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Retrying cloud upload...')),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit_note_rounded, color: AppTheme.primary),
              title: const Text('Edit Caption', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(ctx).pop();
                _showEditCaptionDialog(context, memory);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded, color: AppTheme.secondary),
              title: const Text('Share Photo', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(ctx).pop();
                final caption = memory.caption ?? 'Trip memory from ${widget.trip.title}';
                if (!kIsWeb && memory.localPath != null && File(memory.localPath!).existsSync()) {
                  Share.shareXFiles([XFile(memory.localPath!)], text: caption);
                } else {
                  Share.share('$caption\n${memory.displayPath}');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.red),
              title: const Text('Delete Memory', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
              onTap: () {
                Navigator.of(ctx).pop();
                _showDeleteConfirm(context, memory);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stoppages = ref.watch(tripStoppagesProvider(widget.trip.id));
    final rawMemories = ref.watch(tripMemoriesProvider(widget.trip.id));
    final myMember = widget.trip.currentUserMember;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter memories by tab, member, and search query
    final filteredMemories = rawMemories.where((m) {
      // 1. Member filter
      if (_selectedMemberFilterId != null) {
        if (m.uploadedByMemberId != _selectedMemberFilterId) return false;
      }

      // 2. Tab filter
      if (_filterTab == _MemoryFilterTab.myPhotos) {
        if (myMember == null || m.uploadedByMemberId != myMember.id) return false;
      } else if (_filterTab == _MemoryFilterTab.favorites) {
        if (myMember == null || !m.likedByMemberIds.contains(myMember.id)) return false;
      }

      // 2. Search query filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final caption = m.caption?.toLowerCase() ?? '';
        final uploaderName = widget.trip.getMemberName(m.uploadedByMemberId).toLowerCase();
        final stop = stoppages.where((s) => s.id == m.stoppageId).firstOrNull;
        final stopName = stop?.name.toLowerCase() ?? '';
        return caption.contains(query) || uploaderName.contains(query) || stopName.contains(query);
      }

      return true;
    }).toList();

    filteredMemories.sort((a, b) =>
        _newestFirst ? b.createdAt.compareTo(a.createdAt) : a.createdAt.compareTo(b.createdAt));

    // Check for pending/local uploads in this trip that actually exist on disk
    final pendingCount = rawMemories.where((m) {
      if (m.uploadStatus == MediaUploadStatus.uploaded) return false;
      if (m.remoteUrl != null && m.remoteUrl!.isNotEmpty) return false;
      if (m.mediaPath.startsWith('http://') || m.mediaPath.startsWith('https://')) return false;
      if (m.uploadStatus != MediaUploadStatus.failed && m.uploadStatus != MediaUploadStatus.local) {
        return false;
      }
      if (kIsWeb) return true;
      final path = m.localPath ?? m.mediaPath;
      if (path.startsWith('http://') || path.startsWith('https://')) return false;
      return File(path).existsSync();
    }).length;

    // Watch real-time companion upload presence
    final activeUploaders = ref.watch(activeMemoryUploadersProvider(widget.trip.id));

    if (rawMemories.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library_outlined, size: 54, color: AppTheme.secondary),
              ),
              const SizedBox(height: 16),
              const Text('No Memories Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Share memorable photos captured at each stoppage with your travel companions.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : AppTheme.textMutedLight,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  final targetStop = stoppages.isNotEmpty
                      ? stoppages.first
                      : Stoppage(
                          id: 'general_${widget.trip.id}',
                          tripId: widget.trip.id,
                          name: widget.trip.title,
                          latitude: 0.0,
                          longitude: 0.0,
                          arrivedAt: DateTime.now(),
                          category: 'general',
                          createdBy: widget.trip.createdByMemberId,
                        );
                  _openAddMemoryDialog(context, targetStop);
                },
                icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                label: const Text('Add First Photo Memory'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // ─── Top Control Strip: Search & View Mode Switch ───
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Column(
            children: [
              Row(
                children: [
                  // Search Box
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search captions or companions...',
                          hintStyle: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 16),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // View Mode Toggle (Stops vs Grid)
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.view_agenda_rounded,
                            size: 18,
                            color: _viewMode == _MemoriesViewMode.byStoppage
                                ? AppTheme.primary
                                : (isDark ? Colors.white54 : Colors.black45),
                          ),
                          tooltip: 'By Stoppage',
                          onPressed: () => setState(() => _viewMode = _MemoriesViewMode.byStoppage),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.grid_view_rounded,
                            size: 18,
                            color: _viewMode == _MemoriesViewMode.allPhotosGrid
                                ? AppTheme.primary
                                : (isDark ? Colors.white54 : Colors.black45),
                          ),
                          tooltip: 'All Photos Grid',
                          onPressed: () => setState(() => _viewMode = _MemoriesViewMode.allPhotosGrid),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Chronological Sort Order Toggle (Newest / Oldest)
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _newestFirst ? Icons.south_rounded : Icons.north_rounded,
                      ),
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      iconSize: 18,
                      color: AppTheme.primary,
                      tooltip: _newestFirst ? 'Sorted: Newest First' : 'Sorted: Oldest First',
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _newestFirst = !_newestFirst);
                      },
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Loop 117: Batch Share & Export All Photos Summary Action
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.share_outlined),
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      iconSize: 18,
                      color: AppTheme.primary,
                      tooltip: 'Share Album Summary (${rawMemories.length} Photos)',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        final albumSummary = StringBuffer()
                          ..writeln('📸 ${widget.trip.title} - Photo Album (${rawMemories.length} Memories)')
                          ..writeln('----------------------------------------');
                        for (final m in rawMemories) {
                          final stopName = stoppages.where((s) => s.id == m.stoppageId).firstOrNull?.name ?? 'En Route';
                          final cap = m.caption?.isNotEmpty == true ? ' - "${m.caption}"' : '';
                          albumSummary.writeln('• $stopName$cap (${DateFormatter.formatShortDate(m.createdAt)})');
                        }
                        albumSummary.writeln('----------------------------------------');
                        albumSummary.writeln('Captured with TrackMyTrip');
                        Share.share(albumSummary.toString(), subject: '${widget.trip.title} Photo Album');
                      },
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Multi-Selection Mode Toggle Button
                  Container(
                    decoration: BoxDecoration(
                      color: _isSelectionMode
                          ? AppTheme.primary
                          : (isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isSelectionMode
                            ? AppTheme.primary
                            : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isSelectionMode ? Icons.check_circle_rounded : Icons.checklist_rounded,
                        color: _isSelectionMode ? Colors.white : AppTheme.primary,
                      ),
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      iconSize: 18,
                      tooltip: _isSelectionMode ? 'Exit Selection Mode' : 'Select Multiple Photos',
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _isSelectionMode = !_isSelectionMode;
                          if (!_isSelectionMode) {
                            _selectedMemoryIds.clear();
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),

              // Multi-Selection Action Banner (when selection mode is active)
              if (_isSelectionMode) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primary.withAlpha(isDark ? 90 : 60),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 80 : 25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                      final isCompact = constraints.maxWidth < (textScale > 1.1 ? 380 : 340);
                      final isVeryCompact = constraints.maxWidth < (textScale > 1.1 ? 340 : 280);
                      return Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            tooltip: 'Cancel Selection',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: _exitSelectionMode,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              isVeryCompact
                                  ? '${_selectedMemoryIds.length}/${filteredMemories.length}'
                                  : '${_selectedMemoryIds.length} of ${filteredMemories.length} selected',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              minimumSize: const Size(32, 30),
                            ),
                            onPressed: () => _toggleSelectAll(filteredMemories),
                            child: Text(
                              _selectedMemoryIds.length == filteredMemories.length
                                  ? (isVeryCompact ? 'None' : 'Deselect')
                                  : (isCompact ? 'All' : 'Select All'),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 4),
                          isVeryCompact
                              ? IconButton.filled(
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(32, 30),
                                  ),
                                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                                  tooltip: 'Delete (${_selectedMemoryIds.length})',
                                  onPressed: _selectedMemoryIds.isEmpty ? null : () => _confirmDeleteSelected(context),
                                )
                              : FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    minimumSize: const Size(32, 30),
                                  ),
                                  icon: const Icon(Icons.delete_sweep_rounded, size: 14),
                                  label: Text(
                                    'Delete (${_selectedMemoryIds.length})',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: _selectedMemoryIds.isEmpty ? null : () => _confirmDeleteSelected(context),
                                ),
                        ],
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 8),

              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'All (${rawMemories.length})',
                      selected: _filterTab == _MemoryFilterTab.all && _selectedMemberFilterId == null,
                      onTap: () => setState(() {
                        _filterTab = _MemoryFilterTab.all;
                        _selectedMemberFilterId = null;
                      }),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'My Photos (${rawMemories.where((m) => m.uploadedByMemberId == myMember?.id).length})',
                      selected: _filterTab == _MemoryFilterTab.myPhotos && _selectedMemberFilterId == null,
                      onTap: () => setState(() {
                        _filterTab = _MemoryFilterTab.myPhotos;
                        _selectedMemberFilterId = null;
                      }),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Liked (${rawMemories.where((m) => myMember != null && m.likedByMemberIds.contains(myMember.id)).length})',
                      selected: _filterTab == _MemoryFilterTab.favorites && _selectedMemberFilterId == null,
                      onTap: () => setState(() {
                        _filterTab = _MemoryFilterTab.favorites;
                        _selectedMemberFilterId = null;
                      }),
                      isDark: isDark,
                    ),
                    if (widget.trip.members.length > 1) ...[
                      const SizedBox(width: 8),
                      ...widget.trip.members
                          .where((member) => member.id != myMember?.id && rawMemories.any((m) => m.uploadedByMemberId == member.id))
                          .map((member) {
                        final memberPhotoCount = rawMemories.where((m) => m.uploadedByMemberId == member.id).length;
                        final isSelected = _selectedMemberFilterId == member.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildFilterChip(
                            label: '${member.name.split(" ").first} ($memberPhotoCount)',
                            selected: isSelected,
                            onTap: () => setState(() {
                              _selectedMemberFilterId = isSelected ? null : member.id;
                              _filterTab = _MemoryFilterTab.all;
                            }),
                            isDark: isDark,
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // ─── RTDB Live Companion Memory Upload Presence Banner ───
        if (activeUploaders.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.secondary.withAlpha(40), AppTheme.primary.withAlpha(30)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.secondary.withAlpha(90)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.secondary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '✨ ${activeUploaders.join(', ')} is uploading a new memory...',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.secondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // ─── Offline / Local Pending Upload Monitor Strip ───
        if (pendingCount > 0)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(isDark ? 30 : 20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withAlpha(100)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_queue_rounded, size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$pendingCount photo${pendingCount > 1 ? 's' : ''} stored locally (pending cloud sync)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.amber[200] : Colors.amber[900],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _isSyncingPending
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          setState(() => _isSyncingPending = true);
                          await ref.read(mediaCacheServiceProvider).retryFailed(tripId: widget.trip.id);
                          if (!mounted) return;
                          setState(() => _isSyncingPending = false);
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Syncing pending photos to cloud storage...')),
                          );
                        },
                  child: _isSyncingPending
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        )
                      : const Text(
                          'Sync Now',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),

        // ─── Main Content Area ───
        Expanded(
          child: filteredMemories.isEmpty
              ? const AppEmptyState(
                  icon: Icons.photo_library_outlined,
                  title: 'No Photos Found',
                  message: 'Capture memories at your stops or adjust your active photo filter.',
                )
              : _viewMode == _MemoriesViewMode.allPhotosGrid
                  ? _buildAllPhotosGrid(
                      context: context,
                      memories: filteredMemories,
                      stoppages: stoppages,
                      isDark: isDark,
                      myMember: myMember,
                    )
                  : _buildByStoppageView(
                      context: context,
                      memories: filteredMemories,
                      stoppages: stoppages,
                      isDark: isDark,
                      myMember: myMember,
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary
              : (isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppTheme.primary
                : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  // ─── View 1: Stoppage Cards with Horizontal Carousels ───
  Widget _buildByStoppageView({
    required BuildContext context,
    required List<Memory> memories,
    required List<Stoppage> stoppages,
    required bool isDark,
    required dynamic myMember,
  }) {
    final generalMemories = memories
        .where((m) => !stoppages.any((s) => s.id == m.stoppageId))
        .toList();

    final List<Widget> sections = [];

    // 1. General trip highlights section (if any)
    if (generalMemories.isNotEmpty) {
      final generalStoppage = Stoppage(
        id: 'general_${widget.trip.id}',
        tripId: widget.trip.id,
        name: '${widget.trip.title} Highlights',
        latitude: 0.0,
        longitude: 0.0,
        arrivedAt: DateTime.now(),
        category: 'general',
        createdBy: widget.trip.createdByMemberId,
      );
      sections.add(
        _buildStoppageCard(
          context: context,
          title: 'Trip Highlights & Photos',
          subtitle: generalStoppage.category.toUpperCase(),
          photoCount: generalMemories.length,
          icon: Icons.photo_camera_back_rounded,
          stopMemories: generalMemories,
          allTripMemories: memories,
          stoppages: stoppages,
          onAddPhoto: () => _openAddMemoryDialog(context, generalStoppage),
          isDark: isDark,
          myMember: myMember,
        ),
      );
    }

    // 2. Stoppage-specific memory sections
    for (final stop in stoppages) {
      final stopMemories = memories.where((m) => m.stoppageId == stop.id).toList();
      if (stopMemories.isEmpty) continue;

      sections.add(
        _buildStoppageCard(
          context: context,
          title: stop.name,
          subtitle: stop.category.isNotEmpty ? stop.category.toUpperCase() : 'STOPPAGE',
          photoCount: stopMemories.length,
          icon: AppConstants.getStoppageIcon(stop.category),
          stopMemories: stopMemories,
          allTripMemories: memories,
          stoppages: stoppages,
          onAddPhoto: () => _openAddMemoryDialog(context, stop),
          isDark: isDark,
          myMember: myMember,
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
      children: sections,
    );
  }

  Widget _buildStoppageCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required int photoCount,
    required IconData icon,
    required List<Memory> stopMemories,
    required List<Memory> allTripMemories,
    required List<Stoppage> stoppages,
    required VoidCallback onAddPhoto,
    required bool isDark,
    required dynamic myMember,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header ---
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: AppTheme.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(isDark ? 45 : 20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.primary.withAlpha(isDark ? 90 : 50),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_library_rounded, size: 10, color: AppTheme.primary),
                              const SizedBox(width: 3),
                              Text(
                                '$photoCount',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? AppTheme.surfaceMutedDark : AppTheme.surfaceMutedLight,
                ),
                icon: const Icon(Icons.add_photo_alternate_rounded, color: AppTheme.secondary, size: 18),
                tooltip: 'Add Photo Here',
                onPressed: onAddPhoto,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // --- Horizontal photo cards ---
          SizedBox(
            height: 210,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              itemCount: stopMemories.length,
              itemBuilder: (context, index) {
                final memory = stopMemories[index];
                final uploaderName = widget.trip.getMemberName(memory.uploadedByMemberId);
                final isLiked = myMember != null && memory.likedByMemberIds.contains(myMember.id);

                return Container(
                  width: 165,
                  margin: const EdgeInsets.only(right: 12),
                  child: Material(
                    color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                    elevation: 2,
                    shadowColor: Colors.black.withAlpha(isDark ? 50 : 25),
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        if (_isSelectionMode) {
                          _toggleMemorySelection(memory.id);
                        } else {
                          final initialIdx = allTripMemories.indexOf(memory);
                          _openGalleryViewer(
                            memories: allTripMemories,
                            initialIndex: initialIdx >= 0 ? initialIdx : 0,
                            stoppages: stoppages,
                          );
                        }
                      },
                      onDoubleTap: () {
                        if (_isSelectionMode) {
                          _toggleMemorySelection(memory.id);
                          return;
                        }
                        if (myMember != null) {
                          HapticFeedback.mediumImpact();
                          ref.read(allMemoriesProvider.notifier).toggleLike(memory.id, myMember.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isLiked ? 'Removed from favorites' : '❤️ Added to favorites!'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      onLongPress: () {
                        if (_isSelectionMode) {
                          _toggleMemorySelection(memory.id);
                        } else {
                          _enterSelectionMode(memory.id);
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          MemoriesTab.buildMemoryImage(memory.displayPath, localPath: memory.localPath),

                          // Selection Tint & Badge
                          if (_isSelectionMode) ...[
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _selectedMemoryIds.contains(memory.id)
                                      ? Colors.black.withAlpha(100)
                                      : Colors.transparent,
                                  border: _selectedMemoryIds.contains(memory.id)
                                      ? Border.all(color: AppTheme.primary, width: 3)
                                      : null,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: Icon(
                                  _selectedMemoryIds.contains(memory.id)
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  color: _selectedMemoryIds.contains(memory.id)
                                      ? AppTheme.primary
                                      : Colors.grey[600],
                                  size: 22,
                                ),
                              ),
                            ),
                          ],

                          // Syncing Pill
                          if (memory.uploadStatus == MediaUploadStatus.uploading && !_isSelectionMode)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(160),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.8),
                                    ),
                                    SizedBox(width: 4.5),
                                    Text(
                                      'Syncing',
                                      style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Top Right 3-dots Menu Button (hidden during selection mode)
                          if (!_isSelectionMode)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Material(
                                color: Colors.black45,
                                shape: const CircleBorder(),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => _showContextMenu(context, memory, allTripMemories, stoppages),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.5),
                                    child: Icon(Icons.more_vert_rounded, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ),

                          // Bottom Info Overlay
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.transparent, Colors.black.withAlpha(200)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (memory.caption != null && memory.caption!.isNotEmpty)
                                    Text(
                                      memory.caption!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          uploaderName,
                                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _UploadStatusIcon(status: memory.uploadStatus),
                                          const SizedBox(width: 6),
                                          InkWell(
                                            onTap: () {
                                              if (myMember != null) {
                                                ref
                                                    .read(allMemoriesProvider.notifier)
                                                    .toggleLike(memory.id, myMember.id);
                                              }
                                            },
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isLiked ? Icons.favorite : Icons.favorite_border,
                                                  size: 14,
                                                  color: isLiked ? Colors.red : Colors.white70,
                                                ),
                                                if (memory.likedByMemberIds.isNotEmpty) ...[
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    '${memory.likedByMemberIds.length}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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

  // ─── View 2: High-Density All Photos Grid ───
  Widget _buildAllPhotosGrid({
    required BuildContext context,
    required List<Memory> memories,
    required List<Stoppage> stoppages,
    required bool isDark,
    required dynamic myMember,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int crossAxisCount = width < 400
            ? 2
            : (width < 600
                ? 3
                : (width < 900
                    ? 4
                    : 6));
        final hPad = width >= 800 ? ((width - 760) / 2).clamp(16.0, 380.0) : 16.0;

        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 80),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.0,
          ),
      itemCount: memories.length,
      itemBuilder: (context, index) {
        final memory = memories[index];
        final isLiked = myMember != null && memory.likedByMemberIds.contains(myMember.id);

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Material(
            color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
            child: InkWell(
              onTap: () {
                if (_isSelectionMode) {
                  _toggleMemorySelection(memory.id);
                } else {
                  _openGalleryViewer(
                    memories: memories,
                    initialIndex: index,
                    stoppages: stoppages,
                  );
                }
              },
              onDoubleTap: () {
                if (_isSelectionMode) {
                  _toggleMemorySelection(memory.id);
                  return;
                }
                if (myMember != null) {
                  HapticFeedback.mediumImpact();
                  ref.read(allMemoriesProvider.notifier).toggleLike(memory.id, myMember.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isLiked ? 'Removed from favorites' : '❤️ Added to favorites!'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              onLongPress: () {
                if (_isSelectionMode) {
                  _toggleMemorySelection(memory.id);
                } else {
                  _enterSelectionMode(memory.id);
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MemoriesTab.buildMemoryImage(memory.displayPath, localPath: memory.localPath),

                  // Selection Tint & Badge
                  if (_isSelectionMode) ...[
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedMemoryIds.contains(memory.id)
                              ? Colors.black.withAlpha(100)
                              : Colors.transparent,
                          border: _selectedMemoryIds.contains(memory.id)
                              ? Border.all(color: AppTheme.primary, width: 2.5)
                              : null,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: Icon(
                          _selectedMemoryIds.contains(memory.id)
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: _selectedMemoryIds.contains(memory.id)
                              ? AppTheme.primary
                              : Colors.grey[600],
                          size: 20,
                        ),
                      ),
                    ),
                  ],

                  // Top left: Like badge if liked (hidden during selection)
                  if (memory.likedByMemberIds.isNotEmpty && !_isSelectionMode)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.red : Colors.white,
                              size: 11,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${memory.likedByMemberIds.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Top right: 3-dots menu button (hidden during selection)
                  if (!_isSelectionMode)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.black45,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _showContextMenu(context, memory, memories, stoppages),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.more_vert_rounded, color: Colors.white, size: 15),
                          ),
                        ),
                      ),
                    ),

                  // Bottom left: Upload status icon
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: _UploadStatusIcon(status: memory.uploadStatus),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
      },
    );
  }
}

// ─── Upload Status Icon ───────────────────────────────────────────────────────

class _UploadStatusIcon extends StatelessWidget {
  final MediaUploadStatus status;
  const _UploadStatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MediaUploadStatus.uploaded:
        return const Icon(Icons.cloud_done_rounded, color: Colors.green, size: 12);
      case MediaUploadStatus.uploading:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5),
        );
      case MediaUploadStatus.failed:
        return const Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 12);
      case MediaUploadStatus.local:
        return const Icon(Icons.phone_android_rounded, color: Colors.white54, size: 12);
    }
  }
}

// ─── Loop 2: Interactive Swipeable Fullscreen Lightbox & Gallery Viewer ────────

class FullScreenGalleryViewer extends ConsumerStatefulWidget {
  final List<Memory> memories;
  final int initialIndex;
  final Trip trip;
  final List<Stoppage> stoppages;

  const FullScreenGalleryViewer({
    super.key,
    required this.memories,
    required this.initialIndex,
    required this.trip,
    required this.stoppages,
  });

  @override
  ConsumerState<FullScreenGalleryViewer> createState() => _FullScreenGalleryViewerState();
}

class _FullScreenGalleryViewerState extends ConsumerState<FullScreenGalleryViewer> {
  late PageController _pageController;
  late int _currentIndex;
  late List<Memory> _viewerMemories;
  bool _showHud = true;
  bool _showHeartAnimation = false;

  @override
  void initState() {
    super.initState();
    _viewerMemories = List<Memory>.from(widget.memories);
    _currentIndex = _viewerMemories.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, _viewerMemories.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _shareCurrentMemory(Memory memory) {
    HapticFeedback.lightImpact();
    final caption = memory.caption ?? 'Memory from ${widget.trip.title}';
    final timestamp = DateFormatter.formatDateTime(memory.createdAt);
    final shareText = '$caption • $timestamp';
    if (!kIsWeb && memory.localPath != null && File(memory.localPath!).existsSync()) {
      Share.shareXFiles([XFile(memory.localPath!)], text: shareText);
    } else {
      Share.share('$shareText\n${memory.displayPath}');
    }
  }

  void _editCurrentMemoryCaption(Memory memory) {
    final controller = TextEditingController(text: memory.caption ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Edit Caption', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter caption or travel note...',
            labelText: 'Caption',
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () {
              Navigator.of(ctx).pop();
              final newCaption = controller.text.trim();
              ref.read(allMemoriesProvider.notifier).updateCaption(memory.id, newCaption);
              if (mounted) {
                setState(() {
                  _viewerMemories[_currentIndex] = memory.copyWith(
                    caption: newCaption.isNotEmpty ? newCaption : null,
                  );
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Caption updated')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCurrentMemory(Memory memory) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Memory?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'This photo will be permanently deleted from the trip.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: const Text('Delete'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(allMemoriesProvider.notifier).deleteMemory(memory.id);
              if (_viewerMemories.length <= 1) {
                if (mounted) Navigator.of(context).pop();
              } else {
                setState(() {
                  _viewerMemories.removeAt(_currentIndex);
                  if (_currentIndex >= _viewerMemories.length) {
                    _currentIndex = _viewerMemories.length - 1;
                  }
                  _pageController.jumpToPage(_currentIndex);
                });
              }
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) => DateFormatter.formatDateTime(dt);

  @override
  Widget build(BuildContext context) {
    if (_viewerMemories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('No memories', style: TextStyle(color: Colors.white))),
      );
    }

    final currentMemory = _currentIndex < _viewerMemories.length
        ? _viewerMemories[_currentIndex]
        : _viewerMemories.first;

    final myMember = widget.trip.currentUserMember;
    final isLiked = myMember != null && currentMemory.likedByMemberIds.contains(myMember.id);

    // Resolve stoppage name for the current memory
    String placeName = 'Trip Highlights';
    final stop = widget.stoppages.where((s) => s.id == currentMemory.stoppageId).firstOrNull;
    if (stop != null) placeName = stop.name;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── Swipeable Carousel ───
          GestureDetector(
            onTap: () => setState(() => _showHud = !_showHud),
            onDoubleTap: () {
              if (myMember != null) {
                HapticFeedback.mediumImpact();
                ref.read(allMemoriesProvider.notifier).toggleLike(currentMemory.id, myMember.id);
                setState(() => _showHeartAnimation = true);
                Future.delayed(const Duration(milliseconds: 700), () {
                  if (mounted) setState(() => _showHeartAnimation = false);
                });
              }
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: _viewerMemories.length,
              onPageChanged: (idx) => setState(() => _currentIndex = idx),
              itemBuilder: (context, index) {
                final mem = _viewerMemories[index];
                return InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Center(
                    child: MemoriesTab.buildMemoryImage(mem.displayPath, localPath: mem.localPath),
                  ),
                );
              },
            ),
          ),

          // Double-tap Animated Heart Burst
          if (_showHeartAnimation)
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.2, end: 1.2),
                duration: const Duration(milliseconds: 400),
                curve: Curves.elasticOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.redAccent,
                      size: 96,
                      shadows: [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // ─── Top Navigation Bar HUD ───
          if (_showHud)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withAlpha(200), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    // Back / Close
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),

                    // Counter Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${_viewerMemories.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Heart Like Reaction
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isLiked ? Colors.redAccent : Colors.white,
                        size: 24,
                      ),
                      tooltip: 'Like Photo',
                      onPressed: () {
                        if (myMember != null) {
                          ref.read(allMemoriesProvider.notifier).toggleLike(currentMemory.id, myMember.id);
                        }
                      },
                    ),

                    // Edit Caption Button
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 24),
                      tooltip: 'Edit Caption',
                      onPressed: () => _editCurrentMemoryCaption(currentMemory),
                    ),

                    // Share Button
                    Semantics(
                      button: true,
                      label: 'Share photo',
                      child: IconButton(
                        icon: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
                        tooltip: 'Share Photo',
                        onPressed: () => _shareCurrentMemory(currentMemory),
                      ),
                    ),

                    // Delete Button
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                      tooltip: 'Delete Memory',
                      onPressed: () => _confirmDeleteCurrentMemory(currentMemory),
                    ),
                  ],
                ),
              ),
            ),

          // ─── Bottom Info Overlay HUD ───
          if (_showHud)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withAlpha(220)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.place_rounded, color: AppTheme.secondary, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            placeName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildStatusChip(currentMemory.uploadStatus),
                      ],
                    ),
                    if (currentMemory.caption != null && currentMemory.caption!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      AppResilientText.body(
                        currentMemory.caption!,
                        style: const TextStyle(color: Colors.white, fontSize: 14.5),
                        maxLines: 2,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, color: Colors.white60, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          widget.trip.getMemberName(currentMemory.uploadedByMemberId),
                          style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                        ),
                        const SizedBox(width: 8),
                        const Text('•', style: TextStyle(color: Colors.white38)),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(currentMemory.createdAt),
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        if (currentMemory.likedByMemberIds.isNotEmpty) ...[
                          const Spacer(),
                          const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            '${currentMemory.likedByMemberIds.length}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(MediaUploadStatus status) {
    IconData icon;
    Color color;
    String label;
    switch (status) {
      case MediaUploadStatus.uploaded:
        icon = Icons.cloud_done_rounded;
        color = Colors.greenAccent;
        label = 'Synced';
        break;
      case MediaUploadStatus.uploading:
        icon = Icons.cloud_upload_rounded;
        color = Colors.lightBlueAccent;
        label = 'Uploading';
        break;
      case MediaUploadStatus.failed:
        icon = Icons.cloud_off_rounded;
        color = Colors.orangeAccent;
        label = 'Failed';
        break;
      case MediaUploadStatus.local:
        icon = Icons.phone_android_rounded;
        color = Colors.white70;
        label = 'Local Only';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(160),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
