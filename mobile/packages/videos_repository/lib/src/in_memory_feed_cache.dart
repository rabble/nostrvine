// ABOUTME: Volatile in-memory cache for feed results keyed by feed mode.
// ABOUTME: Lives in the repository layer so it survives BLoC recreation
// ABOUTME: but is lost on app restart. Used for instant mode switching.

import 'package:videos_repository/src/author_feed_result.dart';
import 'package:videos_repository/src/home_feed_result.dart';

/// {@template in_memory_feed_cache}
/// Volatile, session-scoped cache for feed results.
///
/// Stores [HomeFeedResult] keyed by feed mode name (e.g. `"latest"`,
/// `"popular"`, `"classics"`), plus [AuthorFeedResult] keyed by author
/// (e.g. `"author:<pubkeyHex>"`). The cache lives in memory only — it
/// does not persist across app restarts.
///
/// Because the `VideosRepository` outlives individual BLoC instances,
/// cached results survive BLoC recreation (e.g. navigating away from
/// the feed and back), enabling instant mode switches and instant
/// profile reseed without a network round-trip.
/// {@endtemplate}
class InMemoryFeedCache {
  /// {@macro in_memory_feed_cache}
  InMemoryFeedCache({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Map<String, _HomeFeedCacheEntry> _store = {};
  final Map<String, AuthorFeedResult> _authorStore = {};

  /// Returns the cached result for [key], or `null` if not cached.
  HomeFeedResult? get(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (entry.isExpired(_now())) {
      _store.remove(key);
      return null;
    }
    return entry.result;
  }

  /// Stores [result] under [key], replacing any previous entry.
  void set(String key, HomeFeedResult result, {Duration? ttl}) {
    _store[key] = _HomeFeedCacheEntry(
      result,
      expiresAt: ttl == null ? null : _now().add(ttl),
    );
  }

  /// Returns the cached author-feed result for [key], or `null`.
  ///
  /// Author results carry the offset pagination envelope and so are stored
  /// separately from the cursor-based [HomeFeedResult] entries.
  AuthorFeedResult? getAuthorFeed(String key) => _authorStore[key];

  /// Stores an author-feed [result] under [key], replacing any previous entry.
  void setAuthorFeed(String key, AuthorFeedResult result) =>
      _authorStore[key] = result;

  /// Removes the entry for [key] from both the home-feed and author-feed
  /// stores, if present. Keys are namespaced (`"latest"` vs
  /// `"author:<hex>"`) so clearing both is a safe no-op for the other.
  void remove(String key) {
    _store.remove(key);
    _authorStore.remove(key);
  }

  /// Clears all cached entries (home-feed and author-feed).
  void clear() {
    _store.clear();
    _authorStore.clear();
  }
}

class _HomeFeedCacheEntry {
  const _HomeFeedCacheEntry(this.result, {this.expiresAt});

  final HomeFeedResult result;
  final DateTime? expiresAt;

  bool isExpired(DateTime now) {
    final expiresAt = this.expiresAt;
    return expiresAt != null && !now.isBefore(expiresAt);
  }
}
