import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';

import 'helpers/test_helpers.dart';

void main() {
  setUpTestEnvironment();

  group('SafeCacheInfoRepository', () {
    setUpAll(() async {
      await setUpTestDirectories();
    });

    tearDownAll(() async {
      await tearDownTestDirectories();
    });

    test('can be instantiated', () {
      final repo = SafeCacheInfoRepository(databaseName: 'test_db');
      expect(repo, isNotNull);
    });

    group('open', () {
      test('opens successfully with empty cache', () async {
        final dbName = 'test_db_${DateTime.now().millisecondsSinceEpoch}';
        final repo = SafeCacheInfoRepository(databaseName: dbName);

        final result = await repo.open();
        expect(result, true);
      });

      test('handles corrupted JSON file gracefully', () async {
        final dbName = 'corrupted_db_${DateTime.now().millisecondsSinceEpoch}';

        // Create a corrupted JSON file
        final corruptedFile = File('$testSupportPath/$dbName.json');
        await corruptedFile.writeAsString('{ this is not valid JSON }');

        final repo = SafeCacheInfoRepository(databaseName: dbName);

        // Should not throw - parent class handles corruption gracefully
        // by catching FormatException internally and starting fresh
        final result = await repo.open();
        expect(result, true);
      });

      test('handles empty JSON file gracefully', () async {
        final dbName = 'empty_db_${DateTime.now().millisecondsSinceEpoch}';

        // Create an empty JSON file
        final emptyFile = File('$testSupportPath/$dbName.json');
        await emptyFile.writeAsString('');

        final repo = SafeCacheInfoRepository(databaseName: dbName);

        // Should not throw - should recover from empty file
        final result = await repo.open();
        expect(result, true);
      });

      test('handles null content in JSON file', () async {
        final dbName = 'null_db_${DateTime.now().millisecondsSinceEpoch}';

        // Create a JSON file with null content
        final nullFile = File('$testSupportPath/$dbName.json');
        await nullFile.writeAsString('null');

        final repo = SafeCacheInfoRepository(databaseName: dbName);

        // Should not throw - should recover
        final result = await repo.open();
        expect(result, true);
      });

      test('handles valid JSON file', () async {
        final dbName = 'valid_db_${DateTime.now().millisecondsSinceEpoch}';

        // Create a valid JSON cache file
        final validFile = File('$testSupportPath/$dbName.json');
        await validFile.writeAsString('{}');

        final repo = SafeCacheInfoRepository(databaseName: dbName);

        final result = await repo.open();
        expect(result, true);
      });

      test('can be opened multiple times', () async {
        final dbName = 'multi_open_${DateTime.now().millisecondsSinceEpoch}';
        final repo = SafeCacheInfoRepository(databaseName: dbName);

        final result1 = await repo.open();
        final result2 = await repo.open();

        expect(result1, true);
        expect(result2, true);
      });
    });
  });
}
