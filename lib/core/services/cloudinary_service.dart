import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'anti_abuse_rate_limiter_service.dart';
import 'cloudinary_exceptions.dart';
import 'image_compression_service.dart';
import 'secret_config_service.dart';

/// Network bandwidth tiers for adaptive Cloudinary image quality & resolution.
enum CloudinaryNetworkTier {
  eco,   // 2G / metered mobile: 480px, q_auto:eco
  good,  // 3G / 4G standard: 800px, q_auto:good
  best,  // High-speed Wi-Fi: 1280px, q_auto:best
}

/// Structured outcome of a Cloudinary upload operation containing
/// the secure delivery URL, Cloudinary public_id, and unsigned delete_token.
class CloudinaryUploadResult {
  final String secureUrl;
  final String publicId;
  final String? deleteToken;
  final int bytes;

  const CloudinaryUploadResult({
    required this.secureUrl,
    required this.publicId,
    this.deleteToken,
    required this.bytes,
  });
}

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

  /// Target Cloudinary upload endpoint for image uploads
  Uri getUploadEndpoint() =>
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

  /// Resets tracked consumed bytes to 0 (useful for admin telemetry recalibration)
  static Future<void> resetQuotaTelemetry({SharedPreferences? prefs}) async {
    _inMemoryBytes = 0;
    _initializedFromPrefs = true;
    try {
      final sp = prefs ?? await SharedPreferences.getInstance();
      await sp.setInt(_keyConsumedBytes, 0);
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
  // Upload Pipeline (Strictly Images: JPEG, PNG, WebP, GIF)
  // =================================================================

  /// Retrieves any cached delete token for an asset public ID.
  static Future<String?> getCachedDeleteToken(String publicId, {SharedPreferences? prefs}) async {
    try {
      final sp = prefs ?? await SharedPreferences.getInstance();
      return sp.getString('cld_del_token_$publicId');
    } catch (_) {
      return null;
    }
  }

  /// Loop 1: Executes an HTTP multipart request with exponential backoff for transient network issues.
  Future<http.StreamedResponse> _sendWithTransientRetry(
    Future<http.BaseRequest> Function() buildRequest, {
    int maxRetries = 2,
    Duration timeout = const Duration(seconds: 40),
  }) async {
    int attempt = 0;
    while (true) {
      try {
        final req = await buildRequest();
        final streamedResponse = await _httpClient.send(req).timeout(
          timeout,
          onTimeout: () => throw TimeoutException('Cloudinary upload timed out after ${timeout.inSeconds}s'),
        );
        // Retry transient 5xx server errors
        if (streamedResponse.statusCode >= 500 && streamedResponse.statusCode <= 504 && attempt < maxRetries) {
          attempt++;
          final backoffMs = 400 * (1 << attempt);
          await Future.delayed(Duration(milliseconds: backoffMs));
          continue;
        }
        return streamedResponse;
      } on SocketException catch (e) {
        if (attempt < maxRetries) {
          attempt++;
          final backoffMs = 400 * (1 << attempt);
          await Future.delayed(Duration(milliseconds: backoffMs));
          continue;
        }
        throw CloudinaryNetworkException('Network connection failed', originalError: e);
      } on TimeoutException catch (e) {
        if (attempt < maxRetries) {
          attempt++;
          final backoffMs = 400 * (1 << attempt);
          await Future.delayed(Duration(milliseconds: backoffMs));
          continue;
        }
        throw CloudinaryNetworkException('Network connection timed out', originalError: e);
      } catch (e) {
        if (e is http.ClientException && attempt < maxRetries) {
          attempt++;
          final backoffMs = 400 * (1 << attempt);
          await Future.delayed(Duration(milliseconds: backoffMs));
          continue;
        }
        rethrow;
      }
    }
  }

  /// Uploads a local image [File] to Cloudinary, returning full result metadata.
  Future<CloudinaryUploadResult?> uploadImageFileWithResult({
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

    // Loop 3: 25 GB Quota guard: prevent charges by halting remote upload
    if (await isQuotaExceeded()) {
      if (kDebugMode) {
        debugPrint('[CloudinaryService] Upload blocked: 25 GB free quota reached.');
      }
      return null;
    }

    // Loop 4: Security & Magic Byte guard
    if (!await isValidImageFile(file)) {
      if (kDebugMode) {
        debugPrint('[CloudinaryService] Upload blocked: File is invalid, exceeds 15 MB, or is not an image.');
      }
      return null;
    }

    try {
      // Loop 4: Pre-upload optimization with error fallback to original file
      File fileToUpload;
      try {
        fileToUpload = await ImageCompressionService.compressFile(file);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[CloudinaryService] Image compression fallback: uploading original ($e)');
        }
        fileToUpload = file;
      }

      onProgress?.call(0.1);

      final endpoint = getUploadEndpoint();
      Future<http.BaseRequest> buildReq() async {
        final request = http.MultipartRequest('POST', endpoint);
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
        final multipartFile = await http.MultipartFile.fromPath('file', fileToUpload.path);
        request.files.add(multipartFile);
        return request;
      }

      onProgress?.call(0.3);

      // Loop 1: Send request with exponential backoff retry for transient network faults
      final streamedResponse = await _sendWithTransientRetry(buildReq);
      final responseBody = await streamedResponse.stream.bytesToString();
      onProgress?.call(0.9);

      if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final secureUrl = data['secure_url'] as String?;
        final uploadedBytes = data['bytes'] as int? ?? (await fileToUpload.length());
        final deleteToken = data['delete_token'] as String?;
        final returnedPublicId = (data['public_id'] as String?) ?? publicId ?? '';
        await recordUploadBytes(uploadedBytes);
        AntiAbuseRateLimiterService.recordMediaUpload();

        if (deleteToken != null && deleteToken.isNotEmpty) {
          try {
            final sp = await SharedPreferences.getInstance();
            if (publicId != null && publicId.isNotEmpty) {
              await sp.setString('cld_del_token_$publicId', deleteToken);
            }
            if (returnedPublicId.isNotEmpty) {
              await sp.setString('cld_del_token_$returnedPublicId', deleteToken);
            }
          } catch (_) {}
        }

        onProgress?.call(1.0);
        if (kDebugMode) {
          debugPrint('[CloudinaryService] Upload succeeded ($uploadedBytes bytes): $secureUrl');
        }
        if (secureUrl != null && secureUrl.isNotEmpty) {
          return CloudinaryUploadResult(
            secureUrl: secureUrl,
            publicId: returnedPublicId,
            deleteToken: deleteToken,
            bytes: uploadedBytes,
          );
        }
        return null;
      } else {
        // Loop 2 & 3: Defensive error diagnosis
        final errorMsg = _sanitizeErrorMessage(responseBody);
        if (kDebugMode) {
          if (streamedResponse.statusCode == 401 || streamedResponse.statusCode == 403) {
            debugPrint('[CloudinaryService] Auth error (${streamedResponse.statusCode}): $errorMsg');
          } else if (streamedResponse.statusCode == 420 || streamedResponse.statusCode == 429) {
            debugPrint('[CloudinaryService] Rate limit error (${streamedResponse.statusCode}): $errorMsg');
          } else {
            debugPrint('[CloudinaryService] Upload failed (${streamedResponse.statusCode}): $errorMsg');
          }
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

  /// Uploads a local image [File] to Cloudinary using an unsigned upload preset.
  Future<String?> uploadImageFile({
    required File file,
    String? folder,
    String? publicId,
    Map<String, String>? tags,
    void Function(double progress)? onProgress,
  }) async {
    final result = await uploadImageFileWithResult(
      file: file,
      folder: folder,
      publicId: publicId,
      tags: tags,
      onProgress: onProgress,
    );
    return result?.secureUrl;
  }

  static String _sanitizeErrorMessage(String responseBody) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final msg = json['error']?['message'] as String?;
      if (msg != null && msg.isNotEmpty) {
        return msg;
      }
    } catch (_) {}
    return 'API error';
  }

  /// Uploads raw image [Uint8List] bytes directly to Cloudinary, returning full result metadata.
  Future<CloudinaryUploadResult?> uploadImageBytesWithResult({
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

    final rateLimit = AntiAbuseRateLimiterService.checkMediaUploadAllowed();
    if (!rateLimit.isAllowed) {
      if (kDebugMode) {
        debugPrint('[CloudinaryService] Byte upload blocked by rate limiter: ${rateLimit.message}');
      }
      return null;
    }

    // Loop 4: Pre-flight magic byte check
    if (!isValidImageBytes(bytes)) {
      if (kDebugMode) {
        debugPrint('[CloudinaryService] Byte upload blocked: Raw bytes do not match recognized image header.');
      }
      return null;
    }

    // Loop 3: Quota check
    if (await isQuotaExceeded()) {
      if (kDebugMode) {
        debugPrint('[CloudinaryService] Byte upload blocked: 25 GB free quota reached.');
      }
      return null;
    }

    try {
      Uint8List optimizedBytes;
      try {
        optimizedBytes = await ImageCompressionService.compressBytes(bytes);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[CloudinaryService] Byte compression fallback: uploading original ($e)');
        }
        optimizedBytes = bytes;
      }

      onProgress?.call(0.1);

      final endpoint = getUploadEndpoint();
      Future<http.BaseRequest> buildReq() async {
        final request = http.MultipartRequest('POST', endpoint);
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
          optimizedBytes,
          filename: filename,
        );
        request.files.add(multipartFile);
        return request;
      }

      onProgress?.call(0.3);

      // Loop 1: Transient retry wrapper
      final streamedResponse = await _sendWithTransientRetry(buildReq);
      final responseBody = await streamedResponse.stream.bytesToString();
      onProgress?.call(0.9);

      if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final secureUrl = data['secure_url'] as String?;
        final uploadedBytes = data['bytes'] as int? ?? optimizedBytes.lengthInBytes;
        final deleteToken = data['delete_token'] as String?;
        final returnedPublicId = (data['public_id'] as String?) ?? publicId ?? '';
        await recordUploadBytes(uploadedBytes);
        AntiAbuseRateLimiterService.recordMediaUpload();

        if (deleteToken != null && deleteToken.isNotEmpty) {
          try {
            final sp = await SharedPreferences.getInstance();
            if (publicId != null && publicId.isNotEmpty) {
              await sp.setString('cld_del_token_$publicId', deleteToken);
            }
            if (returnedPublicId.isNotEmpty) {
              await sp.setString('cld_del_token_$returnedPublicId', deleteToken);
            }
          } catch (_) {}
        }

        onProgress?.call(1.0);
        if (kDebugMode) {
          debugPrint('[CloudinaryService] Byte upload succeeded ($uploadedBytes bytes): $secureUrl');
        }
        if (secureUrl != null && secureUrl.isNotEmpty) {
          return CloudinaryUploadResult(
            secureUrl: secureUrl,
            publicId: returnedPublicId,
            deleteToken: deleteToken,
            bytes: uploadedBytes,
          );
        }
        return null;
      } else {
        final errorMsg = _sanitizeErrorMessage(responseBody);
        if (kDebugMode) {
          if (streamedResponse.statusCode == 401 || streamedResponse.statusCode == 403) {
            debugPrint('[CloudinaryService] Byte upload auth error (${streamedResponse.statusCode}): $errorMsg');
          } else if (streamedResponse.statusCode == 420 || streamedResponse.statusCode == 429) {
            debugPrint('[CloudinaryService] Byte upload rate limited (${streamedResponse.statusCode}): $errorMsg');
          } else {
            debugPrint('[CloudinaryService] Byte upload failed (${streamedResponse.statusCode}): $errorMsg');
          }
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

  /// Uploads raw image [Uint8List] bytes directly to Cloudinary.
  Future<String?> uploadImageBytes({
    required Uint8List bytes,
    String filename = 'photo.jpg',
    String? folder,
    String? publicId,
    Map<String, String>? tags,
    void Function(double progress)? onProgress,
  }) async {
    final result = await uploadImageBytesWithResult(
      bytes: bytes,
      filename: filename,
      folder: folder,
      publicId: publicId,
      tags: tags,
      onProgress: onProgress,
    );
    return result?.secureUrl;
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
    String cropMode = 'c_limit',
    String? gravity,
  }) {
    if (rawUrl.isEmpty) return rawUrl;
    if (!rawUrl.contains('res.cloudinary.com') || !rawUrl.contains('/upload/')) {
      return rawUrl;
    }

    final transformations = <String>[];
    if (cropMode != 'c_limit' && cropMode.isNotEmpty) {
      transformations.add(cropMode);
    }
    if (gravity != null && gravity.isNotEmpty) {
      transformations.add(gravity);
    }
    if (width != null && width > 0) {
      transformations.add('w_$width');
    }
    if (height != null && height > 0) {
      transformations.add('h_$height');
    }
    if (cropMode == 'c_limit' && (width != null || height != null)) {
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

  /// Generates a thumbnail URL cropped to a square (default 200x200) with face/auto gravity.
  static String getThumbnailUrl(String rawUrl, {int size = 200, bool cropFace = false}) {
    if (rawUrl.isEmpty || !rawUrl.contains('res.cloudinary.com') || !rawUrl.contains('/upload/')) {
      return rawUrl;
    }
    final gravity = cropFace ? 'g_face' : 'g_auto';
    return getOptimizedUrl(
      rawUrl,
      width: size,
      height: size,
      cropMode: 'c_thumb',
      gravity: gravity,
      autoFormat: true,
    );
  }

  /// Generates an optimized medium card banner URL (e.g. 800x500 fill cropped with auto gravity).
  static String getCardBannerUrl(String rawUrl, {int width = 800, int height = 500}) {
    if (rawUrl.isEmpty || !rawUrl.contains('res.cloudinary.com') || !rawUrl.contains('/upload/')) {
      return rawUrl;
    }
    return getOptimizedUrl(
      rawUrl,
      width: width,
      height: height,
      cropMode: 'c_fill',
      gravity: 'g_auto',
      autoFormat: true,
    );
  }

  /// Generates an optimized high-resolution zoom preview URL (up to 1920px width limit).
  static String getPreviewUrl(String rawUrl, {int maxWidth = 1920}) {
    if (rawUrl.isEmpty || !rawUrl.contains('res.cloudinary.com') || !rawUrl.contains('/upload/')) {
      return rawUrl;
    }
    return getOptimizedUrl(
      rawUrl,
      width: maxWidth,
      cropMode: 'c_limit',
      autoFormat: true,
    );
  }

  /// Generates a Low-Quality Image Placeholder (LQIP) URL (tiny blurred thumbnail for instant rendering).
  static String getLqipUrl(String rawUrl, {int width = 40}) {
    if (rawUrl.isEmpty || !rawUrl.contains('res.cloudinary.com') || !rawUrl.contains('/upload/')) {
      return rawUrl;
    }
    final transformString = 'c_scale,w_$width,e_blur:1000,q_10,f_auto/';
    if (rawUrl.contains('/upload/$transformString')) return rawUrl;
    return rawUrl.replaceFirst('/upload/', '/upload/$transformString');
  }

  /// Generates a signed Cloudinary delivery URL with signature token `s--<sig>--`
  /// to protect against unauthorized image parameter tampering and hotlink scraping.
  /// If [apiSecret] is not configured, returns the URL with requested transformations.
  static String getSignedUrl(
    String rawUrl, {
    String? transformation,
    String? apiSecret,
  }) {
    if (rawUrl.isEmpty || !rawUrl.contains('res.cloudinary.com') || !rawUrl.contains('/upload/')) {
      return rawUrl;
    }

    final secret = apiSecret ?? SecretConfigService.cloudinaryApiSecret;
    final uploadIndex = rawUrl.indexOf('/upload/');
    final prefix = rawUrl.substring(0, uploadIndex + '/upload/'.length);
    var remainder = rawUrl.substring(uploadIndex + '/upload/'.length);

    // If already signed, strip existing signature
    if (remainder.startsWith('s--') && remainder.contains('--/')) {
      remainder = remainder.substring(remainder.indexOf('--/') + 3);
    }

    final effectiveTransform = transformation != null && transformation.isNotEmpty
        ? (transformation.endsWith('/') ? transformation : '$transformation/')
        : '';

    if (secret.isEmpty) {
      return '$prefix$effectiveTransform$remainder';
    }

    final toSign = '$effectiveTransform$remainder$secret';
    final digest = sha1.convert(utf8.encode(toSign));
    final b64 = base64Url.encode(digest.bytes).replaceAll('=', '');
    final sig = b64.length >= 8 ? b64.substring(0, 8) : b64;

    return '${prefix}s--$sig--/$effectiveTransform$remainder';
  }

  /// Injects an unobtrusive copyright watermark overlay on the image.
  static String addWatermark(String rawUrl, {String text = 'TrackMyTrip'}) {
    if (rawUrl.isEmpty || !rawUrl.contains('res.cloudinary.com') || !rawUrl.contains('/upload/')) {
      return rawUrl;
    }
    final encodedText = Uri.encodeComponent(text);
    final watermarkTransform = 'l_text:Roboto_16_bold:$encodedText,g_south_east,x_12,y_12,o_70/';
    if (rawUrl.contains(watermarkTransform)) return rawUrl;
    return rawUrl.replaceFirst('/upload/', '/upload/$watermarkTransform');
  }

  /// Generates a network-adaptive delivery URL tailored to connection bandwidth.
  static String getAdaptiveUrl(
    String rawUrl, {
    CloudinaryNetworkTier tier = CloudinaryNetworkTier.good,
    int? customWidth,
  }) {
    if (rawUrl.isEmpty || !rawUrl.contains('res.cloudinary.com') || !rawUrl.contains('/upload/')) {
      return rawUrl;
    }
    final int width;
    final String quality;
    switch (tier) {
      case CloudinaryNetworkTier.eco:
        width = customWidth ?? 480;
        quality = 'q_auto:eco';
        break;
      case CloudinaryNetworkTier.good:
        width = customWidth ?? 800;
        quality = 'q_auto:good';
        break;
      case CloudinaryNetworkTier.best:
        width = customWidth ?? 1280;
        quality = 'q_auto:best';
        break;
    }

    final transformString = 'w_$width,c_limit,$quality,f_auto/';
    if (rawUrl.contains('/upload/$transformString')) return rawUrl;
    return rawUrl.replaceFirst('/upload/', '/upload/$transformString');
  }

  /// Extracts the Cloudinary asset public_id from a CDN delivery URL.
  /// Example:
  /// https://res.cloudinary.com/dcj4v7toh/image/upload/v12345/trackmytrip/trips/trip1/memories/mem_abc.jpg
  /// -> 'trackmytrip/trips/trip1/memories/mem_abc'
  static String? extractPublicId(String url) {
    if (url.isEmpty || !url.contains('res.cloudinary.com') || !url.contains('/upload/')) {
      return null;
    }
    try {
      final uploadIndex = url.indexOf('/upload/');
      var path = url.substring(uploadIndex + '/upload/'.length);

      // Strip transformations (e.g. w_800,c_limit,q_auto,f_auto/)
      while (path.contains('/') && !path.startsWith('v') && RegExp(r'^[a-z]_[^/]+/').hasMatch(path)) {
        path = path.substring(path.indexOf('/') + 1);
      }
      // Strip version prefix if present (e.g. v1234567890/)
      if (RegExp(r'^v[0-9]+/').hasMatch(path)) {
        path = path.substring(path.indexOf('/') + 1);
      }
      // Strip extension (.jpg, .png, .webp)
      final dotIndex = path.lastIndexOf('.');
      if (dotIndex != -1) {
        path = path.substring(0, dotIndex);
      }
      return path.isNotEmpty ? path : null;
    } catch (_) {
      return null;
    }
  }

  /// Deletes an asset from Cloudinary:
  /// 1. Tries `delete_by_token` using the cached client-side delete token (available for unsigned presets).
  /// 2. Tries authenticated signed Upload API `destroy` if API Key & Secret are configured.
  /// Returns `true` if deletion succeeded or was confirmed, `false` otherwise.
  Future<bool> deleteAsset({
    required String publicId,
    String? deleteToken,
  }) async {
    if (!isConfigured) return false;

    // 1. Check for delete_token (from parameter or cached SharedPreferences)
    String? token = deleteToken;
    if (token == null || token.isEmpty) {
      try {
        final sp = await SharedPreferences.getInstance();
        token = sp.getString('cld_del_token_$publicId');
      } catch (_) {}
    }

    if (token != null && token.isNotEmpty) {
      try {
        final tokenUri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/delete_by_token');
        final response = await _httpClient.post(
          tokenUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': token}),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['result'] == 'ok' || data['result'] == 'not found') {
            if (kDebugMode) {
              debugPrint('[CloudinaryService] Successfully deleted asset via delete_token: $publicId');
            }
            try {
              final sp = await SharedPreferences.getInstance();
              await sp.remove('cld_del_token_$publicId');
            } catch (_) {}
            return true;
          }
        } else if (response.statusCode == 404) {
          if (kDebugMode) {
            debugPrint('[CloudinaryService] Asset already absent (404 idempotent): $publicId');
          }
          try {
            final sp = await SharedPreferences.getInstance();
            await sp.remove('cld_del_token_$publicId');
          } catch (_) {}
          return true;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[CloudinaryService] delete_by_token failed: $e');
        }
      }
    }

    // 2. Check for signed destroy API (if CLOUDINARY_API_KEY and CLOUDINARY_API_SECRET are present)
    final apiKey = SecretConfigService.cloudinaryApiKey;
    final apiSecret = SecretConfigService.cloudinaryApiSecret;

    if (apiKey.isNotEmpty && apiSecret.isNotEmpty) {
      try {
        final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
        // Cloudinary signed destroy expects signature of 'public_id=...&timestamp=...<secret>'
        final toSign = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
        final signature = sha1.convert(utf8.encode(toSign)).toString();

        final destroyUri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy');
        final response = await _httpClient.post(
          destroyUri,
          body: {
            'public_id': publicId,
            'timestamp': timestamp,
            'api_key': apiKey,
            'signature': signature,
          },
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['result'] == 'ok' || data['result'] == 'not found') {
            if (kDebugMode) {
              debugPrint('[CloudinaryService] Successfully deleted asset via signed destroy: $publicId');
            }
            try {
              final sp = await SharedPreferences.getInstance();
              await sp.remove('cld_del_token_$publicId');
            } catch (_) {}
            return true;
          }
        } else if (response.statusCode == 404) {
          if (kDebugMode) {
            debugPrint('[CloudinaryService] Signed destroy: asset already absent (404 idempotent): $publicId');
          }
          try {
            final sp = await SharedPreferences.getInstance();
            await sp.remove('cld_del_token_$publicId');
          } catch (_) {}
          return true;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[CloudinaryService] Signed destroy failed: $e');
        }
      }
    }

    if (kDebugMode) {
      debugPrint('[CloudinaryService] Note: Asset $publicId was queued or delete_token expired.');
    }
    return false;
  }

  /// Batch deletes multiple assets from Cloudinary with bounded concurrency (default 3 parallel workers).
  /// Returns a summary map: `{'total': int, 'succeeded': int, 'failed': int}`.
  Future<Map<String, int>> deleteAssetsBatch(
    List<String> publicIds, {
    Map<String, String>? deleteTokens,
    int concurrency = 3,
  }) async {
    final validIds = publicIds.where((id) => id.isNotEmpty).toList();
    if (validIds.isEmpty || !isConfigured) {
      return {'total': validIds.length, 'succeeded': 0, 'failed': validIds.length};
    }

    int succeeded = 0;
    int failed = 0;
    final idQueue = List<String>.from(validIds);

    Future<void> runWorker() async {
      while (idQueue.isNotEmpty) {
        final id = idQueue.removeAt(0);
        final token = deleteTokens?[id];
        final ok = await deleteAsset(publicId: id, deleteToken: token);
        if (ok) {
          succeeded++;
        } else {
          failed++;
        }
      }
    }

    final poolSize = concurrency.clamp(1, 10);
    final workerPool = <Future<void>>[];
    for (int i = 0; i < poolSize && i < validIds.length; i++) {
      workerPool.add(runWorker());
    }

    await Future.wait(workerPool);

    return {
      'total': validIds.length,
      'succeeded': succeeded,
      'failed': failed,
    };
  }
}

/// Riverpod provider for CloudinaryService
final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  return CloudinaryService();
});
