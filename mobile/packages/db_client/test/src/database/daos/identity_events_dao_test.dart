// ABOUTME: Unit tests for IdentityEventsDao (NIP-39 claims source cache).
// ABOUTME: Tests upsert (insert + replace) and primary-key lookup.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late IdentityEventsDao dao;
  late String tempDbPath;

  /// Valid 64-char hex pubkey for testing
  const testPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const tagsJson = '[["i","github:alice","proof-a"]]';

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('identity_events_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.identityEventsDao;
  });

  tearDown(() async {
    await database.close();
    final dir = File(tempDbPath).parent;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group(IdentityEventsDao, () {
    group('upsertEvent', () {
      test('inserts a new row', () async {
        await dao.upsertEvent(
          pubkey: testPubkey,
          tagsJson: tagsJson,
          sourceKind: 10011,
        );

        final row = await dao.getEvent(testPubkey);
        expect(row, isNotNull);
        expect(row!.pubkey, equals(testPubkey));
        expect(row.tagsJson, equals(tagsJson));
        expect(row.sourceKind, equals(10011));
      });

      test('replaces the existing row for the same pubkey', () async {
        await dao.upsertEvent(
          pubkey: testPubkey,
          tagsJson: tagsJson,
          sourceKind: 0,
        );
        await dao.upsertEvent(
          pubkey: testPubkey,
          tagsJson: '[["i","github:alice","proof-b"]]',
          sourceKind: 10011,
        );

        final row = await dao.getEvent(testPubkey);
        expect(row!.tagsJson, equals('[["i","github:alice","proof-b"]]'));
        expect(row.sourceKind, equals(10011));
      });

      test('stores the source event coordinates when given', () async {
        await dao.upsertEvent(
          pubkey: testPubkey,
          tagsJson: tagsJson,
          sourceKind: 10011,
          sourceCreatedAt: 1700,
          sourceEventId: 'e' * 64,
        );

        final row = await dao.getEvent(testPubkey);
        expect(row!.sourceCreatedAt, equals(1700));
        expect(row.sourceEventId, equals('e' * 64));
      });

      test('clears stale coordinates when a row is replaced without '
          'them', () async {
        await dao.upsertEvent(
          pubkey: testPubkey,
          tagsJson: tagsJson,
          sourceKind: 10011,
          sourceCreatedAt: 1700,
          sourceEventId: 'e' * 64,
        );
        await dao.upsertEvent(
          pubkey: testPubkey,
          tagsJson: '[["i","github:alice","proof-b"]]',
          sourceKind: 0,
        );

        final row = await dao.getEvent(testPubkey);
        expect(row!.sourceCreatedAt, isNull);
        expect(row.sourceEventId, isNull);
      });
    });

    group('getEvent', () {
      test('returns null when no row exists', () async {
        expect(await dao.getEvent(testPubkey), isNull);
      });
    });

    group('clearAll', () {
      test('removes every identity event row', () async {
        const secondPubkey =
            '1111111111111111111111111111111111111111111111111111111111111111';
        await dao.upsertEvent(
          pubkey: testPubkey,
          tagsJson: tagsJson,
          sourceKind: 10011,
        );
        await dao.upsertEvent(
          pubkey: secondPubkey,
          tagsJson: '[["i","github:bob","proof-b"]]',
          sourceKind: 10011,
        );

        expect(await dao.clearAll(), equals(2));
        expect(await dao.getEvent(testPubkey), isNull);
        expect(await dao.getEvent(secondPubkey), isNull);
      });

      test('returns 0 when no row exists', () async {
        expect(await dao.clearAll(), equals(0));
      });
    });
  });
}
