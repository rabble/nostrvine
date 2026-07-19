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
      test('inserts a new row with the fetch timestamp', () async {
        final before = DateTime.now().subtract(const Duration(seconds: 1));
        await dao.upsertEvent(
          pubkey: testPubkey,
          tagsJson: tagsJson,
          sourceKind: 10011,
          eventCreatedAt: 1784396891,
        );

        final row = await dao.getEvent(testPubkey);
        expect(row, isNotNull);
        expect(row!.pubkey, equals(testPubkey));
        expect(row.tagsJson, equals(tagsJson));
        expect(row.sourceKind, equals(10011));
        expect(row.eventCreatedAt, equals(1784396891));
        expect(row.fetchedAt.isAfter(before), isTrue);
      });

      test('replaces the existing row for the same pubkey', () async {
        await dao.upsertEvent(
          pubkey: testPubkey,
          tagsJson: tagsJson,
          sourceKind: 0,
          eventCreatedAt: 100,
        );
        await dao.upsertEvent(
          pubkey: testPubkey,
          tagsJson: '[["i","github:alice","proof-b"]]',
          sourceKind: 10011,
          eventCreatedAt: 200,
        );

        final row = await dao.getEvent(testPubkey);
        expect(row!.tagsJson, equals('[["i","github:alice","proof-b"]]'));
        expect(row.sourceKind, equals(10011));
        expect(row.eventCreatedAt, equals(200));
      });
    });

    group('getEvent', () {
      test('returns null when no row exists', () async {
        expect(await dao.getEvent(testPubkey), isNull);
      });
    });
  });
}
