// ABOUTME: Data access for owner-scoped removed-conversation tombstones.
// ABOUTME: Prevents replayed relay history from resurrecting removed DMs.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'removed_conversations_dao.g.dart';

@DriftAccessor(tables: [RemovedConversations])
class RemovedConversationsDao extends DatabaseAccessor<AppDatabase>
    with _$RemovedConversationsDaoMixin {
  RemovedConversationsDao(super.attachedDatabase);

  Future<void> record({
    required String conversationId,
    required String ownerPubkey,
    required int removedAt,
  }) {
    return into(removedConversations).insertOnConflictUpdate(
      RemovedConversationsCompanion.insert(
        conversationId: conversationId,
        ownerPubkey: ownerPubkey,
        removedAt: removedAt,
      ),
    );
  }

  Future<void> recordAll({
    required Iterable<String> conversationIds,
    required String ownerPubkey,
    required int removedAt,
  }) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(
        removedConversations,
        [
          for (final conversationId in conversationIds)
            RemovedConversationsCompanion.insert(
              conversationId: conversationId,
              ownerPubkey: ownerPubkey,
              removedAt: removedAt,
            ),
        ],
      );
    });
  }

  Future<int?> removedAtFor({
    required String conversationId,
    required String ownerPubkey,
  }) async {
    final row =
        await (select(removedConversations)..where(
              (t) =>
                  t.conversationId.equals(conversationId) &
                  t.ownerPubkey.equals(ownerPubkey),
            ))
            .getSingleOrNull();
    return row?.removedAt;
  }

  Future<int> clearFor({
    required String conversationId,
    required String ownerPubkey,
  }) {
    return (delete(removedConversations)..where(
          (t) =>
              t.conversationId.equals(conversationId) &
              t.ownerPubkey.equals(ownerPubkey),
        ))
        .go();
  }

  Future<int> clearAllForUser(String ownerPubkey) {
    return (delete(
      removedConversations,
    )..where((t) => t.ownerPubkey.equals(ownerPubkey))).go();
  }
}
