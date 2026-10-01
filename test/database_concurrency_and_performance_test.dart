import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackmytrip/core/database/app_database.dart';
import 'package:trackmytrip/core/services/image_compression_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Database Concurrency & Performance Tests (WAL Mode & Indexing)', () {
    late Directory tempDir;
    late AppDatabase db;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tmt_db_wal_test_');
      final dbPath = '${tempDir.path}/test_wal.db';
      db = await AppDatabase.open(customPath: dbPath);
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Composite indexes are created without error', () async {
      // Verify querying sqlite_master contains the composite index
      final result = await db.database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_expenses_trip_created';",
      );
      expect(result.isNotEmpty, isTrue);
    });

    test('Concurrent reads and writes do not lock the database', () async {
      // Launch 10 concurrent async operations
      final futures = <Future>[];

      for (int i = 0; i < 5; i++) {
        futures.add(db.database.insert(
          'tombstoned_trips',
          {'tripId': 'concurrent_trip_$i', 'deletedAt': DateTime.now().millisecondsSinceEpoch},
        ));
      }

      for (int i = 0; i < 5; i++) {
        futures.add(db.database.query('tombstoned_trips'));
      }

      await Future.wait(futures);

      final count = await db.database.query('tombstoned_trips');
      expect(count.length, equals(5));
    });
  });

  group('Image Compression & Thumbnail Pipeline Tests', () {
    test('createThumbnail generates valid downscaled thumbnail file', () async {
      final tempDir = await Directory.systemTemp.createTemp('tmt_thumb_test_');
      final sourceFile = File('${tempDir.path}/photo.jpg');
      await sourceFile.writeAsBytes(List.filled(2048, 1)); // 2 KB sample file

      final thumb = await ImageCompressionService.createThumbnail(sourceFile, size: 250);
      expect(thumb, isNotNull);
      expect(await thumb!.exists(), isTrue);
      expect(thumb.path, contains('_thumb.jpg'));

      await tempDir.delete(recursive: true);
    });
  });
}
