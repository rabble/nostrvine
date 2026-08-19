// ABOUTME: Tests durable, owner-scoped removed-conversation tombstones.
// ABOUTME: Tombstones prevent replayed DM history from restoring removed chats.

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const conversationA =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const conversationB =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const ownerA =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const ownerB =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

  late AppDatabase database;
  late RemovedConversationsDao dao;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
    dao = database.removedConversationsDao;
  });

  tearDown(() => database.close());

  group(RemovedConversationsDao, () {
    test('records and replaces an owner-scoped removal timestamp', () async {
      await dao.record(
        conversationId: conversationA,
        ownerPubkey: ownerA,
        removedAt: 100,
      );
      await dao.record(
        conversationId: conversationA,
        ownerPubkey: ownerA,
        removedAt: 200,
      );

      expect(
        await dao.removedAtFor(
          conversationId: conversationA,
          ownerPubkey: ownerA,
        ),
        200,
      );
      expect(
        await dao.removedAtFor(
          conversationId: conversationA,
          ownerPubkey: ownerB,
        ),
        isNull,
      );
    });

    test('recordAll and clearAllForUser preserve other owners', () async {
      await dao.recordAll(
        conversationIds: [conversationA, conversationB],
        ownerPubkey: ownerA,
        removedAt: 300,
      );
      await dao.record(
        conversationId: conversationA,
        ownerPubkey: ownerB,
        removedAt: 400,
      );

      expect(await dao.clearAllForUser(ownerA), 2);
      expect(
        await dao.removedAtFor(
          conversationId: conversationA,
          ownerPubkey: ownerB,
        ),
        400,
      );
    });

    test('transaction rollback does not leave a tombstone', () async {
      await expectLater(
        database.transaction(() async {
          await dao.record(
            conversationId: conversationA,
            ownerPubkey: ownerA,
            removedAt: 500,
          );
          throw StateError('rollback');
        }),
        throwsStateError,
      );

      expect(
        await dao.removedAtFor(
          conversationId: conversationA,
          ownerPubkey: ownerA,
        ),
        isNull,
      );
    });
  });
}
