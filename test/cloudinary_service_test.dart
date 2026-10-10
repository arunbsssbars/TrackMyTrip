import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trackmytrip/core/services/anti_abuse_rate_limiter_service.dart';
import 'package:trackmytrip/core/services/cloudinary_service.dart';
import 'package:trackmytrip/core/services/secret_config_service.dart';

void main() {
  group('CloudinaryService Tests', () {
    setUp(() {
      SecretConfigService.reset();
      AntiAbuseRateLimiterService.resetForTesting();
    });

    tearDown(() {
      SecretConfigService.reset();
    });

    test('isConfigured is true with built-in fallbacks and false with placeholder keys', () {
      final service = CloudinaryService();
      expect(service.isConfigured, isTrue);
      expect(service.cloudName, equals('dcj4v7toh'));

      SecretConfigService.setMockVariables({
        'CLOUDINARY_CLOUD_NAME': 'your_cloudinary_cloud_name',
        'CLOUDINARY_UPLOAD_PRESET': 'your_unsigned_upload_preset',
      });
      expect(service.isConfigured, isFalse);
    });

    test('isConfigured is true when valid keys are provided', () {
      SecretConfigService.setMockVariables({
        'CLOUDINARY_CLOUD_NAME': 'my_prod_cloud_123',
        'CLOUDINARY_UPLOAD_PRESET': 'preset_trips_unsigned',
      });

      final service = CloudinaryService();
      expect(service.isConfigured, isTrue);
      expect(service.cloudName, equals('my_prod_cloud_123'));
      expect(service.uploadPreset, equals('preset_trips_unsigned'));
    });

    test('getOptimizedUrl leaves non-cloudinary URLs unchanged', () {
      const nonCloudUrl = 'https://firebasestorage.googleapis.com/v0/b/app.appspot.com/o/mem.jpg';
      expect(CloudinaryService.getOptimizedUrl(nonCloudUrl, width: 400), equals(nonCloudUrl));
    });

    test('getOptimizedUrl inserts transformations into Cloudinary URL', () {
      const rawUrl = 'https://res.cloudinary.com/testcloud/image/upload/v12345/trip_memory.jpg';
      final optimized = CloudinaryService.getOptimizedUrl(
        rawUrl,
        width: 800,
        height: 600,
        quality: 80,
        autoFormat: true,
      );

      expect(
        optimized,
        equals('https://res.cloudinary.com/testcloud/image/upload/w_800,h_600,c_limit,q_80,f_auto/v12345/trip_memory.jpg'),
      );
    });

    test('getOptimizedUrl prevents duplicate transformation chains', () {
      const alreadyOptimized = 'https://res.cloudinary.com/testcloud/image/upload/w_800,c_limit,q_auto,f_auto/v12345/photo.jpg';
      final reOptimized = CloudinaryService.getOptimizedUrl(
        alreadyOptimized,
        width: 800,
        autoFormat: true,
      );

      expect(reOptimized, equals(alreadyOptimized));
    });

    test('preset transformations generate correct optimized URLs', () {
      const rawUrl = 'https://res.cloudinary.com/testcloud/image/upload/v12345/trip_memory.jpg';

      final thumb = CloudinaryService.getThumbnailUrl(rawUrl, size: 150, cropFace: true);
      expect(thumb, contains('/upload/c_thumb,g_face,w_150,h_150,q_auto,f_auto/'));

      final cardBanner = CloudinaryService.getCardBannerUrl(rawUrl, width: 600, height: 400);
      expect(cardBanner, contains('/upload/c_fill,g_auto,w_600,h_400,q_auto,f_auto/'));

      final preview = CloudinaryService.getPreviewUrl(rawUrl, maxWidth: 1200);
      expect(preview, contains('/upload/w_1200,c_limit,q_auto,f_auto/'));

      final lqip = CloudinaryService.getLqipUrl(rawUrl, width: 30);
      expect(lqip, contains('/upload/c_scale,w_30,e_blur:1000,q_10,f_auto/'));
    });

    test('getSignedUrl inserts standard s--sig-- token when apiSecret provided', () {
      const rawUrl = 'https://res.cloudinary.com/testcloud/image/upload/v12345/trip_memory.jpg';

      // 1. With secret provided
      final signed = CloudinaryService.getSignedUrl(
        rawUrl,
        transformation: 'w_800,c_limit',
        apiSecret: 'my_secret_key',
      );
      expect(signed, startsWith('https://res.cloudinary.com/testcloud/image/upload/s--'));
      expect(signed, contains('--/w_800,c_limit/v12345/trip_memory.jpg'));

      // 2. Without secret, degrades gracefully to transformation
      final unsigned = CloudinaryService.getSignedUrl(
        rawUrl,
        transformation: 'w_800,c_limit',
        apiSecret: '',
      );
      expect(unsigned, equals('https://res.cloudinary.com/testcloud/image/upload/w_800,c_limit/v12345/trip_memory.jpg'));
    });

    test('addWatermark overlays brand mark text onto transformation chain', () {
      const rawUrl = 'https://res.cloudinary.com/testcloud/image/upload/v12345/trip_memory.jpg';
      final watermarked = CloudinaryService.addWatermark(rawUrl, text: 'TrackMyTrip');

      expect(watermarked, contains('l_text:Roboto_16_bold:TrackMyTrip,g_south_east,x_12,y_12,o_70/'));
    });

    test('getAdaptiveUrl adjusts quality and dimensions based on network tier', () {
      const rawUrl = 'https://res.cloudinary.com/testcloud/image/upload/v12345/trip_memory.jpg';

      final eco = CloudinaryService.getAdaptiveUrl(rawUrl, tier: CloudinaryNetworkTier.eco);
      expect(eco, contains('/upload/w_480,c_limit,q_auto:eco,f_auto/'));

      final good = CloudinaryService.getAdaptiveUrl(rawUrl, tier: CloudinaryNetworkTier.good);
      expect(good, contains('/upload/w_800,c_limit,q_auto:good,f_auto/'));

      final best = CloudinaryService.getAdaptiveUrl(rawUrl, tier: CloudinaryNetworkTier.best);
      expect(best, contains('/upload/w_1280,c_limit,q_auto:best,f_auto/'));
    });

    test('isValidImageBytes recognizes valid image formats (JPEG, PNG, WebP, GIF) and rejects others', () {
      // JPEG
      expect(CloudinaryService.isValidImageBytes([0xFF, 0xD8, 0xFF, 0xEE]), isTrue);
      // PNG
      expect(CloudinaryService.isValidImageBytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]), isTrue);
      // WebP
      final webpHeader = [0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50];
      expect(CloudinaryService.isValidImageBytes(webpHeader), isTrue);
      // GIF
      expect(CloudinaryService.isValidImageBytes([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]), isTrue);

      // Audio / video containers are rejected
      final mp4Header = [0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70];
      expect(CloudinaryService.isValidImageBytes(mp4Header), isFalse);
      final mp3Header = [0x49, 0x44, 0x33, 0x03, 0x00, 0x00];
      expect(CloudinaryService.isValidImageBytes(mp3Header), isFalse);
      // Executable / invalid
      expect(CloudinaryService.isValidImageBytes([0x4D, 0x5A, 0x90, 0x00]), isFalse);
    });

    test('uploadImageBytes successfully sends multipart request and returns secure_url', () async {
      SecretConfigService.setMockVariables({
        'CLOUDINARY_CLOUD_NAME': 'mycloud',
        'CLOUDINARY_UPLOAD_PRESET': 'trip_unsigned',
      });

      final mockClient = MockClient((request) async {
        expect(request.url.toString(), equals('https://api.cloudinary.com/v1_1/mycloud/image/upload'));
        expect(request.method, equals('POST'));

        return http.Response(
          jsonEncode({
            'asset_id': 'abc12345',
            'public_id': 'trackmytrip/memories/mem_1',
            'secure_url': 'https://res.cloudinary.com/mycloud/image/upload/v12345/mem_1.jpg',
            'bytes': 4096,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = CloudinaryService(httpClient: mockClient);
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]);

      final url = await service.uploadImageBytes(
        bytes: bytes,
        folder: 'trackmytrip/memories',
        publicId: 'mem_1',
      );

      expect(url, equals('https://res.cloudinary.com/mycloud/image/upload/v12345/mem_1.jpg'));
    });

    test('uploadImageBytes handles API errors gracefully returning null', () async {
      SecretConfigService.setMockVariables({
        'CLOUDINARY_CLOUD_NAME': 'mycloud',
        'CLOUDINARY_UPLOAD_PRESET': 'invalid_preset',
      });

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'Upload preset not found'}
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = CloudinaryService(httpClient: mockClient);
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]);

      final url = await service.uploadImageBytes(bytes: bytes);
      expect(url, isNull);
    });

    test('uploadImageFile returns null when file does not exist', () async {
      SecretConfigService.setMockVariables({
        'CLOUDINARY_CLOUD_NAME': 'mycloud',
        'CLOUDINARY_UPLOAD_PRESET': 'preset',
      });

      final service = CloudinaryService();
      final nonExistentFile = File('non_existent_image_path_123.jpg');

      final url = await service.uploadImageFile(file: nonExistentFile);
      expect(url, isNull);
    });

    test('25 GB quota metrics calculate usage and thresholds properly', () async {
      // 0 MB initially
      await CloudinaryService.setSimulatedConsumedBytes(0);
      expect(await CloudinaryService.getConsumedStorageMb(), equals(0.0));
      expect(await CloudinaryService.getConsumedStoragePercent(), equals(0.0));
      expect(await CloudinaryService.isQuotaWarning(), isFalse);
      expect(await CloudinaryService.isQuotaExceeded(), isFalse);

      // Simulate 21 GB consumed (warning threshold >= 20 GB)
      const int twentyOneGb = 21 * 1024 * 1024 * 1024;
      await CloudinaryService.setSimulatedConsumedBytes(twentyOneGb);
      expect(await CloudinaryService.isQuotaWarning(), isTrue);
      expect(await CloudinaryService.isQuotaExceeded(), isFalse);

      // Simulate 25 GB consumed (exceeded threshold)
      const int twentyFiveGb = 25 * 1024 * 1024 * 1024;
      await CloudinaryService.setSimulatedConsumedBytes(twentyFiveGb);
      expect(await CloudinaryService.isQuotaExceeded(), isTrue);
      expect(await CloudinaryService.getConsumedStoragePercent(), equals(100.0));
    });

    test('uploadImageBytes blocks upload when 25 GB quota is exceeded', () async {
      SecretConfigService.setMockVariables({
        'CLOUDINARY_CLOUD_NAME': 'mycloud',
        'CLOUDINARY_UPLOAD_PRESET': 'preset',
      });

      // Simulate 26 GB consumed (strictly exceeds 25 GB limit)
      const int overLimit = 26 * 1024 * 1024 * 1024;
      await CloudinaryService.setSimulatedConsumedBytes(overLimit);

      // Verify that no HTTP network call is even attempted
      final mockClient = MockClient((request) async {
        fail('Network request should not be attempted when quota is exceeded');
      });

      final service = CloudinaryService(httpClient: mockClient);
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]);

      final url = await service.uploadImageBytes(bytes: bytes);
      // Must be blocked to prevent billing
      expect(url, isNull);
    });

    test('pingCloudinary returns status and latency telemetry', () async {
      SecretConfigService.setMockVariables({
        'CLOUDINARY_CLOUD_NAME': 'testcloud',
        'CLOUDINARY_UPLOAD_PRESET': 'testpreset',
      });

      final mockClient = MockClient((request) async {
        expect(request.url.toString(), contains('ping'));
        return http.Response('OK', 200);
      });

      final service = CloudinaryService(httpClient: mockClient);
      final ping = await service.pingCloudinary();

      expect(ping['status'], equals('Online'));
      expect(ping['isHealthy'], isTrue);
      expect(ping['cloudName'], equals('testcloud'));
      expect(ping['presetConfigured'], isTrue);
      expect(ping['latencyMs'], isNonNegative);
    });

    test('extractPublicId accurately parses public_id from raw and transformed Cloudinary URLs', () {
      const standardUrl = 'https://res.cloudinary.com/mycloud/image/upload/v12345/trackmytrip/trips/trip1/memories/mem_abc.jpg';
      expect(
        CloudinaryService.extractPublicId(standardUrl),
        equals('trackmytrip/trips/trip1/memories/mem_abc'),
      );

      const transformedUrl = 'https://res.cloudinary.com/mycloud/image/upload/w_800,c_limit,q_auto,f_auto/v12345/trackmytrip/trips/trip1/memories/mem_abc.jpg';
      expect(
        CloudinaryService.extractPublicId(transformedUrl),
        equals('trackmytrip/trips/trip1/memories/mem_abc'),
      );

      const nonVersionedUrl = 'https://res.cloudinary.com/mycloud/image/upload/trackmytrip/trips/trip1/memories/mem_abc.png';
      expect(
        CloudinaryService.extractPublicId(nonVersionedUrl),
        equals('trackmytrip/trips/trip1/memories/mem_abc'),
      );

      const nonCloudUrl = 'https://example.com/photos/mem.jpg';
      expect(CloudinaryService.extractPublicId(nonCloudUrl), isNull);
    });

    test('deleteAsset succeeds via delete_by_token', () async {
      SecretConfigService.setMockVariables({
        'CLOUDINARY_CLOUD_NAME': 'mycloud',
        'CLOUDINARY_UPLOAD_PRESET': 'preset',
      });

      final mockClient = MockClient((request) async {
        expect(request.url.toString(), equals('https://api.cloudinary.com/v1_1/mycloud/delete_by_token'));
        expect(request.method, equals('POST'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['token'], equals('token_12345'));
        return http.Response(jsonEncode({'result': 'ok'}), 200);
      });

      final service = CloudinaryService(httpClient: mockClient);
      final success = await service.deleteAsset(
        publicId: 'trackmytrip/trips/trip1/memories/mem_1',
        deleteToken: 'token_12345',
      );
      expect(success, isTrue);
    });

    test('deleteAsset succeeds via signed destroy when API key and secret are configured', () async {
      SecretConfigService.setMockVariables({
        'CLOUDINARY_CLOUD_NAME': 'mycloud',
        'CLOUDINARY_UPLOAD_PRESET': 'preset',
        'CLOUDINARY_API_KEY': '123456789',
        'CLOUDINARY_API_SECRET': 'secret_abc_xyz',
      });

      final mockClient = MockClient((request) async {
        expect(request.url.toString(), equals('https://api.cloudinary.com/v1_1/mycloud/image/destroy'));
        expect(request.method, equals('POST'));
        expect(request.bodyFields['public_id'], equals('trackmytrip/trips/trip1/memories/mem_1'));
        expect(request.bodyFields['api_key'], equals('123456789'));
        expect(request.bodyFields['signature'], isNotEmpty);
        expect(request.bodyFields['timestamp'], isNotEmpty);
        return http.Response(jsonEncode({'result': 'ok'}), 200);
      });

      final service = CloudinaryService(httpClient: mockClient);
      final success = await service.deleteAsset(
        publicId: 'trackmytrip/trips/trip1/memories/mem_1',
      );
      expect(success, isTrue);
    });

    test('deleteAssetsBatch concurrently deletes multiple assets and aggregates stats', () async {
      SecretConfigService.setMockVariables({
        'CLOUDINARY_CLOUD_NAME': 'mycloud',
        'CLOUDINARY_UPLOAD_PRESET': 'preset',
      });

      final deletedIds = <String>[];
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('delete_by_token')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final token = body['token'] as String;
          deletedIds.add(token);
          if (token == 'token_fail') {
            return http.Response(jsonEncode({'result': 'error'}), 400);
          }
          return http.Response(jsonEncode({'result': 'ok'}), 200);
        }
        return http.Response('Not Found', 404);
      });

      final service = CloudinaryService(httpClient: mockClient);
      final tokens = {
        'id_1': 'token_1',
        'id_2': 'token_2',
        'id_3': 'token_fail',
      };

      final result = await service.deleteAssetsBatch(
        ['id_1', 'id_2', 'id_3'],
        deleteTokens: tokens,
        concurrency: 2,
      );

      expect(result['total'], equals(3));
      expect(result['succeeded'], equals(2));
      expect(result['failed'], equals(1));
      expect(deletedIds.length, equals(3));
    });
  });
}
