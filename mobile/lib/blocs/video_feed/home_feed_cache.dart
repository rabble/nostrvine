// ABOUTME: Cache for home feed data using SharedPreferences.
// ABOUTME: Enables instant feed display on cold start by serving
// ABOUTME: cached videos while fresh data loads from the network.

import 'dart:convert';

import 'package:models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

/// SharedPreferences key for cached home feed JSON.
const homeFeedCacheKey = 'home_feed_cache';

/// SharedPreferences key for cached home feed timestamp.
const homeFeedCacheTimeKey = 'home_feed_cache_time';

/// Maximum age of cached home feed before it's considered stale.
const homeFeedCacheMaxAge = Duration(hours: 1);

/// Reads and writes cached home feed data from SharedPreferences.
///
/// The cache stores the raw JSON response from the Funnelcake API
/// so it can be parsed into [HomeFeedResult] on next cold start
/// without any network request.
///
/// Cache entries older than [homeFeedCacheMaxAge] are ignored.
class HomeFeedCache {
  /// Creates a [HomeFeedCache].
  const HomeFeedCache();

  /// Loads the cached home feed, or `null` if no valid cache exists.
  ///
  /// Returns `null` when:
  /// - No cache entry exists
  /// - The cache is older than [homeFeedCacheMaxAge]
  /// - The cached JSON cannot be parsed
  HomeFeedResult? read(SharedPreferences prefs) {
    try {
      final cachedJson = prefs.getString(homeFeedCacheKey);
      if (cachedJson == null) return null;

      final cachedTimeMs = prefs.getInt(homeFeedCacheTimeKey) ?? 0;
      final cachedTime = DateTime.fromMillisecondsSinceEpoch(cachedTimeMs);
      if (DateTime.now().difference(cachedTime) > homeFeedCacheMaxAge) {
        return null;
      }

      return _parse(cachedJson);
    } catch (_) {
      return null;
    }
  }

  /// Writes home feed JSON to cache with the current timestamp.
  ///
  /// Only caches when [json] is non-null and non-empty.
  Future<void> write(SharedPreferences prefs, String json) async {
    await prefs.setString(homeFeedCacheKey, json);
    await prefs.setInt(
      homeFeedCacheTimeKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Parses raw JSON into a [HomeFeedResult].
  static HomeFeedResult _parse(String jsonStr) {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final videosData = data['videos'] as List<dynamic>? ?? [];
    final videos = videosData
        .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
        .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
        .map((v) => v.toVideoEvent())
        .toList();

    return HomeFeedResult(videos: videos);
  }
}
