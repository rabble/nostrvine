// ABOUTME: Unit tests for DmReactionsDao.
// ABOUTME: Covers optimistic writes, retry state transitions, soft delete,
// ABOUTME: wrapped receive dedup, and owner-scoped query behaviour.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _ownerA =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _ownerB =
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
const String _reactorA = _ownerA;
const _reactorB =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _conversationId =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _targetMessageId =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _targetAuthor =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _pendingId =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const _sentId =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
const _giftWrapId =
    '1111111111111111111111111111111111111111111111111111111111111111';

void main() {
  late AppDatabase database;
  late DmReactionsDao dao;
  late String tempDbPath;

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('dm_reactions_dao_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.dmReactionsDao;
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

  group('DmReactionsDao', () {
    Future<List<String>> insertPending({
      String id = _pendingId,
      String ownerPubkey = _ownerA,
      String reactorPubkey = _reactorA,
      String emoji = '🔥',
      int createdAt = 1_700_000_000,
    }) {
      return dao.insertOwnReactionSuperseding(
        placeholderId: id,
        conversationId: _conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _targetAuthor,
        reactorPubkey: reactorPubkey,
        emoji: emoji,
        createdAt: createdAt,
        ownerPubkey: ownerPubkey,
        rumorEventJson: '{"id":"$id"}',
      );
    }

    test(
      'insertOwnReactionSuperseding stores pending state and rumor json',
      () async {
        final superseded = await insertPending();
        expect(superseded, isEmpty);

        final row = await dao.getById(id: _pendingId, ownerPubkey: _ownerA);
        expect(row, isNotNull);
        expect(row!.publishStatus, equals('pending'));
        expect(row.rumorEventJson, contains(_pendingId));
        expect(row.giftWrapId, isNull);
      },
    );

    test(
      'insertOwnReactionSuperseding soft-deletes the prior live own reaction '
      'and returns its id',
      () async {
        await insertPending();
        final superseded = await insertPending(
          id: _sentId,
          emoji: '😂',
          createdAt: 1_700_000_010,
        );

        expect(superseded, equals([_pendingId]));
        expect(
          (await dao.getById(id: _pendingId, ownerPubkey: _ownerA))!.isDeleted,
          isTrue,
        );
        final live = await dao
            .watchForConversation(
              conversationId: _conversationId,
              ownerPubkey: _ownerA,
            )
            .first;
        expect(live.map((r) => r.emoji), equals(['😂']));
      },
    );

    test(
      'partial unique index rejects a second live reaction for the same '
      '(target, reactor, owner) tuple',
      () async {
        await insertPending();

        Future<void> insertDuplicateLive() {
          return database
              .into(database.dmMessageReactions)
              .insert(
                DmMessageReactionsCompanion.insert(
                  id: _sentId,
                  conversationId: _conversationId,
                  targetMessageId: _targetMessageId,
                  targetMessageAuthor: _targetAuthor,
                  reactorPubkey: _reactorA,
                  emoji: '😂',
                  createdAt: 1_700_000_010,
                  ownerPubkey: _ownerA,
                ),
              );
        }

        await expectLater(insertDuplicateLive(), throwsA(isA<Exception>()));
      },
    );

    test(
      'partial unique index allows unlimited deleted rows for one tuple',
      () async {
        Future<void> insertDeleted(String id) {
          return database
              .into(database.dmMessageReactions)
              .insert(
                DmMessageReactionsCompanion.insert(
                  id: id,
                  conversationId: _conversationId,
                  targetMessageId: _targetMessageId,
                  targetMessageAuthor: _targetAuthor,
                  reactorPubkey: _reactorA,
                  emoji: '🔥',
                  createdAt: 1_700_000_000,
                  ownerPubkey: _ownerA,
                  isDeleted: const Value(true),
                ),
              );
        }

        await insertPending(); // one live
        await insertDeleted(_sentId); // deleted dup — allowed
        await insertDeleted(
          '4444444444444444444444444444444444444444444444444444444444444444',
        );

        final live = await dao
            .watchForConversation(
              conversationId: _conversationId,
              ownerPubkey: _ownerA,
            )
            .first;
        expect(live, hasLength(1));
      },
    );

    test(
      'insertOwnReactionSuperseding resurrects a soft-deleted same-id row so '
      'a same-second re-react is not silently dropped',
      () async {
        // React, remove (soft-delete), then re-react the same emoji within the
        // same wall-clock second: the rebuilt rumor id is identical, so the
        // insert collides with the just-deleted row's primary key.
        await insertPending();
        await dao.softDelete(id: _pendingId, ownerPubkey: _ownerA);
        expect(
          (await dao.getById(id: _pendingId, ownerPubkey: _ownerA))!.isDeleted,
          isTrue,
        );

        final superseded = await insertPending();

        expect(superseded, isEmpty);
        final row = await dao.getById(id: _pendingId, ownerPubkey: _ownerA);
        expect(row, isNotNull);
        expect(row!.isDeleted, isFalse);
        expect(row.publishStatus, equals('pending'));
        expect(row.rumorEventJson, contains(_pendingId));

        final live = await dao
            .watchForConversation(
              conversationId: _conversationId,
              ownerPubkey: _ownerA,
            )
            .first;
        expect(live.map((r) => r.emoji), equals(['🔥']));
      },
    );

    test(
      'insertOwnReactionSuperseding leaves a still-live same-id row untouched '
      'so an idempotent double-tap keeps its publish status',
      () async {
        await insertPending();
        await dao.swapPlaceholderId(
          placeholderId: _pendingId,
          realRumorId: _pendingId,
          ownerPubkey: _ownerA,
        );
        expect(
          (await dao.getById(
            id: _pendingId,
            ownerPubkey: _ownerA,
          ))!.publishStatus,
          equals('sent'),
        );

        final superseded = await insertPending();

        expect(superseded, isEmpty);
        // Resurrect is scoped to deleted rows, so the live 'sent' row is not
        // regressed to 'pending' and its cleared rumor json stays cleared.
        final row = await dao.getById(id: _pendingId, ownerPubkey: _ownerA);
        expect(row!.isDeleted, isFalse);
        expect(row.publishStatus, equals('sent'));
        expect(row.rumorEventJson, isNull);
      },
    );

    test(
      'insertOwnReactionSuperseding resurrects a deleted same-id row while a '
      'different-id live sibling exists, staying capped at one live row',
      () async {
        // Deleted same-id row (🔥) coexisting with a live different-id row
        // (😂): re-reacting 🔥 must supersede the sibling BEFORE resurrecting,
        // or the partial unique index would reject two live rows for the tuple.
        await insertPending();
        await dao.softDelete(id: _pendingId, ownerPubkey: _ownerA);
        await insertPending(
          id: _sentId,
          emoji: '😂',
          createdAt: 1_700_000_010,
        );

        final superseded = await insertPending();

        expect(superseded, equals([_sentId]));
        expect(
          (await dao.getById(id: _pendingId, ownerPubkey: _ownerA))!.isDeleted,
          isFalse,
        );
        expect(
          (await dao.getById(id: _sentId, ownerPubkey: _ownerA))!.isDeleted,
          isTrue,
        );
        final live = await dao
            .watchForConversation(
              conversationId: _conversationId,
              ownerPubkey: _ownerA,
            )
            .first;
        expect(live.map((r) => r.emoji), equals(['🔥']));
      },
    );

    test('swapPlaceholderId marks row sent and clears stored rumor', () async {
      await insertPending();

      await dao.swapPlaceholderId(
        placeholderId: _pendingId,
        realRumorId: _sentId,
        ownerPubkey: _ownerA,
        giftWrapId: _giftWrapId,
      );

      expect(await dao.getById(id: _pendingId, ownerPubkey: _ownerA), isNull);
      final row = await dao.getById(id: _sentId, ownerPubkey: _ownerA);
      expect(row, isNotNull);
      expect(row!.publishStatus, equals('sent'));
      expect(row.rumorEventJson, isNull);
      expect(row.giftWrapId, equals(_giftWrapId));
    });

    test('markFailed and markPending transition publish status', () async {
      await insertPending();

      await dao.markFailed(placeholderId: _pendingId, ownerPubkey: _ownerA);
      expect(
        (await dao.getById(
          id: _pendingId,
          ownerPubkey: _ownerA,
        ))!.publishStatus,
        equals('failed'),
      );

      await dao.markPending(id: _pendingId, ownerPubkey: _ownerA);
      expect(
        (await dao.getById(
          id: _pendingId,
          ownerPubkey: _ownerA,
        ))!.publishStatus,
        equals('pending'),
      );
    });

    test(
      'softDelete hides row from live queries but preserves record',
      () async {
        await insertPending(id: _sentId);

        final before = await dao
            .watchForConversation(
              conversationId: _conversationId,
              ownerPubkey: _ownerA,
            )
            .first;
        expect(before, hasLength(1));

        await dao.softDelete(id: _sentId, ownerPubkey: _ownerA);

        final row = await dao.getById(id: _sentId, ownerPubkey: _ownerA);
        expect(row!.isDeleted, isTrue);
        final after = await dao
            .watchForConversation(
              conversationId: _conversationId,
              ownerPubkey: _ownerA,
            )
            .first;
        expect(after, isEmpty);
      },
    );

    test('deleteById removes failed rows entirely', () async {
      await insertPending();

      final deleted = await dao.deleteById(
        id: _pendingId,
        ownerPubkey: _ownerA,
      );

      expect(deleted, equals(1));
      expect(await dao.getById(id: _pendingId, ownerPubkey: _ownerA), isNull);
    });

    test('upsertIncoming deduplicates by id and owner pubkey', () async {
      await dao.upsertIncoming(
        id: _sentId,
        conversationId: _conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _targetAuthor,
        reactorPubkey: _reactorB,
        emoji: '😂',
        createdAt: 1_700_000_000,
        giftWrapId: _giftWrapId,
        ownerPubkey: _ownerA,
      );
      await dao.upsertIncoming(
        id: _sentId,
        conversationId: _conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _targetAuthor,
        reactorPubkey: _reactorB,
        emoji: '😂',
        createdAt: 1_700_000_001,
        giftWrapId:
            '2222222222222222222222222222222222222222222222222222222222222222',
        ownerPubkey: _ownerA,
      );

      final rows = await dao
          .watchForConversation(
            conversationId: _conversationId,
            ownerPubkey: _ownerA,
          )
          .first;
      expect(rows, hasLength(1));
      expect(rows.single.id, equals(_sentId));
    });

    Future<void> upsertIncoming({
      required String id,
      required int createdAt,
      String reactorPubkey = _reactorB,
      String emoji = '😂',
      String giftWrapId = _giftWrapId,
    }) {
      return dao.upsertIncoming(
        id: id,
        conversationId: _conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _targetAuthor,
        reactorPubkey: reactorPubkey,
        emoji: emoji,
        createdAt: createdAt,
        giftWrapId: giftWrapId,
        ownerPubkey: _ownerA,
      );
    }

    test(
      'upsertIncoming with a newer rumor id supersedes the older live reaction',
      () async {
        await upsertIncoming(
          id: _sentId,
          createdAt: 1_700_000_000,
          emoji: '🔥',
        );
        await upsertIncoming(id: _pendingId, createdAt: 1_700_000_010);

        expect(
          (await dao.getById(id: _sentId, ownerPubkey: _ownerA))!.isDeleted,
          isTrue,
        );
        final live = await dao
            .watchForConversation(
              conversationId: _conversationId,
              ownerPubkey: _ownerA,
            )
            .first;
        expect(live.map((r) => r.id), equals([_pendingId]));
        expect(live.single.emoji, equals('😂'));
      },
    );

    test(
      'upsertIncoming with an older rumor id is recorded as already-deleted',
      () async {
        await upsertIncoming(id: _sentId, createdAt: 1_700_000_010);
        await upsertIncoming(
          id: _pendingId,
          createdAt: 1_700_000_000,
          emoji: '🔥',
        );

        // Older reaction is recorded (history + gift-wrap dedup) but deleted.
        final older = await dao.getById(id: _pendingId, ownerPubkey: _ownerA);
        expect(older, isNotNull);
        expect(older!.isDeleted, isTrue);
        final live = await dao
            .watchForConversation(
              conversationId: _conversationId,
              ownerPubkey: _ownerA,
            )
            .first;
        expect(live.map((r) => r.id), equals([_sentId]));
      },
    );

    test(
      'upsertIncoming re-arrival of a deleted reaction does not resurrect it',
      () async {
        await upsertIncoming(id: _sentId, createdAt: 1_700_000_000);
        await dao.softDelete(id: _sentId, ownerPubkey: _ownerA);

        // Self-wrap / relay replay of the same rumor id arrives again.
        await upsertIncoming(id: _sentId, createdAt: 1_700_000_000);

        expect(
          (await dao.getById(id: _sentId, ownerPubkey: _ownerA))!.isDeleted,
          isTrue,
        );
      },
    );

    test('watchForConversation only returns live rows for one owner', () async {
      await insertPending();
      await insertPending(id: _sentId, ownerPubkey: _ownerB, emoji: '😂');
      await dao.softDelete(id: _pendingId, ownerPubkey: _ownerA);
      await dao.upsertIncoming(
        id: '3333333333333333333333333333333333333333333333333333333333333333',
        conversationId: _conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _targetAuthor,
        reactorPubkey: _reactorB,
        emoji: '😮',
        createdAt: 1_700_000_002,
        giftWrapId: _giftWrapId,
        ownerPubkey: _ownerA,
      );

      final rowsA = await dao
          .watchForConversation(
            conversationId: _conversationId,
            ownerPubkey: _ownerA,
          )
          .first;
      final rowsB = await dao
          .watchForConversation(
            conversationId: _conversationId,
            ownerPubkey: _ownerB,
          )
          .first;

      expect(rowsA.map((row) => row.emoji), equals(['😮']));
      expect(rowsB.map((row) => row.emoji), equals(['😂']));
    });

    test('getRumorJson and hasGiftWrap are owner scoped', () async {
      await insertPending();
      await dao.upsertIncoming(
        id: _sentId,
        conversationId: _conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _targetAuthor,
        reactorPubkey: _reactorB,
        emoji: '😂',
        createdAt: 1_700_000_001,
        giftWrapId: _giftWrapId,
        ownerPubkey: _ownerA,
      );

      expect(
        await dao.getRumorJson(id: _pendingId, ownerPubkey: _ownerA),
        contains(_pendingId),
      );
      expect(
        await dao.getRumorJson(id: _pendingId, ownerPubkey: _ownerB),
        isNull,
      );
      expect(
        await dao.hasGiftWrap(giftWrapId: _giftWrapId, ownerPubkey: _ownerA),
        isTrue,
      );
      expect(
        await dao.hasGiftWrap(giftWrapId: _giftWrapId, ownerPubkey: _ownerB),
        isFalse,
      );
    });

    test('deleteAllForOwner clears only the targeted account', () async {
      await insertPending();
      await insertPending(id: _sentId, ownerPubkey: _ownerB);

      final deleted = await dao.deleteAllForOwner(_ownerA);

      expect(deleted, equals(1));
      expect(await dao.getById(id: _pendingId, ownerPubkey: _ownerA), isNull);
      expect(await dao.getById(id: _sentId, ownerPubkey: _ownerB), isNotNull);
    });
  });
}
