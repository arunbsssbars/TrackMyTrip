import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/media_cache_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/memory.dart';
import '../../../models/stoppage.dart';
import '../../../models/trip.dart';
import '../../../providers/memory_provider.dart';
import '../../../providers/stoppage_provider.dart';
import '../../../core/utils/trip_guard_helper.dart';
import '../../memories/add_memory_dialog.dart';

class MemoriesTab extends ConsumerWidget {
  final Trip trip;

  const MemoriesTab({super.key, required this.trip});

  Future<void> _openAddMemoryDialog(BuildContext context, WidgetRef ref, Stoppage stoppage) async {
    final canProceed = await TripGuardHelper.ensureTripOpenForEdit(
      context,
      ref,
      trip,
      actionLabel: 'add memories / photos',
    );
    if (!canProceed || !context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => AddMemoryDialog(tripId: trip.id, stoppage: stoppage),
    );
  }

  static Widget buildMemoryImage(String imagePath) {
    if (imagePath.startsWith('data:image')) {
      final base64Str = imagePath.split(',').last;
      return Image.memory(
        base64Decode(base64Str),
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) =>
            const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      );
    } else if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
            ),
          );
        },
        errorBuilder: (ctx, err, stack) =>
            const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      );
    } else if (!kIsWeb) {
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) =>
            const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      );
    } else {
      return const Center(child: Icon(Icons.photo));
    }
  }

  void _openImageViewer(BuildContext context, Memory memory, String placeName) {
    showDialog(
      context: context,
      builder: (ctx) => _FullScreenMemoryViewer(
        memory: memory,
        placeName: placeName,
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, Memory memory) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Memory?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'This photo will be removed from the trip. Local file will also be deleted.',
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
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(allMemoriesProvider.notifier).deleteMemory(memory.id);
              // Also remove from media cache if it was a local photo
              if (memory.localPath != null) {
                ref.read(mediaCacheServiceProvider).deleteItem(
                  ref.read(mediaCacheServiceProvider).itemForEntity(memory.id)?.id ?? '',
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stoppages = ref.watch(currentTripStoppagesProvider);
    final memories = ref.watch(currentTripMemoriesProvider);
    final myMember = trip.currentUserMember;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (memories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
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
              if (stoppages.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _openAddMemoryDialog(context, ref, stoppages.first),
                  icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                  label: const Text('Add First Photo Memory'),
                ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
      children: stoppages.map((stop) {
        final stopMemories = memories.where((m) => m.stoppageId == stop.id).toList();
        if (stopMemories.isEmpty) return const SizedBox.shrink();

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
              // --- Stoppage header ---
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      AppConstants.getStoppageIcon(stop.category),
                      size: 16,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${stopMemories.length} photo${stopMemories.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
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
                    onPressed: () => _openAddMemoryDialog(context, ref, stop),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // --- Horizontal photo cards ---
              SizedBox(
                height: 210,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: stopMemories.length,
                  itemBuilder: (context, index) {
                    final memory = stopMemories[index];
                    final uploaderName = trip.getMemberName(memory.uploadedByMemberId);
                    final isLiked = myMember != null &&
                        memory.likedByMemberIds.contains(myMember.id);

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
                          onTap: () => _openImageViewer(context, memory, stop.name),
                          onLongPress: () => _showContextMenu(context, ref, memory, stop.name),
                          splashColor: Colors.white.withAlpha(50),
                          highlightColor: Colors.white.withAlpha(25),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Photo
                              buildMemoryImage(memory.displayPath),

                              // Upload progress overlay
                              if (memory.uploadStatus == MediaUploadStatus.uploading)
                                Container(
                                  color: Colors.black.withAlpha(100),
                                  child: const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          'Uploading...',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              // Bottom info gradient
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
                                              // Upload status icon
                                              _UploadStatusIcon(status: memory.uploadStatus),
                                              const SizedBox(width: 6),
                                              // Like button
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
      }).toList(),
    );
  }

  void _showContextMenu(BuildContext context, WidgetRef ref, Memory memory, String placeName) {
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
              title: const Text('View Full Screen', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(ctx).pop();
                _openImageViewer(context, memory, placeName);
              },
            ),
            if (memory.localPath != null &&
                memory.uploadStatus != MediaUploadStatus.uploaded)
              ListTile(
                leading: const Icon(Icons.cloud_upload_rounded, color: Colors.blue),
                title: const Text('Retry Cloud Upload', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ref.read(mediaCacheServiceProvider).retryFailed();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Retrying upload...')),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.red),
              title: const Text('Delete Memory', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
              onTap: () {
                Navigator.of(ctx).pop();
                _showDeleteConfirm(context, ref, memory);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
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

// ─── Full Screen Viewer ───────────────────────────────────────────────────────

class _FullScreenMemoryViewer extends StatelessWidget {
  final Memory memory;
  final String placeName;

  const _FullScreenMemoryViewer({required this.memory, required this.placeName});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: MemoriesTab.buildMemoryImage(memory.displayPath),
            ),
          ),

          // Close button
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // Upload status badge
          Positioned(
            top: 44,
            left: 20,
            child: _buildStatusChip(memory.uploadStatus),
          ),

          // Caption + info overlay at bottom
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(160),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    placeName,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (memory.caption != null && memory.caption!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      memory.caption!,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, color: Colors.white54, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(memory.createdAt),
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      if (memory.likedByMemberIds.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.favorite, color: Colors.red, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${memory.likedByMemberIds.length}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
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
        color = Colors.green;
        label = 'Synced';
        break;
      case MediaUploadStatus.uploading:
        icon = Icons.cloud_upload_rounded;
        color = Colors.blue;
        label = 'Uploading';
        break;
      case MediaUploadStatus.failed:
        icon = Icons.cloud_off_rounded;
        color = Colors.orange;
        label = 'Upload Failed';
        break;
      case MediaUploadStatus.local:
        icon = Icons.phone_android_rounded;
        color = Colors.white70;
        label = 'Local Only';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(160),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
