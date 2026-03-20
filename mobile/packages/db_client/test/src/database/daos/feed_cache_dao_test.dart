// ABOUTME: Unit tests for FeedCacheDao response body caching operations.
// ABOUTME: Tests save, get, overwrite, clear, and clearAll behavior.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late FeedCacheDao dao;
  late String tempDbPath;

  const testBody = '{"videos":[{"id":"abc","pubkey":"def"}]}';
  const testBody2 = '[{"id":"xyz","pubkey":"123"}]';

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('feed_cache_dao_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.feedCacheDao;
  });

  tearDown(() async {
    await database.close();
    final file = File(tempDbPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    final dir = Directory(tempDbPath).parent;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group(FeedCacheDao, () {
    group('saveResponseBody', () {
      test('inserts a response body for a feed key', () async {
        await dao.saveResponseBody('home', testBody);

        final result = await dao.getResponseBody('home');
        expect(result, equals(testBody));
      });

      test('replaces existing response for same feed key', () async {
        await dao.saveResponseBody('home', testBody);
        await dao.saveResponseBody('home', testBody2);

        final result = await dao.getResponseBody('home');
        expect(result, equals(testBody2));
      });

      test('does not affect other feed keys', () async {
        await dao.saveResponseBody('home', testBody);
        await dao.saveResponseBody('latest', testBody2);

        expect(await dao.getResponseBody('home'), equals(testBody));
        expect(await dao.getResponseBody('latest'), equals(testBody2));
      });
    });

    group('getResponseBody', () {
      test('returns null for unknown feed key', () async {
        final result = await dao.getResponseBody('nonexistent');
        expect(result, isNull);
      });
    });

    group('clearResponseBody', () {
      test('removes the entry for a feed key', () async {
        await dao.saveResponseBody('home', testBody);
        await dao.clearResponseBody('home');

        expect(await dao.getResponseBody('home'), isNull);
      });

      test('does not affect other feed keys', () async {
        await dao.saveResponseBody('home', testBody);
        await dao.saveResponseBody('popular', testBody2);

        await dao.clearResponseBody('home');

        expect(await dao.getResponseBody('home'), isNull);
        expect(await dao.getResponseBody('popular'), equals(testBody2));
      });
    });

    group('clearAll', () {
      test('removes all cached entries', () async {
        await dao.saveResponseBody('home', testBody);
        await dao.saveResponseBody('latest', testBody2);
        await dao.saveResponseBody('popular', testBody);

        await dao.clearAll();

        expect(await dao.getResponseBody('home'), isNull);
        expect(await dao.getResponseBody('latest'), isNull);
        expect(await dao.getResponseBody('popular'), isNull);
      });
    });
  });
}
