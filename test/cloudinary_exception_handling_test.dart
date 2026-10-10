import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackmytrip/core/services/anti_abuse_rate_limiter_service.dart';
import 'package:trackmytrip/core/services/cloudinary_service.dart';
import 'package:trackmytrip/core/services/secret_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cloudinary 5-Loop Exception & Resilience Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      SecretConfigService.reset();
      AntiAbuseRateLimiterService.resetForTesting();
      await CloudinaryService.resetQuotaTelemetry();
      SecretConfigService.setMockVariables({
        'CLOUDINARY_CLOUD_NAME': 'test_resilience_cloud',
        'CLOUDINARY_UPLOAD_PRESET': 'test_resilience_preset',
        'CLOUDINARY_API_KEY': 'resilience_key',
        'CLOUDINARY_API_SECRET': 'resilience_secret',
      });
    });

    tearDown(() {
      SecretConfigService.reset();
    });

    // =========================================================================
    // Loop 1: Network & Transient Faults (SocketException, Timeout, 5xx Retry)
    // =========================================================================
    group('Loop 1: Network & Transient Fault Resilience', () {
      test('Retries transient 500/502/503 errors and succeeds when server recovers', () async {
        int callCount = 0;
        final mockClient = MockClient.streaming((request, bodyStream) async {
          callCount++;
          if (callCount < 2) {
            // First attempt fails with 503 Service Unavailable
            return http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({'error': {'message': 'Backend unavailable'}}))),
              503,
              headers: {'content-type': 'application/json'},
            );
          }
          // Second attempt succeeds
          final successBody = jsonEncode({
            'asset_id': 'recovered_asset_123',
            'public_id': 'trackmytrip/trips/trip1/memories/mem_rec',
            'secure_url': 'https://res.cloudinary.com/test_resilience_cloud/image/upload/v1/mem_rec.jpg',
            'bytes': 512,
            'delete_token': 'del_token_recovered',
          });
          return http.StreamedResponse(
            Stream.value(utf8.encode(successBody)),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = CloudinaryService(httpClient: mockClient);
        final validJpg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x00, 0x01]);

        final result = await service.uploadImageBytesWithResult(bytes: validJpg);

        expect(result, isNotNull);
        expect(result!.secureUrl, contains('mem_rec.jpg'));
        expect(result.deleteToken, equals('del_token_recovered'));
        expect(callCount, equals(2));
      });

      test('Gracefully returns null when network retries are exhausted', () async {
        final mockClient = MockClient.streaming((request, bodyStream) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'error': {'message': 'Persistent gateway timeout'}}))),
            504,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = CloudinaryService(httpClient: mockClient);
        final validJpg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x00, 0x01]);

        final result = await service.uploadImageBytes(bytes: validJpg);
        expect(result, isNull);
      });
    });

    // =========================================================================
    // Loop 2: Client Error Parsing & Idempotent Deletion (400, 401, 404)
    // =========================================================================
    group('Loop 2: Client Errors & Idempotent Deletion', () {
      test('HTTP 400 Bad Request extracts clean error message without crashing', () async {
        final mockClient = MockClient.streaming((request, bodyStream) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'error': {'message': 'Invalid transformation width'}}))),
            400,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = CloudinaryService(httpClient: mockClient);
        final validJpg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x00, 0x01]);

        final result = await service.uploadImageBytesWithResult(bytes: validJpg);
        expect(result, isNull);
      });

      test('delete_by_token handles 404 as idempotent success', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.toString(), contains('delete_by_token'));
          return http.Response(
            jsonEncode({'error': {'message': 'Token or asset not found'}}),
            404,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = CloudinaryService(httpClient: mockClient);
        final success = await service.deleteAsset(
          publicId: 'trackmytrip/memories/already_deleted',
          deleteToken: 'expired_token',
        );

        // Idempotent: absent asset is a successful deletion
        expect(success, isTrue);
      });

      test('delete_by_token handles {"result": "not found"} as idempotent success', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'result': 'not found'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = CloudinaryService(httpClient: mockClient);
        final success = await service.deleteAsset(
          publicId: 'trackmytrip/memories/not_found_asset',
          deleteToken: 'some_token',
        );

        expect(success, isTrue);
      });

      test('Signed destroy handles 404 as idempotent success', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.toString(), contains('image/destroy'));
          return http.Response(
            jsonEncode({'error': {'message': 'Resource not found'}}),
            404,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = CloudinaryService(httpClient: mockClient);
        final success = await service.deleteAsset(
          publicId: 'trackmytrip/memories/absent_asset',
        );

        expect(success, isTrue);
      });
    });

    // =========================================================================
    // Loop 3: Quota & Rate Limit Protection (HTTP 420/429 & 25 GB Cap)
    // =========================================================================
    group('Loop 3: Quota & Rate Limit Resilience', () {
      test('HTTP 429 Too Many Requests handles rate limit gracefully', () async {
        final mockClient = MockClient.streaming((request, bodyStream) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'error': {'message': 'Rate limit exceeded'}}))),
            429,
            headers: {
              'content-type': 'application/json',
              'retry-after': '60',
            },
          );
        });

        final service = CloudinaryService(httpClient: mockClient);
        final validJpg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x00, 0x01]);

        final result = await service.uploadImageBytesWithResult(bytes: validJpg);
        expect(result, isNull);
      });

      test('25 GB cap prevents network dispatch entirely', () async {
        // Pre-fill 26 GB consumed
        const int overQuotaBytes = 26 * 1024 * 1024 * 1024;
        await CloudinaryService.setSimulatedConsumedBytes(overQuotaBytes);

        bool networkCalled = false;
        final mockClient = MockClient((request) async {
          networkCalled = true;
          return http.Response('OK', 200);
        });

        final service = CloudinaryService(httpClient: mockClient);
        final validJpg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x00, 0x01]);

        final result = await service.uploadImageBytes(bytes: validJpg);
        expect(result, isNull);
        expect(networkCalled, isFalse);
      });
    });

    // =========================================================================
    // Loop 4: Payload Integrity & Pre-Flight Validation
    // =========================================================================
    group('Loop 4: Payload Integrity & Validation', () {
      test('Empty bytes (< 4 bytes) rejected without making network request', () async {
        bool networkCalled = false;
        final mockClient = MockClient((request) async {
          networkCalled = true;
          return http.Response('OK', 200);
        });

        final service = CloudinaryService(httpClient: mockClient);
        final result = await service.uploadImageBytes(bytes: Uint8List.fromList([0x00, 0x01]));

        expect(result, isNull);
        expect(networkCalled, isFalse);
      });

      test('Non-image binary rejected by magic byte validator', () async {
        bool networkCalled = false;
        final mockClient = MockClient((request) async {
          networkCalled = true;
          return http.Response('OK', 200);
        });

        final service = CloudinaryService(httpClient: mockClient);
        // Random binary payload that is not JPG/PNG/WebP/GIF
        final fakeBytes = Uint8List.fromList([0x12, 0x34, 0x56, 0x78, 0x90, 0xAB]);

        final result = await service.uploadImageBytes(bytes: fakeBytes);
        expect(result, isNull);
        expect(networkCalled, isFalse);
      });
    });

    // =========================================================================
    // Loop 5: Deletion Drift & Delete Token Lifecycle
    // =========================================================================
    group('Loop 5: Deletion Drift & Token Lifecycle', () {
      test('Upload saves delete_token in SharedPreferences and deleteAsset uses it', () async {
        final mockClient = MockClient((request) async {
          if (request.url.toString().contains('/image/upload')) {
            final resp = jsonEncode({
              'secure_url': 'https://res.cloudinary.com/test_resilience_cloud/image/upload/v1/mem_token_test.jpg',
              'public_id': 'trackmytrip/memories/mem_token_test',
              'delete_token': 'secret_delete_token_xyz',
              'bytes': 2048,
            });
            return http.Response(resp, 200, headers: {'content-type': 'application/json'});
          }
          if (request.url.toString().contains('/delete_by_token')) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['token'], equals('secret_delete_token_xyz'));
            return http.Response(jsonEncode({'result': 'ok'}), 200);
          }
          return http.Response('Not Found', 404);
        });

        final service = CloudinaryService(httpClient: mockClient);
        final validJpg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x00, 0x01]);

        final uploadResult = await service.uploadImageBytesWithResult(
          bytes: validJpg,
          publicId: 'mem_token_test',
        );

        expect(uploadResult, isNotNull);
        expect(uploadResult!.deleteToken, equals('secret_delete_token_xyz'));

        // Verify token was cached in SharedPreferences
        final cached = await CloudinaryService.getCachedDeleteToken('mem_token_test');
        expect(cached, equals('secret_delete_token_xyz'));

        // Delete asset without passing deleteToken explicitly — it must retrieve from cache!
        final deleted = await service.deleteAsset(publicId: 'mem_token_test');
        expect(deleted, isTrue);

        // Verify token was removed after deletion
        final cachedAfter = await CloudinaryService.getCachedDeleteToken('mem_token_test');
        expect(cachedAfter, isNull);
      });

      test('Batch deletion is resilient: partial failures do not abort whole batch', () async {
        SecretConfigService.setMockVariables({
          'CLOUDINARY_CLOUD_NAME': 'test_resilience_cloud',
          'CLOUDINARY_UPLOAD_PRESET': 'test_resilience_preset',
        });

        final deleted = <String>[];
        final mockClient = MockClient((request) async {
          if (request.url.toString().contains('/delete_by_token')) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final tok = body['token'] as String;
            if (tok == 'bad_token') {
              return http.Response(jsonEncode({'error': {'message': 'Invalid token'}}), 400);
            }
            deleted.add(tok);
            return http.Response(jsonEncode({'result': 'ok'}), 200);
          }
          return http.Response('Not Found', 404);
        });

        final service = CloudinaryService(httpClient: mockClient);
        final result = await service.deleteAssetsBatch(
          ['id_a', 'id_b', 'id_c'],
          deleteTokens: {
            'id_a': 'token_a',
            'id_b': 'bad_token',
            'id_c': 'token_c',
          },
        );

        expect(result['total'], equals(3));
        expect(result['succeeded'], equals(2));
        expect(result['failed'], equals(1));
        expect(deleted, containsAll(['token_a', 'token_c']));
      });
    });
  });
}
