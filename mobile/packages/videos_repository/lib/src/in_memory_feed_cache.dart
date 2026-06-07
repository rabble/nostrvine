// ABOUTME: Volatile in-memory cache for feed results keyed by feed mode.
// ABOUTME: Lives in the repository layer so it survives BLoC recreation
// ABOUTME: but is lost on app restart. Used for instant mode switching.

import 'package:videos_repository/src/author_feed_result.dart';
import 'package:videos_repository/src/home_feed_result.dart';

/// {@template in_memory_feed_cache}
/// Volatile, session-scoped cache for feed results.
///
/// Stores [HomeFeedResult] keyed by feed mode name (e.g. `"home"`,
/// `"latest"`, `"popular"`), plus [AuthorFeedResult] keyed by author
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
  InMemoryFeedCache();

  final Map<String, HomeFeedResult> _store = {};
  final Map<String, AuthorFeedResult> _authorStore = {};

  /// Returns the cached result for [key], or `null` if not cached.
  HomeFeedResult? get(String key) => _store[key];

  /// Stores [result] under [key], replacing any previous entry.
  void set(String key, HomeFeedResult result) => _store[key] = result;

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
