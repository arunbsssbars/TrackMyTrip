import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'anti_abuse_rate_limiter_service.dart';
import 'image_compression_service.dart';
import 'secret_config_service.dart';

/// Cloudinary media service providing free, zero-card cloud media uploads,
/// strict 25 GB free quota enforcement, pre-upload image optimizations,
/// and responsive dynamic URL image transformations.
class CloudinaryService {
  final http.Client _httpClient;

  CloudinaryService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  // =================================================================
  // 25 GB Quota Bounds & Protection Limits
  // =================================================================
  /// 25 GB maximum free-tier quota in Megabytes (MB)
  static const double maxQuotaMb = 25600.0;

  /// 25 GB maximum free-tier quota in Bytes (26,843,545,600)
  static const double maxQuotaBytes = 25.0 * 1024 * 1024 * 1024;

  /// Warning threshold at 80% (20,480 MB)
  static const double warningQuotaMb = 20480.0;

  /// Critical threshold at 95% (24,320 MB)
  static const double criticalQuotaMb = 24320.0;

  static const String _keyConsumedBytes = 'cloudinary_consumed_bytes';
  static int _inMemoryBytes = 0;
  static bool _initializedFromPrefs = false;

  /// Whether Cloudinary cloud credentials (cloud_name + unsigned preset) are configured
  bool get isConfigured => SecretConfigService.isCloudinaryConfigured;

  /// Active Cloudinary cloud name from environment or .env
  String get cloudName => SecretConfigService.cloudinaryCloudName;

  /// Active unsigned upload preset name
  String get uploadPreset => SecretConfigService.cloudinaryUploadPreset;

  /// Target Cloudinary upload endpoint
  Uri get _uploadEndpoint =>
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

  // =================================================================
  // Quota Telemetry & Enforcement Methods
  // =================================================================

  /// Retrieves consumed storage in Megabytes (MB)
  static Future<double> getConsumedStorageMb({SharedPreferences? prefs}) async {
    final bytes = await getConsumedBytes(prefs: prefs);
    return bytes / (1024.0 * 1024.0);
  }

  /// Retrieves consumed storage in raw Bytes
  static Future<int> getConsumedBytes({SharedPreferences? prefs}) async {
    if (!_initializedFromPrefs) {
      try {
        final sp = prefs ?? await SharedPreferences.getInstance();
        _inMemoryBytes = sp.getInt(_keyConsumedBytes) ?? 0;
        _initializedFromPrefs = true;
      } catch (_) {
        // Fallback to in-memory bytes if SharedPreferences unavailable in test harness
      }
    }
    return _inMemoryBytes;
  }

  /// Records uploaded bytes to persistent storage
  static Future<void> recordUploadBytes(int bytes, {SharedPreferences? prefs}) async {
    if (bytes <= 0) return;
    _inMemoryBytes += bytes;
    try {
      final sp = prefs ?? await SharedPreferences.getInstance();
      await sp.setInt(_keyConsumedBytes, _inMemoryBytes);
      _initializedFromPrefs = true;
    } catch (_) {}
  }

  /// Checks if the 25 GB quota limit has been reached or exceeded
  static Future<bool> isQuotaExceeded({SharedPreferences? prefs}) async {
    final bytes = await getConsumedBytes(prefs: prefs);
    return bytes >= maxQuotaBytes;
  }

  /// Percentage of the 25 GB quota consumed (0.0% – 100.0%)
  static Future<double> getConsumedStoragePercent({SharedPreferences? prefs}) async {
    final bytes = await getConsumedBytes(prefs: prefs);
    final pct = (bytes / maxQuotaBytes) * 100.0;
    return pct.clamp(0.0, 100.0);
  }

  /// Warning condition: storage >= 80% (20 GB)
  static Future<bool> isQuotaWarning({SharedPreferences? prefs}) async {
    final mb = await getConsumedStorageMb(prefs: prefs);
    return mb >= warningQuotaMb;
  }

  /// Critical condition: storage >= 95% (23.75 GB)
  static Future<bool> isQuotaCritical({SharedPreferences? prefs}) async {
    final mb = await getConsumedStorageMb(prefs: prefs);
    return mb >= criticalQuotaMb;
  }

  /// Manually injects consumed bytes (useful for tests or syncing from cloud telemetry)
  @visibleForTesting
  static Future<void> setSimulatedConsumedBytes(int bytes, {SharedPreferences? prefs}) async {
    _inMemoryBytes = bytes;
    _initializedFromPrefs = true;
    try {
      final sp = prefs ?? await SharedPreferences.getInstance();
      await sp.setInt(_keyConsumedBytes, bytes);
    } catch (_) {}
  }

  // =================================================================
  // Magic Byte Validation & Anti-Abuse Signatures
  // =================================================================

  /// Maximum permissible raw file size before compression (15 MB) to avoid OOM DoS attacks
  static const int maxRawFileSizeBytes = 15 * 1024 * 1024;

  /// Validates whether the given raw [bytes] match a legitimate image file header
  /// (JPEG, PNG, WebP, or GIF) via binary magic bytes.
  static bool isValidImageBytes(List<int> bytes) {
    if (bytes.length < 4) return false;

    // JPEG: FF D8 FF
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return true;
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return true;
    }

    // WebP: 52 49 46 46 (RIFF) ... 57 45 42 50 (WEBP)
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }

    // GIF: 47 49 46 38 (GIF87a or GIF89a)
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38 &&
        (bytes[4] == 0x37 || bytes[4] == 0x39) &&
        bytes[5] == 0x61) {
      return true;
    }

    return false;
  }

  /// Inspects the magic bytes of a local [File] header without loading the entire file into memory.
  static Future<bool> isValidImageFile(File file) async {
    try {
      if (!await file.exists()) return false;
      final length = await file.length();
      if (length < 4 || length > maxRawFileSizeBytes) return false;

      final raf = await file.open(mode: FileMode.read);
      try {
        final header = await raf.read(16);
        return isValidImageBytes(header);
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }

  // =================================================================
  // Upload Pipeline (Guaranteed Image Optimization)
  // =================================================================

  /// Uploads a local image [File] to Cloudinary using an unsigned upload preset.
  /// Enforces:
  /// 1. Anti-abuse rate limit guard (max 10/min, 100/day).
  /// 2. Binary magic byte validation (blocks non-image executable payloads).
  /// 3. 25 GB quota cap guard (blocks upload if 25 GB reached to prevent billing).
  /// 4. Guaranteed pre-upload compression down to FHD 1080p and 75-80% quality.
  /// 5. In-flight Cloudinary auto format and quality parameters.
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

    // Anti-Abuse Rate Limit guard: prevent runaway bot upload loops
    final rateLimit = AntiAbuseRateLimiterService.checkMediaUploadAllowed();
    if (!rateLimit.isAllowed) {
      if (kDebugMode) {
        debugPrint('[CloudinaryService] Upload blocked by rate limiter: ${rateLimit.message}');
      }
      return null;
    }

    // 25 GB Quota guard: prevent charges by halting remote upload
    if (await isQuotaExceeded()) {
      if (kDebugMode) {
        debugPrint('[CloudinaryService] Upload blocked: 25 GB free quota reached to prevent charges.');
      }
      return null;
    }

    // Security & Magic Byte guard: verify file exists, size bounded, and valid image binary header
    if (!await isValidImageFile(file)) {
      if (kDebugMode) {
        debugPrint('[CloudinaryService] Upload blocked: File is invalid, exceeds 15 MB, or is not a genuine image.');
      }
      return null;
    }

    try {

      // Mandatory Pre-Upload Optimization: ensure file is compressed before transmitting
      final optimizedFile = await ImageCompressionService.compressFile(file);

      onProgress?.call(0.1);

      final request = http.MultipartRequest('POST', _uploadEndpoint);
      request.fields['upload_preset'] = uploadPreset;
      // Cloudinary cloud-side auto-quality & auto-format headers
      request.fields['quality'] = 'auto:good';
      request.fields['fetch_format'] = 'auto';

      if (folder != null && folder.isNotEmpty) {
        request.fields['folder'] = folder;
      }
      if (publicId != null && publicId.isNotEmpty) {
        request.fields['public_id'] = publicId;
      }
      if (tags != null && tags.isNotEmpty) {
        request.fields['tags'] = tags.values.join(',');
      }

      final multipartFile = await http.MultipartFile.fromPath('file', optimizedFile.path);
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
        final uploadedBytes = data['bytes'] as int? ?? (await optimizedFile.length());
        await recordUploadBytes(uploadedBytes);
        AntiAbuseRateLimiterService.recordMediaUpload();

        onProgress?.call(1.0);
        if (kDebugMode) {
          debugPrint('[CloudinaryService] Upload succeeded ($uploadedBytes bytes): $secureUrl');
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
  /// Enforces 25 GB limit and pre-upload compression.
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

    // Anti-Abuse Rate Limit guard: prevent runaway byte upload loops
    final rateLimit = AntiAbuseRateLimiterService.checkMediaUploadAllowed();
    if (!rateLimit.isAllowed) {
      if (kDebugMode) {
        debugPrint('[CloudinaryService] Byte upload blocked by rate limiter: ${rateLimit.message}');
      }
      return null;
    }

    // Binary magic byte validation: verify raw buffer matches valid image header
    if (!isValidImageBytes(bytes)) {
      if (kDebugMode) {
        debugPrint('[CloudinaryService] Byte upload blocked: Raw bytes do not match recognized image header.');
      }
      return null;
    }

    // 25 GB Quota guard
    if (await isQuotaExceeded()) {
      if (kDebugMode) {
        debugPrint('[CloudinaryService] Byte upload blocked: 25 GB free quota reached.');
      }
      return null;
    }

    try {
      // Mandatory Pre-Upload Optimization: downscale & compress byte buffer
      final optimizedBytes = await ImageCompressionService.compressBytes(bytes);

      onProgress?.call(0.1);

      final request = http.MultipartRequest('POST', _uploadEndpoint);
      request.fields['upload_preset'] = uploadPreset;
      request.fields['quality'] = 'auto:good';
      request.fields['fetch_format'] = 'auto';

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
        optimizedBytes,
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
        final uploadedBytes = data['bytes'] as int? ?? optimizedBytes.lengthInBytes;
        await recordUploadBytes(uploadedBytes);
        AntiAbuseRateLimiterService.recordMediaUpload();

        onProgress?.call(1.0);
        if (kDebugMode) {
          debugPrint('[CloudinaryService] Byte upload succeeded ($uploadedBytes bytes): $secureUrl');
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

  /// Pings Cloudinary to check credential health, endpoint accessibility, and round-trip latency
  Future<Map<String, dynamic>> pingCloudinary() async {
    if (!isConfigured) {
      return {
        'status': 'Unconfigured',
        'isHealthy': false,
        'cloudName': cloudName.isNotEmpty ? cloudName : '[MISSING]',
        'presetConfigured': uploadPreset.isNotEmpty,
        'latencyMs': -1,
        'message': 'Cloudinary cloud name or upload preset is not set in .env',
      };
    }

    final sw = Stopwatch()..start();
    try {
      final pingUri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/ping');
      final res = await _httpClient.get(pingUri).timeout(const Duration(seconds: 6));
      sw.stop();
      return {
        'status': res.statusCode < 500 ? 'Online' : 'Degraded',
        'isHealthy': res.statusCode < 500,
        'cloudName': cloudName,
        'presetConfigured': uploadPreset.isNotEmpty,
        'latencyMs': sw.elapsedMilliseconds,
        'statusCode': res.statusCode,
        'message': 'Cloudinary endpoint responded in ${sw.elapsedMilliseconds} ms',
      };
    } catch (e) {
      sw.stop();
      return {
        'status': 'Offline / Unreachable',
        'isHealthy': false,
        'cloudName': cloudName,
        'presetConfigured': uploadPreset.isNotEmpty,
        'latencyMs': sw.elapsedMilliseconds,
        'message': 'Connection error: $e',
      };
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
