import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'secret_config_service.dart';

/// Cloudinary media service providing free, card-free cloud media uploads
/// and responsive dynamic URL image optimizations.
class CloudinaryService {
  final http.Client _httpClient;

  CloudinaryService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Whether Cloudinary cloud credentials (cloud_name + unsigned preset) are configured
  bool get isConfigured => SecretConfigService.isCloudinaryConfigured;

  /// Active Cloudinary cloud name from environment or .env
  String get cloudName => SecretConfigService.cloudinaryCloudName;

  /// Active unsigned upload preset name
  String get uploadPreset => SecretConfigService.cloudinaryUploadPreset;

  /// Target Cloudinary upload endpoint
  Uri get _uploadEndpoint =>
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

  /// Uploads a local image [File] to Cloudinary using an unsigned upload preset.
  /// Returns the secure HTTPS URL of the uploaded asset, or `null` on failure.
  Future<String?> uploadImageFile({
    required File file,
    String? folder,
    String? publicId,
    Map<String, String>? tags,
    void Function(double progress)? onProgress,
  }) async {
    if (!isConfigured) {
      if (kDebugMode) {
        debugPrint('[CloudinaryService] Skip upload: Cloudinary credentials not configured.');
      }
      return null;
    }

    try {
      if (!await file.exists()) {
        if (kDebugMode) {
          debugPrint('[CloudinaryService] File does not exist at: ${file.path}');
        }
        return null;
      }

      onProgress?.call(0.1);

      final request = http.MultipartRequest('POST', _uploadEndpoint);
      request.fields['upload_preset'] = uploadPreset;
      if (folder != null && folder.isNotEmpty) {
        request.fields['folder'] = folder;
      }
      if (publicId != null && publicId.isNotEmpty) {
        request.fields['public_id'] = publicId;
      }
      if (tags != null && tags.isNotEmpty) {
        request.fields['tags'] = tags.values.join(',');
      }

      final multipartFile = await http.MultipartFile.fromPath('file', file.path);
      request.files.add(multipartFile);

      onProgress?.call(0.3);

      final streamedResponse = await _httpClient.send(request).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Cloudinary upload timed out after 30 seconds'),
      );

      final responseBody = await streamedResponse.stream.bytesToString();
      onProgress?.call(0.9);

      if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final secureUrl = data['secure_url'] as String?;
        onProgress?.call(1.0);
        if (kDebugMode) {
          debugPrint('[CloudinaryService] Upload succeeded: $secureUrl');
        }
        return secureUrl;
      } else {
        if (kDebugMode) {
          debugPrint(
            '[CloudinaryService] Upload failed (${streamedResponse.statusCode}): $responseBody',
          );
        }
        return null;
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[CloudinaryService] Upload exception: $e\n$stack');
      }
      return null;
    }
  }

  /// Uploads raw image [Uint8List] bytes directly to Cloudinary (useful for Web or memory buffers).
  /// Returns the secure HTTPS URL or `null` on failure.
  Future<String?> uploadImageBytes({
    required Uint8List bytes,
    String filename = 'photo.jpg',
    String? folder,
    String? publicId,
    Map<String, String>? tags,
    void Function(double progress)? onProgress,
  }) async {
    if (!isConfigured) {
      if (kDebugMode) {
        debugPrint('[CloudinaryService] Skip upload: Cloudinary credentials not configured.');
      }
      return null;
    }

    try {
      onProgress?.call(0.1);

      final request = http.MultipartRequest('POST', _uploadEndpoint);
      request.fields['upload_preset'] = uploadPreset;
      if (folder != null && folder.isNotEmpty) {
        request.fields['folder'] = folder;
      }
      if (publicId != null && publicId.isNotEmpty) {
        request.fields['public_id'] = publicId;
      }
      if (tags != null && tags.isNotEmpty) {
        request.fields['tags'] = tags.values.join(',');
      }

      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      );
      request.files.add(multipartFile);

      onProgress?.call(0.3);

      final streamedResponse = await _httpClient.send(request).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Cloudinary byte upload timed out after 30 seconds'),
      );

      final responseBody = await streamedResponse.stream.bytesToString();
      onProgress?.call(0.9);

      if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final secureUrl = data['secure_url'] as String?;
        onProgress?.call(1.0);
        if (kDebugMode) {
          debugPrint('[CloudinaryService] Byte upload succeeded: $secureUrl');
        }
        return secureUrl;
      } else {
        if (kDebugMode) {
          debugPrint(
            '[CloudinaryService] Byte upload failed (${streamedResponse.statusCode}): $responseBody',
          );
        }
        return null;
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[CloudinaryService] Byte upload exception: $e\n$stack');
      }
      return null;
    }
  }

  /// Generates a performance-optimized Cloudinary transformation delivery URL
  /// (e.g. dynamic resizing, auto-format WebP/AVIF, quality auto).
  /// If the URL is not a Cloudinary delivery URL, returns it unchanged.
  static String getOptimizedUrl(
    String rawUrl, {
    int? width,
    int? height,
    int? quality,
    bool autoFormat = true,
  }) {
    if (rawUrl.isEmpty) return rawUrl;
    if (!rawUrl.contains('res.cloudinary.com') || !rawUrl.contains('/upload/')) {
      return rawUrl;
    }

    final transformations = <String>[];
    if (width != null && width > 0) {
      transformations.add('w_$width');
    }
    if (height != null && height > 0) {
      transformations.add('h_$height');
    }
    if (width != null || height != null) {
      transformations.add('c_limit');
    }
    if (quality != null && quality > 0) {
      transformations.add('q_$quality');
    } else {
      transformations.add('q_auto');
    }
    if (autoFormat) {
      transformations.add('f_auto');
    }

    if (transformations.isEmpty) return rawUrl;

    final transformString = '${transformations.join(',')}/';

    // Avoid duplicate transformations if already injected
    if (rawUrl.contains('/upload/$transformString')) {
      return rawUrl;
    }

    return rawUrl.replaceFirst('/upload/', '/upload/$transformString');
  }
}

/// Riverpod provider for CloudinaryService
final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  return CloudinaryService();
});
