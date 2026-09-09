import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

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

  MediaItem({
    required this.id,
    required this.localPath,
    this.remoteUrl,
    this.status = MediaUploadStatus.local,
    this.uploadProgress = 0.0,
    required this.createdAt,
    required this.entityType,
    required this.entityId,
  });

  bool get isLocal => status == MediaUploadStatus.local || status == MediaUploadStatus.failed;
  bool get isUploaded => status == MediaUploadStatus.uploaded;
  bool get isUploading => status == MediaUploadStatus.uploading;

  String get displayPath => remoteUrl ?? localPath;
}

// ─── Service ──────────────────────────────────────────────────────────────────

class MediaCacheService extends ChangeNotifier {
  final _items = <String, MediaItem>{};  // id → MediaItem
  String _serverHost = '100.98.130.99:8086';

  void updateServerHost(String host) => _serverHost = host;

  /// All tracked media items
  List<MediaItem> get allItems => _items.values.toList();

  /// Get item for a given entity
  MediaItem? itemForEntity(String entityId) =>
      _items.values.where((i) => i.entityId == entityId).firstOrNull;

  /// Copy a picked file into the app's permanent storage and queue it for upload
  Future<MediaItem> cacheAndQueue({
    required String sourcePath,
    required String entityType,
    required String entityId,
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
    );
    _items[item.id] = item;
    notifyListeners();

    // Start upload in background
    _uploadItem(item);
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
    await File(sourcePath).copy(destFile.path);
    return destFile.path;
  }

  /// Upload a single item to the local sync server (or later AWS S3)
  Future<void> _uploadItem(MediaItem item) async {
    if (!_items.containsKey(item.id)) return;

    _items[item.id]!.status = MediaUploadStatus.uploading;
    _items[item.id]!.uploadProgress = 0.0;
    notifyListeners();

    try {
      final file = File(item.localPath);
      if (!await file.exists()) {
        _items[item.id]!.status = MediaUploadStatus.failed;
        notifyListeners();
        return;
      }

      final uri = Uri.parse('http://$_serverHost/api/media/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['entityType'] = item.entityType
        ..fields['entityId'] = item.entityId
        ..fields['mediaId'] = item.id
        ..files.add(await http.MultipartFile.fromPath('file', item.localPath));

      // Simulate progress (real implementation would use a StreamedRequest)
      _items[item.id]!.uploadProgress = 0.3;
      notifyListeners();

      final response = await request.send().timeout(const Duration(seconds: 10));

      _items[item.id]!.uploadProgress = 0.9;
      notifyListeners();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Server returns { "url": "http://..." }
        final respStr = await response.stream.bytesToString();
        String? remoteUrl;
        try {
          // Simple JSON parse without dart:convert for minimal imports
          final match = RegExp(r'"url"\s*:\s*"([^"]+)"').firstMatch(respStr);
          remoteUrl = match?.group(1);
        } catch (_) {}
        _items[item.id]!
          ..status = MediaUploadStatus.uploaded
          ..uploadProgress = 1.0
          ..remoteUrl = remoteUrl ?? 'http://$_serverHost/media/${item.id}';
      } else {
        // Server offline — keep local and mark as local (will retry)
        _items[item.id]!.status = MediaUploadStatus.local;
        _items[item.id]!.uploadProgress = 0.0;
      }
    } on TimeoutException {
      // Server unreachable (local testing mode) — OK, image stays local
      _items[item.id]!.status = MediaUploadStatus.local;
      _items[item.id]!.uploadProgress = 0.0;
    } catch (e) {
      debugPrint('[MediaCacheService] Upload error: $e');
      _items[item.id]!.status = MediaUploadStatus.failed;
      _items[item.id]!.uploadProgress = 0.0;
    }
    notifyListeners();
  }

  /// Retry failed uploads (call when connectivity is restored)
  Future<void> retryFailed() async {
    final failed = _items.values.where((i) => i.status == MediaUploadStatus.failed).toList();
    for (final item in failed) {
      await _uploadItem(item);
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
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final mediaCacheServiceProvider = ChangeNotifierProvider<MediaCacheService>((ref) {
  return MediaCacheService();
});
