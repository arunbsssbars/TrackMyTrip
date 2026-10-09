import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trackmytrip/core/services/cloudinary_service.dart';
import 'package:trackmytrip/core/services/secret_config_service.dart';

void main() {
  group('CloudinaryService Tests', () {
    setUp(() {
      SecretConfigService.reset();
    });

    tearDown(() {
      SecretConfigService.reset();
    });

    test('isConfigured is false when unconfigured or default placeholders', () {
      final service = CloudinaryService();
      expect(service.isConfigured, isFalse);

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
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

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
      final bytes = Uint8List.fromList([1, 2, 3, 4]);

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
  });
}
