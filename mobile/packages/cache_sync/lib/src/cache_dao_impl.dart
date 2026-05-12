// ignore_for_file: public_member_api_docs // internal implementation, not re-exported by the package
import 'package:cache_sync/src/cache_dao.dart';
import 'package:cache_sync/src/cache_database.dart';
import 'package:drift/drift.dart';

/// Drift-backed implementation of [CacheDao].
///
/// TTL eviction is applied **on read**: an expired row is deleted and `null`
/// is returned, so stale data never reaches the caller.
///
/// When [maxSizeBytes] is set, LRU eviction runs **after every write**:
/// the oldest entries (by `cachedAt`) are deleted until the total payload
/// size is within the budget.
class CacheDaoImpl implements CacheDao {
  CacheDaoImpl(this._db, {this.maxSizeBytes});

  final CacheDatabase _db;

  /// Maximum total payload size in characters. `null` = unlimited.
  final int? maxSizeBytes;

  @override
  Future<String?> read(String key) async {
    final row = await (_db.select(
      _db.cacheEntries,
    )..where((t) => t.cacheKey.equals(key))).getSingleOrNull();

    if (row == null) return null;

    final expires = row.expiresAt;
    if (expires != null && DateTime.now().toUtc().isAfter(expires)) {
      await delete(key);
      return null;
    }

    return row.payload;
  }

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {
    final now = DateTime.now().toUtc();
    await _db
        .into(_db.cacheEntries)
        .insertOnConflictUpdate(
          CacheEntriesCompanion.insert(
            cacheKey: key,
            payload: payload,
            cachedAt: now,
            expiresAt: Value(ttl != null ? now.add(ttl) : null),
          ),
        );

    final limit = maxSizeBytes;
    if (limit != null) {
      final total = await totalPayloadBytes();
      if (total > limit) await evictOldest(total - limit);
    }
  }

  @override
  Future<void> delete(String key) async {
    await (_db.delete(
      _db.cacheEntries,
    )..where((t) => t.cacheKey.equals(key))).go();
  }

  @override
  Future<void> deleteAll() async {
    await _db.delete(_db.cacheEntries).go();
  }

  @override
  Future<int> totalPayloadBytes() async {
    final result = await _db
        .customSelect(
          'SELECT COALESCE(SUM(LENGTH(payload)), 0) AS total '
          'FROM cache_entries',
          readsFrom: {_db.cacheEntries},
        )
        .getSingle();
    return result.read<int>('total');
  }

  @override
  Future<void> evictOldest(int bytesToFree) async {
    if (bytesToFree <= 0) return;
    await _db.transaction(() async {
      var freed = 0;
      final rows = await (_db.select(
        _db.cacheEntries,
      )..orderBy([(t) => OrderingTerm.asc(t.cachedAt)])).get();

      for (final row in rows) {
        if (freed >= bytesToFree) break;
        freed += row.payload.length;
        await (_db.delete(
          _db.cacheEntries,
        )..where((t) => t.cacheKey.equals(row.cacheKey))).go();
      }
    });
  }
}
