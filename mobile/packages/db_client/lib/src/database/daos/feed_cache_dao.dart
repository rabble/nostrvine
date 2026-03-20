// ABOUTME: Data Access Object for feed response cache operations.
// ABOUTME: Stores one JSON response body per feed key for cold-start
// ABOUTME: cache of feed data.

import 'package:db_client/db_client.dart' hide Filter;
import 'package:drift/drift.dart';

part 'feed_cache_dao.g.dart';

@DriftAccessor(tables: [FeedResponseCache])
class FeedCacheDao extends DatabaseAccessor<AppDatabase>
    with _$FeedCacheDaoMixin {
  FeedCacheDao(super.attachedDatabase);

  /// Saves a JSON response body for [feedKey].
  ///
  /// Replaces any existing cached response for this key.
  Future<void> saveResponseBody(String feedKey, String body) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await customInsert(
      'INSERT OR REPLACE INTO feed_response_cache '
      '(feed_key, response_body, cached_at) VALUES (?, ?, ?)',
      variables: [
        Variable.withString(feedKey),
        Variable.withString(body),
        Variable.withInt(now),
      ],
      updates: {feedResponseCache},
    );
  }

  /// Returns the cached response body for [feedKey], or `null` if none.
  Future<String?> getResponseBody(String feedKey) async {
    final rows = await customSelect(
      'SELECT response_body FROM feed_response_cache WHERE feed_key = ?',
      variables: [Variable.withString(feedKey)],
      readsFrom: {feedResponseCache},
    ).get();

    if (rows.isEmpty) return null;
    return rows.first.read<String>('response_body');
  }

  /// Deletes the cached response for [feedKey].
  Future<void> clearResponseBody(String feedKey) async {
    await customUpdate(
      'DELETE FROM feed_response_cache WHERE feed_key = ?',
      variables: [Variable.withString(feedKey)],
      updates: {feedResponseCache},
      updateKind: UpdateKind.delete,
    );
  }

  /// Deletes all cached responses.
  Future<void> clearAll() async {
    await customUpdate(
      'DELETE FROM feed_response_cache',
      updates: {feedResponseCache},
      updateKind: UpdateKind.delete,
    );
  }
}
