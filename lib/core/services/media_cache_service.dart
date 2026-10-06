import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'image_compression_service.dart';
import 'firebase_storage_service.dart';
import '../../providers/memory_provider.dart';
import 'tombstone_service.dart';

// ─── Upload Status ────────────────────────────────────────────────────────────

enum MediaUploadStatus { local, uploading, uploaded, failed }

// ─── Media Item ───────────────────────────────────────────────────────────────

class MediaItem {
  final String id;
  final String localPath;    // Absolute path in app docs dir
  String? remoteUrl;         // Populated after successful upload
  MediaUploadStatus status;
  double uploadProgress;     // 0.0 – 1.0
  final DateTime createdAt;
  final String entityType;   // 'memory' | 'receipt'
  final String entityId;     // memoryId or expenseId
  final String? tripId;

  MediaItem({
    required this.id,
    required this.localPath,
    this.remoteUrl,
    this.status = MediaUploadStatus.local,
    this.uploadProgress = 0.0,
    required this.createdAt,
    required this.entityType,
    required this.entityId,
    this.tripId,
  });

  bool get isLocal => status == MediaUploadStatus.local || status == MediaUploadStatus.failed;
  bool get isUploaded => status == MediaUploadStatus.uploaded;
  bool get isUploading => status == MediaUploadStatus.uploading;

  String get displayPath => remoteUrl ?? localPath;
}

// ─── Service ──────────────────────────────────────────────────────────────────

class MediaCacheService extends ChangeNotifier {
  final _items = <String, MediaItem>{};  // id → MediaItem
  final FirebaseStorageService _storageService;
  final Ref? _ref;

  MediaCacheService({FirebaseStorageService? storageService, Ref? ref})
      : _storageService = storageService ?? FirebaseStorageService(),
        _ref = ref;

  /// All tracked media items
  List<MediaItem> get allItems => _items.values.toList();

  /// Get item for a given entity
  MediaItem? itemForEntity(String entityId) =>
      _items.values.where((i) => i.entityId == entityId).firstOrNull;

  /// Delete any items matching a specific entity (e.g. when memory is deleted)
  Future<void> deleteForEntity(String entityId) async {
    final matching = _items.values.where((i) => i.entityId == entityId).toList();
    for (final item in matching) {
      _items.remove(item.id);
      try {
        final file = File(item.localPath);
        if (await file.exists()) await file.delete();
        final thumbFile = ImageCompressionService.getThumbnailFile(file);
        if (await thumbFile.exists()) await thumbFile.delete();
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Copy a picked file into the app's permanent storage and queue it for upload
  Future<MediaItem> cacheAndQueue({
    required String sourcePath,
    required String entityType,
    required String entityId,
    String? tripId,
  }) async {
    final destPath = await _copyToAppDir(sourcePath);
    const uuid = Uuid();
    final item = MediaItem(
      id: uuid.v4(),
      localPath: destPath,
      status: MediaUploadStatus.local,
      createdAt: DateTime.now(),
      entityType: entityType,
      entityId: entityId,
      tripId: tripId,
    );
    _items[item.id] = item;
    notifyListeners();

    // Start upload to Firebase Storage in background
    _uploadItem(item, tripId: tripId);
    return item;
  }

  /// Copy source file into app documents/media/ directory
  Future<String> _copyToAppDir(String sourcePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(docsDir.path, 'trip_media'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    final ext = p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.jpg';
    final destFile = File(p.join(mediaDir.path, '${const Uuid().v4()}$ext'));
    final copiedFile = await File(sourcePath).copy(destFile.path);
    try {
      // On-device high-efficiency compression to maximize free-tier cloud storage
      await ImageCompressionService.compressFile(copiedFile);
      // Generate lightweight thumbnail for 60 FPS gallery scrolling
      await ImageCompressionService.createThumbnail(copiedFile, size: 250);
    } catch (_) {}
    return destFile.path;
  }

  /// Upload a single item directly to Firebase Cloud Storage
  Future<void> _uploadItem(MediaItem item, {String? tripId}) async {
    if (!_items.containsKey(item.id)) return;

    // Tombstone guard: abort upload if entity was deleted/tombstoned!
    if (item.entityType == 'memory' && TombstoneService.isMemoryTombstoned(item.entityId)) {
      await deleteItem(item.id);
      return;
    }

    _items[item.id]!.status = MediaUploadStatus.uploading;
    _items[item.id]!.uploadProgress = 0.0;
    notifyListeners();
    if (item.entityType == 'memory' && _ref != null) {
      try {
        _ref.read(allMemoriesProvider.notifier).updateMemoryUploadStatus(item.entityId, MediaUploadStatus.uploading);
      } catch (_) {}
    }

    try {
      final file = File(item.localPath);
      if (!await file.exists()) {
        _items[item.id]!.status = MediaUploadStatus.failed;
        notifyListeners();
        if (item.entityType == 'memory' && _ref != null) {
          try {
            _ref.read(allMemoriesProvider.notifier).updateMemoryUploadStatus(item.entityId, MediaUploadStatus.failed);
          } catch (_) {}
        }
        return;
      }

      if (_storageService.isAvailable) {
        final targetTripId = tripId ?? item.tripId ?? 'shared_trips';
        final memoryId = item.entityId.isNotEmpty ? item.entityId : item.id;
        final downloadUrl = await _storageService.uploadMemoryPhoto(
          tripId: targetTripId,
          memoryId: memoryId,
          file: file,
          onProgress: (progress) {
            if (_items.containsKey(item.id)) {
              _items[item.id]!.uploadProgress = progress;
              notifyListeners();
            }
          },
        ).timeout(const Duration(seconds: 20), onTimeout: () => null);

        // Check if item was deleted while uploading
        if (item.entityType == 'memory' && TombstoneService.isMemoryTombstoned(item.entityId)) {
          await deleteItem(item.id);
          return;
        }

        if (downloadUrl != null && downloadUrl.isNotEmpty) {
          _items[item.id]!
            ..status = MediaUploadStatus.uploaded
            ..uploadProgress = 1.0
            ..remoteUrl = downloadUrl;
          notifyListeners();
          if (item.entityType == 'memory' && _ref != null) {
            try {
              _ref.read(allMemoriesProvider.notifier).updateMemoryMediaUrl(memoryId, downloadUrl);
            } catch (_) {}
          }
          return;
        }
      }

      // If Firebase Storage is unreachable or unconfigured, keep local and safe
      _items[item.id]!.status = MediaUploadStatus.local;
      _items[item.id]!.uploadProgress = 0.0;
      if (item.entityType == 'memory' && _ref != null) {
        try {
          _ref.read(allMemoriesProvider.notifier).updateMemoryUploadStatus(item.entityId, MediaUploadStatus.local);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[MediaCacheService] Firebase Storage upload error: $e');
      _items[item.id]!.status = MediaUploadStatus.local;
      _items[item.id]!.uploadProgress = 0.0;
      if (item.entityType == 'memory' && _ref != null) {
        try {
          _ref.read(allMemoriesProvider.notifier).updateMemoryUploadStatus(item.entityId, MediaUploadStatus.local);
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  /// Retry failed or pending local uploads (call when connectivity is restored or on manual sync)
  Future<void> retryFailed({String? tripId}) async {
    final pending = _items.values.where((i) {
      final isPending = i.status == MediaUploadStatus.failed || i.status == MediaUploadStatus.local;
      if (tripId != null && i.tripId != null) {
        return isPending && i.tripId == tripId;
      }
      return isPending;
    }).toList();
    for (final item in pending) {
      await _uploadItem(item, tripId: item.tripId);
    }
  }

  /// Delete both the local file and remove from queue
  Future<void> deleteItem(String itemId) async {
    final item = _items.remove(itemId);
    if (item != null) {
      try {
        final file = File(item.localPath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
      notifyListeners();
    }
  }

  /// Register an already-existing local path as a MediaItem (e.g., on app restart)
  MediaItem register({
    required String localPath,
    required String entityType,
    required String entityId,
    String? remoteUrl,
    MediaUploadStatus status = MediaUploadStatus.local,
  }) {
    // Check if already registered for this entity
    final existing = _items.values.where((i) => i.entityId == entityId).firstOrNull;
    if (existing != null) return existing;

    const uuid = Uuid();
    final item = MediaItem(
      id: uuid.v4(),
      localPath: localPath,
      remoteUrl: remoteUrl,
      status: status,
      createdAt: DateTime.now(),
      entityType: entityType,
      entityId: entityId,
    );
    _items[item.id] = item;
    notifyListeners();
    return item;
  }

  /// Safely deletes a media file and its companion thumbnail from disk
  static Future<void> deleteMediaFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      final thumbFile = ImageCompressionService.getThumbnailFile(file);
      if (await thumbFile.exists()) {
        await thumbFile.delete();
      }
    } catch (_) {}
  }

  /// Permanently deletes all media files and thumbnails in trip_media on disk
  static Future<void> wipeAllMediaCache() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory(p.join(docsDir.path, 'trip_media'));
      if (await mediaDir.exists()) {
        await mediaDir.delete(recursive: true);
      }
    } catch (_) {}
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final mediaCacheServiceProvider = ChangeNotifierProvider<MediaCacheService>((ref) {
  final storage = ref.watch(firebaseStorageServiceProvider);
  return MediaCacheService(storageService: storage, ref: ref);
});
