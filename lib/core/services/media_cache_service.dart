import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'image_compression_service.dart';
import 'firebase_storage_service.dart';
import 'cloudinary_service.dart';
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'localPath': localPath,
    'remoteUrl': remoteUrl,
    'status': status.name,
    'uploadProgress': uploadProgress,
    'createdAt': createdAt.toIso8601String(),
    'entityType': entityType,
    'entityId': entityId,
    'tripId': tripId,
  };

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as String,
      localPath: json['localPath'] as String? ?? '',
      remoteUrl: json['remoteUrl'] as String?,
      status: MediaUploadStatus.values.byName(json['status'] as String? ?? 'local'),
      uploadProgress: (json['uploadProgress'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      entityType: json['entityType'] as String? ?? 'memory',
      entityId: json['entityId'] as String? ?? '',
      tripId: json['tripId'] as String?,
    );
  }
}

// ─── Service ──────────────────────────────────────────────────────────────────

class MediaCacheService extends ChangeNotifier {
  final _items = <String, MediaItem>{};  // id → MediaItem
  final FirebaseStorageService _storageService;
  final CloudinaryService _cloudinaryService;
  final Ref? _ref;

  static const String _keyPendingQueue = 'cld_pending_media_queue';

  MediaCacheService({
    FirebaseStorageService? storageService,
    CloudinaryService? cloudinaryService,
    Ref? ref,
  })  : _storageService = storageService ?? FirebaseStorageService(),
        _cloudinaryService = cloudinaryService ?? CloudinaryService(),
        _ref = ref {
    restorePendingQueue();
  }

  /// Saves any pending local/failed media items to persistent storage
  Future<void> persistPendingQueue({SharedPreferences? prefs}) async {
    try {
      final sp = prefs ?? await SharedPreferences.getInstance();
      final pending = _items.values.where((i) => i.isLocal).map((i) => i.toJson()).toList();
      await sp.setString(_keyPendingQueue, jsonEncode(pending));
    } catch (_) {}
  }

  /// Restores pending queue on service startup or app resumption
  Future<void> restorePendingQueue({SharedPreferences? prefs}) async {
    try {
      final sp = prefs ?? await SharedPreferences.getInstance();
      final raw = sp.getString(_keyPendingQueue);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final itemJson in list) {
          final item = MediaItem.fromJson(itemJson as Map<String, dynamic>);
          if (!_items.containsKey(item.id)) {
            _items[item.id] = item;
          }
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  /// All tracked media items
  List<MediaItem> get allItems => _items.values.toList();

  /// Get item for a given entity
  MediaItem? itemForEntity(String entityId) =>
      _items.values.where((i) => i.entityId == entityId).firstOrNull;

  /// Delete any items matching a specific entity (e.g. when memory is deleted)
  Future<void> deleteForEntity(String entityId) async {
    final matching = _items.values.where((i) => i.entityId == entityId).toList();
    final publicIdsToDelete = <String>[];

    for (final item in matching) {
      _items.remove(item.id);
      try {
        final file = File(item.localPath);
        if (await file.exists()) await file.delete();
        final thumbFile = ImageCompressionService.getThumbnailFile(file);
        if (await thumbFile.exists()) await thumbFile.delete();
      } catch (_) {}

      // Delete from Cloudinary if hosted remotely
      if (item.remoteUrl != null && item.remoteUrl!.contains('cloudinary.com')) {
        final publicId = CloudinaryService.extractPublicId(item.remoteUrl!) ??
            (item.tripId != null ? 'trackmytrip/trips/${item.tripId}/memories/mem_$entityId' : null);
        if (publicId != null) {
          publicIdsToDelete.add(publicId);
        }
      }
    }

    if (publicIdsToDelete.isNotEmpty) {
      if (publicIdsToDelete.length == 1) {
        try {
          await _cloudinaryService.deleteAsset(publicId: publicIdsToDelete.first);
        } catch (_) {}
      } else {
        try {
          await _cloudinaryService.deleteAssetsBatch(publicIdsToDelete);
        } catch (_) {}
      }
    }
    notifyListeners();
    await persistPendingQueue();
  }

  /// Delete all media items and remote Cloudinary assets associated with a trip
  Future<void> deleteForTrip(String tripId) async {
    final matching = _items.values.where((i) => i.tripId == tripId).toList();
    final publicIdsToDelete = <String>[];

    for (final item in matching) {
      _items.remove(item.id);
      try {
        final file = File(item.localPath);
        if (await file.exists()) await file.delete();
        final thumbFile = ImageCompressionService.getThumbnailFile(file);
        if (await thumbFile.exists()) await thumbFile.delete();
      } catch (_) {}

      if (item.remoteUrl != null && item.remoteUrl!.contains('cloudinary.com')) {
        final publicId = CloudinaryService.extractPublicId(item.remoteUrl!) ??
            'trackmytrip/trips/$tripId/memories/mem_${item.entityId}';
        publicIdsToDelete.add(publicId);
      }
    }

    if (publicIdsToDelete.isNotEmpty) {
      try {
        await _cloudinaryService.deleteAssetsBatch(publicIdsToDelete);
      } catch (_) {}
    }
    notifyListeners();
    await persistPendingQueue();
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
    persistPendingQueue();

    // Start upload to Firebase Storage in background
    _uploadItem(item, tripId: tripId);
    return item;
  }

  /// Upload raw image bytes directly (for Web or non-filesystem platforms)
  Future<MediaItem> uploadBytesAndQueue({
    required Uint8List bytes,
    required String entityType,
    required String entityId,
    String? tripId,
    String? previewDataUrl,
  }) async {
    const uuid = Uuid();
    final item = MediaItem(
      id: uuid.v4(),
      localPath: previewDataUrl ?? '',
      status: MediaUploadStatus.uploading,
      createdAt: DateTime.now(),
      entityType: entityType,
      entityId: entityId,
      tripId: tripId,
    );
    _items[item.id] = item;
    notifyListeners();
    persistPendingQueue();

    _uploadItemBytes(item, bytes: bytes, tripId: tripId);
    return item;
  }

  Future<void> _uploadItemBytes(MediaItem item, {required Uint8List bytes, String? tripId}) async {
    if (!_items.containsKey(item.id)) return;
    try {
      final targetTripId = tripId ?? item.tripId ?? 'shared_trips';
      final memoryId = item.entityId.isNotEmpty ? item.entityId : item.id;

      // Strategy 1: Cloudinary (Zero-card free quota with dynamic transformations)
      if (_cloudinaryService.isConfigured) {
        final downloadUrl = await _cloudinaryService.uploadImageBytes(
          bytes: bytes,
          folder: 'trackmytrip/trips/$targetTripId/memories',
          publicId: 'mem_$memoryId',
          onProgress: (progress) {
            if (_items.containsKey(item.id)) {
              _items[item.id]!.uploadProgress = progress;
              notifyListeners();
            }
          },
        );

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

      // Strategy 2: Firebase Storage fallback
      if (_storageService.isAvailable) {
        final downloadUrl = await _storageService.uploadMemoryPhotoBytes(
          tripId: targetTripId,
          memoryId: memoryId,
          bytes: bytes,
          onProgress: (progress) {
            if (_items.containsKey(item.id)) {
              _items[item.id]!.uploadProgress = progress;
              notifyListeners();
            }
          },
        );
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
      _items[item.id]!.status = MediaUploadStatus.local;
      if (item.entityType == 'memory' && _ref != null) {
        try {
          _ref.read(allMemoriesProvider.notifier).updateMemoryUploadStatus(item.entityId, MediaUploadStatus.local);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[MediaCacheService] Photo upload error: $e');
      _items[item.id]!.status = MediaUploadStatus.local;
      if (item.entityType == 'memory' && _ref != null) {
        try {
          _ref.read(allMemoriesProvider.notifier).updateMemoryUploadStatus(item.entityId, MediaUploadStatus.local);
        } catch (_) {}
      }
    }
    notifyListeners();
    persistPendingQueue();
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

  /// Upload a single item directly to remote cloud storage (Cloudinary or Firebase)
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

      final targetTripId = tripId ?? item.tripId ?? 'shared_trips';
      final memoryId = item.entityId.isNotEmpty ? item.entityId : item.id;

      // Strategy 1: Cloudinary (Zero-card free quota with dynamic transformations)
      if (_cloudinaryService.isConfigured) {
        final downloadUrl = await _cloudinaryService.uploadImageFile(
          file: file,
          folder: 'trackmytrip/trips/$targetTripId/memories',
          publicId: 'mem_$memoryId',
          onProgress: (progress) {
            if (_items.containsKey(item.id)) {
              _items[item.id]!.uploadProgress = progress;
              notifyListeners();
            }
          },
        );

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

      // Strategy 2: Firebase Storage fallback
      if (_storageService.isAvailable) {
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

      // If both remote services are unconfigured/offline, keep safe in local cache
      _items[item.id]!.status = MediaUploadStatus.local;
      _items[item.id]!.uploadProgress = 0.0;
      if (item.entityType == 'memory' && _ref != null) {
        try {
          _ref.read(allMemoriesProvider.notifier).updateMemoryUploadStatus(item.entityId, MediaUploadStatus.local);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[MediaCacheService] Remote storage upload error: $e');
      _items[item.id]!.status = MediaUploadStatus.local;
      _items[item.id]!.uploadProgress = 0.0;
      if (item.entityType == 'memory' && _ref != null) {
        try {
          _ref.read(allMemoriesProvider.notifier).updateMemoryUploadStatus(item.entityId, MediaUploadStatus.local);
        } catch (_) {}
      }
    }
    notifyListeners();
    persistPendingQueue();
  }

  /// Retry failed or pending local uploads (call when connectivity is restored or on manual sync)
  Future<void> retryFailed({String? tripId}) async {
    // 1. Process in-memory queued items
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

    // 2. Scan allMemoriesProvider for memories whose uploadStatus is local/failed but file exists
    if (_ref != null) {
      try {
        final memories = _ref.read(allMemoriesProvider);
        final unUploaded = memories.where((m) {
          final isTargetTrip = tripId == null || m.tripId == tripId;
          final isPending = m.uploadStatus == MediaUploadStatus.local || m.uploadStatus == MediaUploadStatus.failed;
          return isTargetTrip && isPending;
        }).toList();

        for (final m in unUploaded) {
          final path = m.localPath ?? m.mediaPath;
          if (path.isNotEmpty && !path.startsWith('http://') && !path.startsWith('https://')) {
            final file = File(path);
            if (await file.exists()) {
              final existingItem = itemForEntity(m.id);
              if (existingItem != null) {
                existingItem.status = MediaUploadStatus.local;
                await _uploadItem(existingItem, tripId: m.tripId);
              } else {
                final newItem = register(
                  localPath: path,
                  entityType: 'memory',
                  entityId: m.id,
                  status: MediaUploadStatus.local,
                );
                await _uploadItem(newItem, tripId: m.tripId);
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[MediaCacheService] retryFailed scanning allMemoriesProvider error: $e');
        }
      }
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
      await persistPendingQueue();
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
  final cloudinary = ref.watch(cloudinaryServiceProvider);
  return MediaCacheService(storageService: storage, cloudinaryService: cloudinary, ref: ref);
});
