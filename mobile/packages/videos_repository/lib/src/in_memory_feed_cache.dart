// ABOUTME: Volatile in-memory cache for feed results keyed by feed mode.
// ABOUTME: Lives in the repository layer so it survives BLoC recreation
// ABOUTME: but is lost on app restart. Used for instant mode switching.

import 'package:videos_repository/src/home_feed_result.dart';

/// {@template in_memory_feed_cache}
/// Volatile, session-scoped cache for feed results.
///
/// Stores [HomeFeedResult] keyed by feed mode name (e.g. `"home"`,
/// `"latest"`, `"popular"`). The cache lives in memory only — it does
/// not persist across app restarts.
///
/// Because the `VideosRepository` outlives individual BLoC instances,
/// cached results survive BLoC recreation (e.g. navigating away from
/// the feed and back), enabling instant mode switches without a
/// network round-trip.
/// {@endtemplate}
class InMemoryFeedCache {
  /// {@macro in_memory_feed_cache}
  InMemoryFeedCache();

  final Map<String, HomeFeedResult> _store = {};

  /// Returns the cached result for [key], or `null` if not cached.
  HomeFeedResult? get(String key) => _store[key];

  /// Stores [result] under [key], replacing any previous entry.
  void set(String key, HomeFeedResult result) => _store[key] = result;

  /// Removes the entry for [key], if present.
  void remove(String key) => _store.remove(key);

  /// Clears all cached entries.
  void clear() => _store.clear();
}
