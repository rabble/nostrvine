// ABOUTME: db_client implementation of RepostsLocalStorage.
// ABOUTME: Uses PersonalRepostsDao for persistent storage of repost records.

import 'package:db_client/db_client.dart';
import 'package:reposts_repository/src/models/repost_record.dart';
import 'package:reposts_repository/src/reposts_local_storage.dart';

/// Implementation of `RepostsLocalStorage` using db_client's
/// `PersonalRepostsDao`.
///
/// This implementation persists repost records to the local SQLite database,
/// providing durability across app restarts.
class DbRepostsLocalStorage implements RepostsLocalStorage {
  /// Creates a new db_client-backed local storage.
  ///
  /// Requires a [PersonalRepostsDao] for database operations and
  /// the [userPubkey] to scope records to the current user.
  DbRepostsLocalStorage({
    required PersonalRepostsDao dao,
    required String userPubkey,
  }) : _dao = dao,
       _userPubkey = userPubkey;

  final PersonalRepostsDao _dao;
  final String _userPubkey;

  @override
  Future<void> saveRepostRecord(RepostRecord record) async {
    await _dao.upsertRepost(
      addressableId: record.addressableId,
      repostEventId: record.repostEventId,
      originalAuthorPubkey: record.originalAuthorPubkey,
      userPubkey: _userPubkey,
      createdAt: record.createdAt.millisecondsSinceEpoch ~/ 1000,
    );
  }

  @override
  Future<void> saveRepostRecordsBatch(List<RepostRecord> records) async {
    if (records.isEmpty) return;

    final rows = records.map((record) {
      return PersonalRepostRow(
        addressableId: record.addressableId,
        repostEventId: record.repostEventId,
        originalAuthorPubkey: record.originalAuthorPubkey,
        userPubkey: _userPubkey,
        createdAt: record.createdAt.millisecondsSinceEpoch ~/ 1000,
      );
    }).toList();

    await _dao.upsertRepostsBatch(rows);
  }

  @override
  Future<bool> deleteRepostRecord(String addressableId) async {
    final deleted = await _dao.deleteRepost(
      addressableId: addressableId,
      userPubkey: _userPubkey,
    );
    return deleted > 0;
  }

  @override
  Future<RepostRecord?> getRepostRecord(String addressableId) async {
    final row = await _dao.getRepost(
      addressableId: addressableId,
      userPubkey: _userPubkey,
    );

    if (row == null) return null;

    return _rowToRecord(row);
  }

  @override
  Future<String?> getRepostEventId(String addressableId) async {
    return _dao.getRepostEventId(
      addressableId: addressableId,
      userPubkey: _userPubkey,
    );
  }

  @override
  Future<List<RepostRecord>> getAllRepostRecords() async {
    final rows = await _dao.getAllReposts(_userPubkey);
    return rows.map(_rowToRecord).toList();
  }

  @override
  Future<Set<String>> getRepostedAddressableIds() async {
    return _dao.getRepostedAddressableIds(_userPubkey);
  }

  @override
  Future<bool> isReposted(String addressableId) async {
    return _dao.isReposted(
      addressableId: addressableId,
      userPubkey: _userPubkey,
    );
  }

  @override
  Stream<Set<String>> watchRepostedAddressableIds() {
    return _dao.watchRepostedAddressableIds(_userPubkey);
  }

  @override
  Future<void> clearAll() async {
    await _dao.deleteAllForUser(_userPubkey);
  }

  /// Converts a database row to a [RepostRecord].
  RepostRecord _rowToRecord(PersonalRepostRow row) {
    return RepostRecord(
      addressableId: row.addressableId,
      repostEventId: row.repostEventId,
      originalAuthorPubkey: row.originalAuthorPubkey,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt * 1000),
    );
  }
}
