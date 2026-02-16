// ABOUTME: db_client implementation of LikesLocalStorage.
// ABOUTME: Uses PersonalReactionsDao for persistent storage of like records.

import 'package:db_client/db_client.dart';
import 'package:likes_repository/src/likes_local_storage.dart';
import 'package:likes_repository/src/models/like_record.dart';

/// Implementation of `LikesLocalStorage` using db_client's
/// `PersonalReactionsDao`.
///
/// This implementation persists like records to the local SQLite database,
/// providing durability across app restarts.
class DbLikesLocalStorage implements LikesLocalStorage {
  /// Creates a new db_client-backed local storage.
  ///
  /// Requires a [PersonalReactionsDao] for database operations and
  /// the [userPubkey] to scope records to the current user.
  DbLikesLocalStorage({
    required PersonalReactionsDao dao,
    required String userPubkey,
  }) : _dao = dao,
       _userPubkey = userPubkey;

  final PersonalReactionsDao _dao;
  final String _userPubkey;

  @override
  Future<void> saveLikeRecord(LikeRecord record) async {
    await _dao.upsertReaction(
      targetEventId: record.targetEventId,
      reactionEventId: record.reactionEventId,
      userPubkey: _userPubkey,
      createdAt: record.createdAt.millisecondsSinceEpoch ~/ 1000,
    );
  }

  @override
  Future<void> saveLikeRecordsBatch(List<LikeRecord> records) async {
    if (records.isEmpty) return;

    final rows = records.map((record) {
      return PersonalReactionRow(
        targetEventId: record.targetEventId,
        reactionEventId: record.reactionEventId,
        userPubkey: _userPubkey,
        createdAt: record.createdAt.millisecondsSinceEpoch ~/ 1000,
      );
    }).toList();

    await _dao.upsertReactionsBatch(rows);
  }

  @override
  Future<bool> deleteLikeRecord(String targetEventId) async {
    final deleted = await _dao.deleteReaction(
      targetEventId: targetEventId,
      userPubkey: _userPubkey,
    );
    return deleted > 0;
  }

  @override
  Future<LikeRecord?> getLikeRecord(String targetEventId) async {
    final row = await _dao.getReaction(
      targetEventId: targetEventId,
      userPubkey: _userPubkey,
    );

    if (row == null) return null;

    return _rowToRecord(row);
  }

  @override
  Future<String?> getReactionEventId(String targetEventId) async {
    return _dao.getReactionEventId(
      targetEventId: targetEventId,
      userPubkey: _userPubkey,
    );
  }

  @override
  Future<List<LikeRecord>> getAllLikeRecords() async {
    final rows = await _dao.getAllReactions(_userPubkey);
    return rows.map(_rowToRecord).toList();
  }

  @override
  Future<Set<String>> getLikedEventIds() async {
    return _dao.getLikedEventIds(_userPubkey);
  }

  @override
  Future<bool> isLiked(String targetEventId) async {
    return _dao.isLiked(
      targetEventId: targetEventId,
      userPubkey: _userPubkey,
    );
  }

  @override
  Stream<List<String>> watchLikedEventIds() {
    return _dao.watchLikedEventIds(_userPubkey);
  }

  @override
  Future<void> clearAll() async {
    await _dao.deleteAllForUser(_userPubkey);
  }

  /// Converts a database row to a [LikeRecord].
  LikeRecord _rowToRecord(PersonalReactionRow row) {
    return LikeRecord(
      targetEventId: row.targetEventId,
      reactionEventId: row.reactionEventId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt * 1000),
    );
  }
}
