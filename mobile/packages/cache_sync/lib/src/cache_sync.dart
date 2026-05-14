import 'dart:async';

import 'package:cache_sync/src/cache_dao.dart';
import 'package:cache_sync/src/cache_dao_impl.dart';
import 'package:cache_sync/src/cache_database.dart';
import 'package:cache_sync/src/cache_fetch_policy.dart';
import 'package:cache_sync/src/cache_result.dart';

/// Static facade for the stale-while-revalidate cache.
///
/// Call [init] once at app startup (or in test `setUp`) before using any
/// other method.
///
/// ```dart
/// // main.dart
/// await CacheSync.init();
///
/// // test
/// setUp(() => CacheSync.init(dao: FakeCacheDao()));
/// ```
abstract final class CacheSync {
  static late CacheDao _dao;

  /// Default cache size limit used in production (100 MB).
  ///
  /// Pass to [init] as `maxSizeBytes` or override with your own value.
  static const int defaultMaxSizeBytes = 100 * 1024 * 1024;

  /// Initialises the cache.
  ///
  /// - [maxSizeBytes] caps the total payload size; when exceeded the oldest
  ///   entries are evicted (LRU). Pass `null` to disable the limit.
  ///   Defaults to [defaultMaxSizeBytes] (100 MB) in production.
  /// - In tests inject a [CacheDao] implementation via [dao] to avoid disk I/O.
  ///   The [maxSizeBytes] parameter is ignored when [dao] is provided;
  ///   construct the fake with its own limit if needed.
  static Future<void> init({
    CacheDao? dao,
    int? maxSizeBytes = defaultMaxSizeBytes,
  }) async {
    if (dao != null) {
      _dao = dao;
      return;
    }
    // coverage:ignore-start
    final db = CacheDatabase();
    _dao = CacheDaoImpl(db, maxSizeBytes: maxSizeBytes);
    // coverage:ignore-end
  }

  /// Watches a single value backed by a [Future] fetch.
  ///
  /// Emits at most two events per call:
  ///   1. A [CacheResult.cached] if a non-expired cached value exists.
  ///   2. A [CacheResult.live] once the [fetch] Future resolves.
  ///
  /// When [policy] is [CacheFetchPolicy.cacheFirst], a fresh cached value ends
  /// the stream without calling [fetch].
  ///
  /// If [toJson] returns an empty string the result is **not** written to the
  /// cache. This lets callers signal "do not cache this response" by returning
  /// an empty payload.
  ///
  /// Errors from [fetch] are forwarded as stream errors.
  static Stream<CacheResult<T>> watchOne<T>({
    required String key,
    required Future<T> Function() fetch,
    required T Function(String json) fromJson,
    required String Function(T value) toJson,
    Duration? ttl,
    CacheFetchPolicy policy = CacheFetchPolicy.cacheAndNetwork,
  }) {
    late final StreamController<CacheResult<T>> controller;
    controller = StreamController<CacheResult<T>>(
      onListen: () => _driveWatchOne(
        controller: controller,
        key: key,
        fetch: fetch,
        fromJson: fromJson,
        toJson: toJson,
        ttl: ttl,
        policy: policy,
      ),
    );
    return controller.stream;
  }

  /// Watches a value backed by a [Stream] source.
  ///
  /// Behaves like [watchOne] but the fetch is an ongoing [Stream] rather than
  /// a one-shot [Future]. Each live event from [source] is written to the
  /// cache and re-emitted as [CacheResult.live].
  ///
  /// When [policy] is [CacheFetchPolicy.cacheFirst], a fresh cached value ends
  /// the stream without subscribing to [source].
  ///
  /// Errors from [source] are forwarded as stream errors.
  static Stream<CacheResult<T>> watchStream<T>({
    required String key,
    required Stream<T> Function() source,
    required T Function(String json) fromJson,
    required String Function(T value) toJson,
    Duration? ttl,
    CacheFetchPolicy policy = CacheFetchPolicy.cacheAndNetwork,
  }) {
    StreamIterator<T>? iterator;
    late final StreamController<CacheResult<T>> controller;
    controller = StreamController<CacheResult<T>>(
      onListen: () => _driveWatchStream(
        controller: controller,
        key: key,
        source: source,
        fromJson: fromJson,
        toJson: toJson,
        ttl: ttl,
        policy: policy,
        registerIterator: (value) => iterator = value,
      ),
      onCancel: () async {
        await iterator?.cancel();
      },
    );
    return controller.stream;
  }

  /// Removes the cached entry for [key].
  static Future<void> invalidate(String key) => _dao.delete(key);

  /// Removes all cached entries whose keys start with [prefix].
  ///
  /// Account-scoped invalidation: cache keys follow the
  /// `${pubkeyHex}:${operation}` convention (RFC #4244), so calling
  /// `invalidatePrefix(pubkeyHex)` at sign-out clears every entry for that
  /// account without touching other accounts on the same device.
  ///
  /// ```dart
  /// // In AuthService.signOut, after capturing currentPubkey:
  /// await CacheSync.invalidatePrefix(currentPubkey);
  /// ```
  ///
  /// [prefix] must not contain SQL `LIKE` wildcards (`%`, `_`). Pubkey hex
  /// is `[0-9a-f]{64}` so the pubkey-prefix convention is safe; callers
  /// passing other prefixes are responsible for escaping.
  static Future<void> invalidatePrefix(String prefix) =>
      _dao.deletePrefix(prefix);

  /// Removes all cached entries.
  ///
  /// Use only when no scoped invalidation is possible (e.g. corruption
  /// recovery). For sign-out / account-switch prefer [invalidatePrefix] so
  /// other accounts on the same device keep their caches.
  ///
  /// ```dart
  /// await CacheSync.invalidateAll();
  /// ```
  static Future<void> invalidateAll() => _dao.deleteAll();

  /// Writes [value] for [key] only when it is newer than the currently
  /// cached value (or when nothing is cached / the cached payload is
  /// corrupted).
  ///
  /// "Newer" is determined by [versionOf]: a value with a strictly higher
  /// version replaces an older one. Equal versions are not overwritten.
  ///
  /// Intended for replaceable Nostr events (kinds 0, 3, 10000-19999,
  /// 30000-39999) where `created_at` ordering must be preserved across
  /// writes from multiple relays. Callers pass
  /// `versionOf: (event) => event.createdAt`.
  ///
  /// Returns `true` when the cache was updated, `false` when the existing
  /// entry was newer or equal.
  static Future<bool> writeIfNewer<T>({
    required String key,
    required T value,
    required T Function(String json) fromJson,
    required String Function(T value) toJson,
    required int Function(T value) versionOf,
    Duration? ttl,
  }) async {
    final cachedPayload = await _dao.read(key);
    if (cachedPayload != null && cachedPayload.isNotEmpty) {
      try {
        final cachedValue = fromJson(cachedPayload);
        if (versionOf(cachedValue) >= versionOf(value)) {
          return false;
        }
      } on Object {
        // Corrupted cached payload — fall through and overwrite.
      }
    }

    final payload = toJson(value);
    if (payload.isEmpty) return false;
    await _dao.write(key: key, payload: payload, ttl: ttl);
    return true;
  }

  static Future<void> _driveWatchOne<T>({
    required StreamController<CacheResult<T>> controller,
    required String key,
    required Future<T> Function() fetch,
    required T Function(String json) fromJson,
    required String Function(T value) toJson,
    required Duration? ttl,
    required CacheFetchPolicy policy,
  }) async {
    // 1. Serve from cache when applicable.
    var servedCachedValue = false;
    if (policy != CacheFetchPolicy.networkOnly) {
      final cached = await _dao.read(key);
      if (cached != null && cached.isNotEmpty) {
        try {
          controller.add(CacheResult.cached(fromJson(cached)));
          servedCachedValue = true;
        } on Object {
          // Corrupted cache entry — ignore and fetch fresh.
          await _dao.delete(key);
        }
      }
    }

    if (policy == CacheFetchPolicy.cacheOnly ||
        (policy == CacheFetchPolicy.cacheFirst && servedCachedValue)) {
      await controller.close();
      return;
    }

    // 2. Fetch from network.
    try {
      final value = await fetch();
      final payload = toJson(value);
      if (payload.isNotEmpty) {
        await _dao.write(key: key, payload: payload, ttl: ttl);
      }
      if (!controller.isClosed) {
        controller.add(CacheResult.live(value));
      }
    } on Object catch (e, st) {
      if (!controller.isClosed) {
        controller.addError(e, st);
      }
    } finally {
      if (!controller.isClosed) await controller.close();
    }
  }

  static Future<void> _driveWatchStream<T>({
    required StreamController<CacheResult<T>> controller,
    required String key,
    required Stream<T> Function() source,
    required T Function(String json) fromJson,
    required String Function(T value) toJson,
    required Duration? ttl,
    required CacheFetchPolicy policy,
    required void Function(StreamIterator<T> iterator) registerIterator,
  }) async {
    // 1. Serve from cache when applicable.
    var servedCachedValue = false;
    if (policy != CacheFetchPolicy.networkOnly) {
      final cached = await _dao.read(key);
      if (cached != null && cached.isNotEmpty) {
        try {
          controller.add(CacheResult.cached(fromJson(cached)));
          servedCachedValue = true;
        } on Object {
          await _dao.delete(key);
        }
      }
    }

    if (policy == CacheFetchPolicy.cacheOnly ||
        (policy == CacheFetchPolicy.cacheFirst && servedCachedValue)) {
      await controller.close();
      return;
    }

    // 2. Subscribe to source stream.
    if (controller.isClosed) return;

    final iterator = StreamIterator<T>(source());
    registerIterator(iterator);

    try {
      while (!controller.isClosed && await iterator.moveNext()) {
        final value = iterator.current;
        final payload = toJson(value);
        if (payload.isNotEmpty) {
          await _dao.write(key: key, payload: payload, ttl: ttl);
        }
        if (!controller.isClosed) {
          controller.add(CacheResult.live(value));
        }
      }
    } on Object catch (e, st) {
      if (!controller.isClosed) {
        controller.addError(e, st);
      }
    } finally {
      await iterator.cancel();
      if (!controller.isClosed) await controller.close();
    }
  }
}
