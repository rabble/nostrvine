/// Abstract interface for the cache DAO.
///
/// Decoupled from Drift so tests can inject a fake DAO.
abstract interface class CacheDao {
  /// Returns the payload for [key], or `null` when the entry is absent or
  /// has passed its `expiresAt` deadline.
  Future<String?> read(String key);

  /// Writes [payload] for [key].
  ///
  /// - If [ttl] is provided the row's `expiresAt` is set to `now + ttl`.
  /// - If [ttl] is `null` the entry never expires.
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  });

  /// Removes the single entry for [key], if present.
  Future<void> delete(String key);

  /// Removes all cached entries.
  Future<void> deleteAll();

  /// Returns the total size of all `payload` strings, in characters.
  ///
  /// Uses `String.length` semantics (UTF-16 code units), suitable as an
  /// approximation of storage bytes for JSON-heavy payloads.
  Future<int> totalPayloadBytes();

  /// Deletes the oldest entries (by write time, ascending) until at least
  /// [bytesToFree] characters have been freed.
  ///
  /// Does nothing when [bytesToFree] ≤ 0 or the store is empty.
  Future<void> evictOldest(int bytesToFree);
}
