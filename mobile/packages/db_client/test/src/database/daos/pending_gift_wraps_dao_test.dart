// ABOUTME: Unit tests for PendingGiftWrapsDao — the durable failed-decrypt
// ABOUTME: gift-wrap retry queue (#5202).

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PendingGiftWrapsDao dao;
  late String tempDbPath;

  const ownerA =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const ownerB =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
  const wrap1 =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const wrap2 =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('pgw_test_');
    tempDbPath = '${tempDir.path}/test.db';
    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.pendingGiftWrapsDao;
  });

  tearDown(() async {
    await database.close();
    final file = File(tempDbPath);
    if (file.existsSync()) file.deleteSync();
  });

  group(PendingGiftWrapsDao, () {
    test('recordFailedDecrypt inserts a new row with attempts=1', () async {
      await dao.recordFailedDecrypt(
        giftWrapId: wrap1,
        ownerPubkey: ownerA,
        rawJson: '{"id":"x"}',
        createdAt: 100,
      );

      final rows = await dao.getRetryable(ownerPubkey: ownerA, maxAttempts: 10);
      expect(rows, hasLength(1));
      expect(rows.single.giftWrapId, wrap1);
      expect(rows.single.attempts, 1);
      expect(rows.single.rawJson, '{"id":"x"}');
      expect(rows.single.createdAt, 100);
    });

    test(
      'recordFailedDecrypt increments attempts on repeat and keeps the '
      'original raw payload',
      () async {
        await dao.recordFailedDecrypt(
          giftWrapId: wrap1,
          ownerPubkey: ownerA,
          rawJson: 'first',
          createdAt: 100,
        );
        await dao.recordFailedDecrypt(
          giftWrapId: wrap1,
          ownerPubkey: ownerA,
          rawJson: 'second',
          createdAt: 999,
        );

        final rows = await dao.getRetryable(
          ownerPubkey: ownerA,
          maxAttempts: 10,
        );
        expect(rows, hasLength(1));
        expect(rows.single.attempts, 2);
        // First insert wins — the raw bytes never change for a given wrap.
        expect(rows.single.rawJson, 'first');
        expect(rows.single.createdAt, 100);
      },
    );

    test('getRetryable excludes rows at or over the attempt cap', () async {
      for (var i = 0; i < 3; i++) {
        await dao.recordFailedDecrypt(
          giftWrapId: wrap1,
          ownerPubkey: ownerA,
          rawJson: 'r',
          createdAt: 100,
        );
      }

      expect(
        await dao.getRetryable(ownerPubkey: ownerA, maxAttempts: 3),
        isEmpty,
      );
      expect(
        await dao.getRetryable(ownerPubkey: ownerA, maxAttempts: 4),
        hasLength(1),
      );
    });

    test('getRetryable scopes by owner and orders newest-first', () async {
      await dao.recordFailedDecrypt(
        giftWrapId: wrap1,
        ownerPubkey: ownerA,
        rawJson: 'r',
        createdAt: 100,
      );
      await dao.recordFailedDecrypt(
        giftWrapId: wrap2,
        ownerPubkey: ownerA,
        rawJson: 'r',
        createdAt: 300,
      );
      await dao.recordFailedDecrypt(
        giftWrapId: wrap1,
        ownerPubkey: ownerB,
        rawJson: 'r',
        createdAt: 200,
      );

      final rows = await dao.getRetryable(ownerPubkey: ownerA, maxAttempts: 10);
      expect(rows.map((r) => r.giftWrapId).toList(), [wrap2, wrap1]);
      expect(await dao.countForOwner(ownerB), 1);
    });

    test('deletePending removes the row and is a no-op when absent', () async {
      await dao.recordFailedDecrypt(
        giftWrapId: wrap1,
        ownerPubkey: ownerA,
        rawJson: 'r',
        createdAt: 100,
      );

      await dao.deletePending(giftWrapId: wrap1, ownerPubkey: ownerA);
      expect(await dao.countForOwner(ownerA), 0);

      // Absent row — must not throw.
      await dao.deletePending(giftWrapId: wrap2, ownerPubkey: ownerA);
      expect(await dao.countForOwner(ownerA), 0);
    });

    test(
      'the same gift-wrap id under different owners is independent',
      () async {
        await dao.recordFailedDecrypt(
          giftWrapId: wrap1,
          ownerPubkey: ownerA,
          rawJson: 'r',
          createdAt: 100,
        );
        await dao.recordFailedDecrypt(
          giftWrapId: wrap1,
          ownerPubkey: ownerB,
          rawJson: 'r',
          createdAt: 100,
        );

        await dao.deletePending(giftWrapId: wrap1, ownerPubkey: ownerA);

        expect(await dao.countForOwner(ownerA), 0);
        expect(await dao.countForOwner(ownerB), 1);
      },
    );

    test('deleteExhausted removes only rows at or above the cap', () async {
      // wrap1: 3 attempts; wrap2: 1 attempt.
      for (var i = 0; i < 3; i++) {
        await dao.recordFailedDecrypt(
          giftWrapId: wrap1,
          ownerPubkey: ownerA,
          rawJson: 'r',
          createdAt: 100,
        );
      }
      await dao.recordFailedDecrypt(
        giftWrapId: wrap2,
        ownerPubkey: ownerA,
        rawJson: 'r',
        createdAt: 200,
      );

      final deleted = await dao.deleteExhausted(
        ownerPubkey: ownerA,
        maxAttempts: 3,
      );

      expect(deleted, 1);
      final remaining = await dao.getRetryable(
        ownerPubkey: ownerA,
        maxAttempts: 999,
      );
      expect(remaining.map((r) => r.giftWrapId).toList(), [wrap2]);
    });

    test('deleteExhausted is owner-scoped', () async {
      for (var i = 0; i < 3; i++) {
        await dao.recordFailedDecrypt(
          giftWrapId: wrap1,
          ownerPubkey: ownerA,
          rawJson: 'r',
          createdAt: 100,
        );
        await dao.recordFailedDecrypt(
          giftWrapId: wrap1,
          ownerPubkey: ownerB,
          rawJson: 'r',
          createdAt: 100,
        );
      }

      await dao.deleteExhausted(ownerPubkey: ownerA, maxAttempts: 3);

      expect(await dao.countForOwner(ownerA), 0);
      expect(await dao.countForOwner(ownerB), 1);
    });

    test('clearAll removes every row across all owners', () async {
      await dao.recordFailedDecrypt(
        giftWrapId: wrap1,
        ownerPubkey: ownerA,
        rawJson: 'r',
        createdAt: 100,
      );
      await dao.recordFailedDecrypt(
        giftWrapId: wrap2,
        ownerPubkey: ownerB,
        rawJson: 'r',
        createdAt: 100,
      );

      final deleted = await dao.clearAll();

      expect(deleted, 2);
      expect(await dao.countForOwner(ownerA), 0);
      expect(await dao.countForOwner(ownerB), 0);
    });
  });
}
