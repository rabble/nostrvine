// ABOUTME: Data Access Object for personal repost operations.
// ABOUTME: Manages the user's own Kind 16 repost events for quick lookup
// ABOUTME: and unrepost functionality.
// ABOUTME: Provides the addressableId to repostEventId
// ABOUTME: mapping needed for NIP-09 deletion events.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'personal_reposts_dao.g.dart';

/// DAO for managing the current user's personal repost events.
///
/// This DAO handles storage and retrieval of the user's own reposts (Kind 16
/// repost events). The primary purpose is to maintain the mapping between
/// addressable IDs (videos that were reposted) and repost event IDs (the
/// Kind 16 events created when reposting).
///
/// This mapping is essential for unreposts, which require creating a Kind 5
/// deletion event that references the original repost event ID.
@DriftAccessor(tables: [PersonalReposts])
class PersonalRepostsDao extends DatabaseAccessor<AppDatabase>
    with _$PersonalRepostsDaoMixin {
  PersonalRepostsDao(super.attachedDatabase);

  /// Insert or update a personal repost record.
  ///
  /// Called when the user reposts an event. Stores the mapping so that
  /// the repost can later be deleted (unrepost).
  Future<void> upsertRepost({
    required String addressableId,
    required String repostEventId,
    required String originalAuthorPubkey,
    required String userPubkey,
    required int createdAt,
  }) async {
    await into(personalReposts).insertOnConflictUpdate(
      PersonalRepostsCompanion.insert(
        addressableId: addressableId,
        repostEventId: repostEventId,
        originalAuthorPubkey: originalAuthorPubkey,
        userPubkey: userPubkey,
        createdAt: createdAt,
      ),
    );
  }

  /// Batch insert multiple repost records in a single transaction.
  ///
  /// Used during initial sync to efficiently store all user's reposts
  /// fetched from relays.
  Future<void> upsertRepostsBatch(List<PersonalRepostRow> reposts) async {
    if (reposts.isEmpty) return;

    await batch((batch) {
      batch.insertAllOnConflictUpdate(
        personalReposts,
        reposts.map(
          (r) => PersonalRepostsCompanion.insert(
            addressableId: r.addressableId,
            repostEventId: r.repostEventId,
            originalAuthorPubkey: r.originalAuthorPubkey,
            userPubkey: r.userPubkey,
            createdAt: r.createdAt,
          ),
        ),
      );
    });
  }

  /// Delete a repost by addressable ID.
  ///
  /// Called when the user unreposts an event.
  Future<int> deleteRepost({
    required String addressableId,
    required String userPubkey,
  }) async {
    return (delete(personalReposts)..where(
          (t) =>
              t.addressableId.equals(addressableId) &
              t.userPubkey.equals(userPubkey),
        ))
        .go();
  }

  /// Delete a repost by repost event ID.
  ///
  /// Useful when processing deletion events from relays.
  Future<int> deleteByRepostEventId(String repostEventId) async {
    return (delete(
      personalReposts,
    )..where((t) => t.repostEventId.equals(repostEventId))).go();
  }

  /// Get the repost event ID for a specific addressable ID.
  ///
  /// Returns the Kind 16 event ID if the user has reposted this video,
  /// or null if not reposted.
  Future<String?> getRepostEventId({
    required String addressableId,
    required String userPubkey,
  }) async {
    final query = select(personalReposts)
      ..where(
        (t) =>
            t.addressableId.equals(addressableId) &
            t.userPubkey.equals(userPubkey),
      );

    final result = await query.getSingleOrNull();
    return result?.repostEventId;
  }

  /// Get all reposted addressable IDs for a user.
  ///
  /// Returns the set of addressable IDs that the user has reposted.
  Future<Set<String>> getRepostedAddressableIds(String userPubkey) async {
    final query = select(personalReposts)
      ..where((t) => t.userPubkey.equals(userPubkey));

    final results = await query.get();
    return results.map((r) => r.addressableId).toSet();
  }

  /// Get all repost records for a user.
  ///
  /// Returns full repost records including both addressable and
  /// repost event IDs.
  Future<List<PersonalRepostRow>> getAllReposts(String userPubkey) async {
    final query = select(personalReposts)
      ..where((t) => t.userPubkey.equals(userPubkey))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return query.get();
  }

  /// Watch all reposted addressable IDs for a user (reactive stream).
  ///
  /// Emits a new set whenever the user's reposts change.
  Stream<Set<String>> watchRepostedAddressableIds(String userPubkey) {
    final query = select(personalReposts)
      ..where((t) => t.userPubkey.equals(userPubkey));

    return query.watch().map(
      (rows) => rows.map((r) => r.addressableId).toSet(),
    );
  }

  /// Watch all repost records for a user (reactive stream).
  Stream<List<PersonalRepostRow>> watchAllReposts(String userPubkey) {
    final query = select(personalReposts)
      ..where((t) => t.userPubkey.equals(userPubkey))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return query.watch();
  }

  /// Check if an event is reposted by a user.
  Future<bool> isReposted({
    required String addressableId,
    required String userPubkey,
  }) async {
    final query = select(personalReposts)
      ..where(
        (t) =>
            t.addressableId.equals(addressableId) &
            t.userPubkey.equals(userPubkey),
      );

    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// Get the count of reposts for a user.
  Future<int> getRepostCount(String userPubkey) async {
    final countExpr = personalReposts.addressableId.count();
    final query = selectOnly(personalReposts)
      ..where(personalReposts.userPubkey.equals(userPubkey))
      ..addColumns([countExpr]);

    final result = await query.getSingle();
    return result.read(countExpr) ?? 0;
  }

  /// Delete all reposts for a user.
  ///
  /// Used when logging out or clearing user data.
  Future<int> deleteAllForUser(String userPubkey) async {
    return (delete(
      personalReposts,
    )..where((t) => t.userPubkey.equals(userPubkey))).go();
  }

  /// Delete all reposts (for testing or full reset).
  Future<int> deleteAll() async {
    return delete(personalReposts).go();
  }

  /// Get a repost record by addressable ID.
  Future<PersonalRepostRow?> getRepost({
    required String addressableId,
    required String userPubkey,
  }) async {
    final query = select(personalReposts)
      ..where(
        (t) =>
            t.addressableId.equals(addressableId) &
            t.userPubkey.equals(userPubkey),
      );

    return query.getSingleOrNull();
  }
}
