import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/media_cache_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/memory.dart';
import '../../models/stoppage.dart';
import '../../providers/memory_provider.dart';
import '../../providers/trip_provider.dart';

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
  XFile? _pickedFile;        // Raw picked file
  bool _isLoadingImage = false;
  bool _isSaving = false;

  final List<String> _presetPhotos = [
    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
    'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=800&q=80',
    'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800&q=80',
    'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800&q=80',
  ];

  late String _activePhoto;

  @override
  void initState() {
    super.initState();
    _activePhoto = _presetPhotos.first;
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() => _isLoadingImage = true);
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
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
            // Will be permanently cached via MediaCacheService on submit
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
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final currentTrip = ref.read(currentTripProvider);
    final uploaderId = _selectedMemberId ?? currentTrip?.currentUserMember?.id ?? 'me';
    const uuid = Uuid();
    final memoryId = uuid.v4();

    String finalMediaPath = _activePhoto;
    String? localPath;
    MediaUploadStatus uploadStatus = MediaUploadStatus.local;

    // If user picked a real local image (not a preset URL), cache it permanently
    if (_pickedFile != null && !kIsWeb && !_activePhoto.startsWith('data:image')) {
      try {
        final mediaService = ref.read(mediaCacheServiceProvider);
        final item = await mediaService.cacheAndQueue(
          sourcePath: _activePhoto,
          entityType: 'memory',
          entityId: memoryId,
        );
        finalMediaPath = item.localPath;
        localPath = item.localPath;
        uploadStatus = item.status;
      } catch (e) {
        // Fallback: use picked path directly (will not survive reinstall)
        localPath = _activePhoto;
      }
    }

    final newMemory = Memory(
      id: memoryId,
      tripId: widget.tripId,
      stoppageId: widget.stoppage.id,
      uploadedByMemberId: uploaderId,
      mediaPath: finalMediaPath,
      localPath: localPath,
      uploadStatus: uploadStatus,
      caption: _captionController.text.trim().isNotEmpty
          ? _captionController.text.trim()
          : null,
      createdAt: DateTime.now(),
      likedByMemberIds: [],
    );

    ref.read(allMemoriesProvider.notifier).addMemory(newMemory);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final currentTrip = ref.watch(currentTripProvider);
    final members = currentTrip?.members ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isUserPhoto = _pickedFile != null;

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
              // --- Upload buttons ---
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Browse Phone Photos',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isLoadingImage ? null : () => _pickImage(ImageSource.gallery),
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
                            onPressed: _isLoadingImage ? null : () => _pickImage(ImageSource.camera),
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
                ),
              ),
              const SizedBox(height: 12),

              // --- Preview ---
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  color: isDark ? Colors.black38 : Colors.grey[200],
                  child: _isLoadingImage
                      ? const Center(child: CircularProgressIndicator())
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildPhotoPreview(_activePhoto),
                            if (isUserPhoto)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(170),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.save_rounded, color: Colors.white, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'Will save to device',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // --- Preset selector ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Or Pick Scenic Preset:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  if (isUserPhoto)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        setState(() {
                          _pickedFile = null;
                          _activePhoto = _presetPhotos.first;
                        });
                      },
                      child: const Text('Reset', style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _presetPhotos.length,
                  itemBuilder: (context, index) {
                    final photo = _presetPhotos[index];
                    final isSelected = !isUserPhoto && photo == _activePhoto;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _pickedFile = null;
                          _activePhoto = photo;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppTheme.secondary : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            photo,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image, size: 20),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
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
                value: _selectedMemberId ?? (members.isNotEmpty ? members.first.id : null),
                decoration: const InputDecoration(
                  labelText: 'Captured By',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                items: members.map((m) {
                  return DropdownMenuItem(
                    value: m.id,
                    child: Text(m.isCurrentUser ? '${m.name} (Me)' : m.name),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedMemberId = val);
                },
              ),

              if (isUserPhoto) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withAlpha(80)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_upload_outlined, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Photo will be saved locally & queued for cloud sync.',
                          style: TextStyle(fontSize: 11, color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
          onPressed: _isSaving ? null : _submit,
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
