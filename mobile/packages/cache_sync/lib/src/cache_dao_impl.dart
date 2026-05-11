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
  Future<void>? _statsInit;

  /// Maximum total payload size in characters. `null` = unlimited.
  final int? maxSizeBytes;

  Future<void> _ensureStatsReady() => _statsInit ??= _initStats();

  Future<void> _initStats() async {
    await _db.customStatement(_createCacheStatsTableSql);
    await _db.customStatement(_initCacheStatsRowSql);
  }

  Future<int> _readTotalPayloadBytes() async {
    final result = await _db
        .customSelect(
          _selectCacheStatsSql,
          readsFrom: {_db.cacheEntries},
        )
        .getSingle();
    return result.read<int>('total');
  }

  Future<void> _adjustTotalPayloadBytes(int delta) {
    return _db.customStatement(
      _adjustCacheStatsSql,
      [delta],
    );
  }

  @override
  Future<String?> read(String key) async {
    await _ensureStatsReady();
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
    await _ensureStatsReady();
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.cacheEntries,
      )..where((t) => t.cacheKey.equals(key))).getSingleOrNull();

      final oldSize = existing?.payload.length ?? 0;

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

      final delta = payload.length - oldSize;
      if (delta != 0) {
        await _adjustTotalPayloadBytes(delta);
      }
    });

    final limit = maxSizeBytes;
    if (limit != null) {
      final total = await totalPayloadBytes();
      if (total > limit) await evictOldest(total - limit);
    }
  }

  @override
  Future<void> delete(String key) async {
    await _ensureStatsReady();
    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.cacheEntries,
      )..where((t) => t.cacheKey.equals(key))).getSingleOrNull();

      if (existing == null) return;

      await (_db.delete(
        _db.cacheEntries,
      )..where((t) => t.cacheKey.equals(key))).go();

      await _adjustTotalPayloadBytes(-existing.payload.length);
    });
  }

  @override
  Future<void> deleteAll() async {
    await _ensureStatsReady();
    await _db.transaction(() async {
      await _db.delete(_db.cacheEntries).go();
      await _db.customStatement(_resetCacheStatsSql);
    });
  }

  @override
  Future<int> totalPayloadBytes() async {
    await _ensureStatsReady();
    return _readTotalPayloadBytes();
  }

  @override
  Future<void> evictOldest(int bytesToFree) async {
    await _ensureStatsReady();
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

      if (freed > 0) {
        await _adjustTotalPayloadBytes(-freed);
      }
    });
  }
}

const _createCacheStatsTableSql =
    'CREATE TABLE IF NOT EXISTS cache_stats ( '
    'id INTEGER PRIMARY KEY CHECK (id = 1), '
    'total_payload_bytes INTEGER NOT NULL DEFAULT 0)';

const _initCacheStatsRowSql =
    'INSERT OR IGNORE INTO cache_stats (id, total_payload_bytes) '
    'VALUES (1, 0)';

const _selectCacheStatsSql =
    'SELECT total_payload_bytes AS total FROM cache_stats WHERE id = 1';

const _adjustCacheStatsSql =
    'UPDATE cache_stats '
    'SET total_payload_bytes = MAX(0, total_payload_bytes + ?) '
    'WHERE id = 1';

const _resetCacheStatsSql =
    'UPDATE cache_stats SET total_payload_bytes = 0 WHERE id = 1';
