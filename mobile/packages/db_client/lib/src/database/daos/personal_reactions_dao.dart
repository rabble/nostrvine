// ABOUTME: Data Access Object for personal reaction (like) operations.
// ABOUTME: Manages the user's own Kind 7 reaction events for quick lookup
// ABOUTME: and unlike functionality.
// ABOUTME: Provides the targetEventId to reactionEventId
// ABOUTME: mapping needed for NIP-09 deletion events.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'personal_reactions_dao.g.dart';

/// DAO for managing the current user's personal reaction events.
///
/// This DAO handles storage and retrieval of the user's own likes (Kind 7
/// reaction events). The primary purpose is to maintain the mapping between
/// target event IDs (videos that were liked) and reaction event IDs (the
/// Kind 7 events created when liking).
///
/// This mapping is essential for unlikes, which require creating a Kind 5
/// deletion event that references the original reaction event ID.
@DriftAccessor(tables: [PersonalReactions])
class PersonalReactionsDao extends DatabaseAccessor<AppDatabase>
    with _$PersonalReactionsDaoMixin {
  PersonalReactionsDao(super.attachedDatabase);

  /// Insert or update a personal reaction record.
  ///
  /// Called when the user likes an event. Stores the mapping so that
  /// the reaction can later be deleted (unlike).
  Future<void> upsertReaction({
    required String targetEventId,
    required String reactionEventId,
    required String userPubkey,
    required int createdAt,
  }) async {
    await into(personalReactions).insertOnConflictUpdate(
      PersonalReactionsCompanion.insert(
        targetEventId: targetEventId,
        reactionEventId: reactionEventId,
        userPubkey: userPubkey,
        createdAt: createdAt,
      ),
    );
  }

  /// Batch insert multiple reaction records in a single transaction.
  ///
  /// Used during initial sync to efficiently store all user's reactions
  /// fetched from relays.
  Future<void> upsertReactionsBatch(List<PersonalReactionRow> reactions) async {
    if (reactions.isEmpty) return;

    await batch((batch) {
      batch.insertAllOnConflictUpdate(
        personalReactions,
        reactions.map(
          (r) => PersonalReactionsCompanion.insert(
            targetEventId: r.targetEventId,
            reactionEventId: r.reactionEventId,
            userPubkey: r.userPubkey,
            createdAt: r.createdAt,
          ),
        ),
      );
    });
  }

  /// Delete a reaction by target event ID.
  ///
  /// Called when the user unlikes an event.
  Future<int> deleteReaction({
    required String targetEventId,
    required String userPubkey,
  }) async {
    return (delete(personalReactions)..where(
          (t) =>
              t.targetEventId.equals(targetEventId) &
              t.userPubkey.equals(userPubkey),
        ))
        .go();
  }

  /// Delete a reaction by reaction event ID.
  ///
  /// Useful when processing deletion events from relays.
  Future<int> deleteByReactionEventId(String reactionEventId) async {
    return (delete(
      personalReactions,
    )..where((t) => t.reactionEventId.equals(reactionEventId))).go();
  }

  /// Get the reaction event ID for a specific target event.
  ///
  /// Returns the Kind 7 event ID if the user has liked this event,
  /// or null if not liked.
  Future<String?> getReactionEventId({
    required String targetEventId,
    required String userPubkey,
  }) async {
    final query = select(personalReactions)
      ..where(
        (t) =>
            t.targetEventId.equals(targetEventId) &
            t.userPubkey.equals(userPubkey),
      );

    final result = await query.getSingleOrNull();
    return result?.reactionEventId;
  }

  /// Get all liked event IDs for a user.
  ///
  /// Returns the set of target event IDs that the user has liked.
  Future<Set<String>> getLikedEventIds(String userPubkey) async {
    final query = select(personalReactions)
      ..where((t) => t.userPubkey.equals(userPubkey));

    final results = await query.get();
    return results.map((r) => r.targetEventId).toSet();
  }

  /// Get all reaction records for a user.
  ///
  /// Returns full reaction records including both target and
  /// reaction event IDs.
  Future<List<PersonalReactionRow>> getAllReactions(String userPubkey) async {
    final query = select(personalReactions)
      ..where((t) => t.userPubkey.equals(userPubkey))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return query.get();
  }

  /// Watch all liked event IDs for a user (reactive stream).
  ///
  /// Emits a new set whenever the user's likes change.
  Stream<Set<String>> watchLikedEventIds(String userPubkey) {
    final query = select(personalReactions)
      ..where((t) => t.userPubkey.equals(userPubkey));

    return query.watch().map(
      (rows) => rows.map((r) => r.targetEventId).toSet(),
    );
  }

  /// Watch all reaction records for a user (reactive stream).
  Stream<List<PersonalReactionRow>> watchAllReactions(String userPubkey) {
    final query = select(personalReactions)
      ..where((t) => t.userPubkey.equals(userPubkey))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return query.watch();
  }

  /// Check if an event is liked by a user.
  Future<bool> isLiked({
    required String targetEventId,
    required String userPubkey,
  }) async {
    final query = select(personalReactions)
      ..where(
        (t) =>
            t.targetEventId.equals(targetEventId) &
            t.userPubkey.equals(userPubkey),
      );

    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// Get the count of likes for a user.
  Future<int> getLikeCount(String userPubkey) async {
    final countExpr = personalReactions.targetEventId.count();
    final query = selectOnly(personalReactions)
      ..where(personalReactions.userPubkey.equals(userPubkey))
      ..addColumns([countExpr]);

    final result = await query.getSingle();
    return result.read(countExpr) ?? 0;
  }

  /// Delete all reactions for a user.
  ///
  /// Used when logging out or clearing user data.
  Future<int> deleteAllForUser(String userPubkey) async {
    return (delete(
      personalReactions,
    )..where((t) => t.userPubkey.equals(userPubkey))).go();
  }

  /// Delete all reactions (for testing or full reset).
  Future<int> deleteAll() async {
    return delete(personalReactions).go();
  }

  /// Get a reaction record by target event ID.
  Future<PersonalReactionRow?> getReaction({
    required String targetEventId,
    required String userPubkey,
  }) async {
    final query = select(personalReactions)
      ..where(
        (t) =>
            t.targetEventId.equals(targetEventId) &
            t.userPubkey.equals(userPubkey),
      );

    return query.getSingleOrNull();
  }
}
