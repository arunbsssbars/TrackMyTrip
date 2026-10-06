import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FirebaseStorageService {
  final FirebaseStorage? _storage;

  FirebaseStorageService({FirebaseStorage? storage})
      : _storage = storage ?? (Firebase.apps.isNotEmpty ? FirebaseStorage.instance : null);

  bool get isAvailable => _storage != null;

  /// Uploads a trip memory photo from a local File to Firebase Cloud Storage.
  /// Storage path format: trips/{tripId}/memories/{memoryId}.jpg
  Future<String?> uploadMemoryPhoto({
    required String tripId,
    required String memoryId,
    required File file,
    void Function(double progress)? onProgress,
  }) async {
    if (_storage == null) {
      if (kDebugMode) debugPrint('[FirebaseStorageService] Storage not initialized');
      return null;
    }

    try {
      final ref = _storage.ref().child('trips/$tripId/memories/$memoryId.jpg');
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'tripId': tripId,
          'memoryId': memoryId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = ref.putFile(file, metadata);

      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((event) {
          if (event.totalBytes > 0) {
            final progress = event.bytesTransferred / event.totalBytes;
            onProgress(progress);
          }
        });
      }

      final snapshot = await uploadTask.timeout(const Duration(seconds: 15));
      final downloadUrl = await snapshot.ref.getDownloadURL();
      if (kDebugMode) {
        debugPrint('[FirebaseStorageService] Uploaded memory $memoryId to Cloud Storage: $downloadUrl');
      }
      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FirebaseStorageService] Failed to upload memory $memoryId: $e');
      }
      return null;
    }
  }

  /// Uploads a trip memory photo from in-memory bytes (for Web or raw buffers).
  Future<String?> uploadMemoryPhotoBytes({
    required String tripId,
    required String memoryId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
    void Function(double progress)? onProgress,
  }) async {
    if (_storage == null) return null;

    try {
      final ref = _storage.ref().child('trips/$tripId/memories/$memoryId.jpg');
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'tripId': tripId,
          'memoryId': memoryId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = ref.putData(bytes, metadata);

      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((event) {
          if (event.totalBytes > 0) {
            onProgress(event.bytesTransferred / event.totalBytes);
          }
        });
      }

      final snapshot = await uploadTask.timeout(const Duration(seconds: 45));
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FirebaseStorageService] Byte upload failed for memory $memoryId: $e');
      }
      return null;
    }
  }

  /// Deletes a memory photo from Firebase Storage if it exists.
  Future<void> deleteMemoryPhoto({
    required String tripId,
    required String memoryId,
  }) async {
    if (_storage == null) return;
    try {
      final ref = _storage.ref().child('trips/$tripId/memories/$memoryId.jpg');
      await ref.delete();
      if (kDebugMode) {
        debugPrint('[FirebaseStorageService] Deleted memory $memoryId from Storage');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FirebaseStorageService] Failed to delete memory $memoryId from Storage: $e');
      }
    }
  }

  /// Purges all memories for a trip from Storage
  Future<void> purgeTripMemories(String tripId) async {
    if (_storage == null) return;
    try {
      final folderRef = _storage.ref().child('trips/$tripId/memories');
      final listResult = await folderRef.listAll();
      for (final item in listResult.items) {
        try {
          await item.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }
}

final firebaseStorageServiceProvider = Provider<FirebaseStorageService>((ref) {
  return FirebaseStorageService();
});
