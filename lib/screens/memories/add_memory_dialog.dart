import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/media_cache_service.dart';
import '../../core/services/image_compression_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/memory.dart';
import '../../models/stoppage.dart';
import '../../providers/memory_provider.dart';
import '../../providers/trip_provider.dart';
import '../../core/services/realtime_sync_service.dart';
import '../../core/services/secret_config_service.dart';

class AddMemoryDialog extends ConsumerStatefulWidget {
  final String tripId;
  final Stoppage stoppage;

  const AddMemoryDialog({
    super.key,
    required this.tripId,
    required this.stoppage,
  });

  @override
  ConsumerState<AddMemoryDialog> createState() => _AddMemoryDialogState();
}

class _AddMemoryDialogState extends ConsumerState<AddMemoryDialog> {
  final _captionController = TextEditingController();
  String? _selectedMemberId;
  XFile? _pickedFile;
  String? _activePhoto;
  bool _isLoadingImage = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() => _isLoadingImage = true);
      final picked = await ImageCompressionService.pickOptimizedImage(
        picker: ImagePicker(),
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 75,
      );

      if (picked != null) {
        _pickedFile = picked;
        if (kIsWeb) {
          final bytes = await picked.readAsBytes();
          final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          setState(() {
            _activePhoto = base64String;
          });
        } else {
          setState(() {
            _activePhoto = picked.path;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingImage = false);
    }
  }

  Widget _buildPhotoPreview(String path) {
    if (path.startsWith('data:image')) {
      final base64Str = path.split(',').last;
      return Image.memory(base64Decode(base64Str), fit: BoxFit.cover);
    } else if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
      );
    } else if (!kIsWeb) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
      );
    } else {
      return const Center(child: Icon(Icons.photo));
    }
  }

  Future<void> _submit() async {
    if (_activePhoto == null || _isSaving) return;
    setState(() => _isSaving = true);

    final currentTrip = ref.read(currentTripProvider);
    final uploaderId = _selectedMemberId ?? currentTrip?.currentUserMember?.id ?? 'me';
    final uploaderName = currentTrip?.getMemberName(uploaderId) ?? 'Companion';

    // Broadcast companion memory uploading presence
    ref.read(realtimeSyncServiceProvider).broadcastMemoryActivity(widget.tripId, uploaderId, uploaderName, true);

    try {
      const uuid = Uuid();
      final memoryId = uuid.v4();

      String finalMediaPath = _activePhoto!;
      String? localPath;
      bool isQueueing = false;

      // Cache image permanently into local app storage or queue for Cloud Storage
      if (_pickedFile != null) {
        if (kIsWeb) {
          try {
            final bytes = await _pickedFile!.readAsBytes();
            final mediaService = ref.read(mediaCacheServiceProvider);
            await mediaService.uploadBytesAndQueue(
              bytes: bytes,
              entityType: 'memory',
              entityId: memoryId,
              tripId: widget.tripId,
              previewDataUrl: _activePhoto,
            );
            isQueueing = true;
          } catch (e) {
            debugPrint('[AddMemoryDialog] Web upload exception: $e');
          }
        } else if (!_activePhoto!.startsWith('data:image')) {
          try {
            final mediaService = ref.read(mediaCacheServiceProvider);
            final item = await mediaService.cacheAndQueue(
              sourcePath: _activePhoto!,
              entityType: 'memory',
              entityId: memoryId,
              tripId: widget.tripId,
            );
            finalMediaPath = item.localPath;
            localPath = item.localPath;
            isQueueing = true;
          } catch (e) {
            localPath = _activePhoto;
          }
        }
      }

      final newMemory = Memory(
        id: memoryId,
        tripId: widget.tripId,
        stoppageId: widget.stoppage.id,
        uploadedByMemberId: uploaderId,
        mediaPath: finalMediaPath,
        localPath: localPath,
        uploadStatus: isQueueing ? MediaUploadStatus.uploading : MediaUploadStatus.local,
        caption: _captionController.text.trim().isNotEmpty
            ? _captionController.text.trim()
            : null,
        createdAt: DateTime.now(),
        likedByMemberIds: [],
      );

      await ref.read(allMemoriesProvider.notifier).addMemory(newMemory);
    } finally {
      // Clear memory activity presence safely
      try {
        ref.read(realtimeSyncServiceProvider).broadcastMemoryActivity(widget.tripId, uploaderId, uploaderName, false);
      } catch (_) {}
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final currentTrip = ref.watch(currentTripProvider);
    final members = currentTrip?.members ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPhoto = _activePhoto != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add_a_photo_rounded, color: AppTheme.secondary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Add Memory • ${widget.stoppage.name}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Photo Picker or Preview Area ---
              if (!hasPhoto)
                InkWell(
                  onTap: _isLoadingImage ? null : () => _pickImage(ImageSource.gallery),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isLoadingImage)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(),
                          )
                        else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.secondary.withAlpha(25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_photo_alternate_rounded,
                              size: 32,
                              color: AppTheme.secondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Select a Photo for this Memory',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Choose from gallery or take a new picture',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _pickImage(ImageSource.gallery),
                                  icon: const Icon(Icons.photo_library_rounded, size: 16),
                                  label: const Text('Gallery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.secondary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickImage(ImageSource.camera),
                                  icon: const Icon(Icons.camera_alt_rounded, size: 16),
                                  label: const Text('Camera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    side: const BorderSide(color: AppTheme.secondary, width: 1.2),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 170,
                        width: double.infinity,
                        color: isDark ? Colors.black38 : Colors.grey[200],
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildPhotoPreview(_activePhoto!),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _pickedFile = null;
                                    _activePhoto = null;
                                  });
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(190),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.cached_rounded, color: Colors.white, size: 13),
                                      SizedBox(width: 4),
                                      Text(
                                        'Change',
                                        style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(180),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.cloud_done_rounded, color: Colors.greenAccent, size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      SecretConfigService.isCloudinaryConfigured
                                          ? 'Cloudinary 25 GB Ready'
                                          : 'Firebase Storage Ready',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 14),

              // --- Caption ---
              TextField(
                controller: _captionController,
                decoration: const InputDecoration(
                  labelText: 'Caption / Travel Story',
                  hintText: 'e.g. Stunning sunset at the viewpoint!',
                  prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              // --- Uploader ---
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedMemberId ?? (members.isNotEmpty ? members.first.id : null),
                decoration: const InputDecoration(
                  labelText: 'Captured By',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                items: members.map((m) {
                  return DropdownMenuItem(
                    value: m.id,
                    child: Text(
                      m.isCurrentUser ? '${m.name} (Me)' : m.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedMemberId = val);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: (_isSaving || !hasPhoto) ? null : _submit,
          icon: _isSaving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(
            _isSaving ? 'Saving...' : 'Save Memory',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}
