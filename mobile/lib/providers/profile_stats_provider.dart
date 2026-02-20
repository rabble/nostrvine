// ABOUTME: Riverpod provider for managing profile statistics with async loading and caching
// ABOUTME: Aggregates user video count, likes, and other metrics from Nostr events

import 'dart:async';

import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/services/profile_stats_cache_service.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_stats_provider.g.dart';

/// Statistics for a user's profile
class ProfileStats {
  const ProfileStats({
    required this.videoCount,
    required this.totalLikes,
    required this.followers,
    required this.following,
    required this.totalViews,
    required this.lastUpdated,
  });
  final int videoCount;
  final int totalLikes;
  final int followers;
  final int following;
  final int totalViews; // Placeholder for future implementation
  final DateTime lastUpdated;

  ProfileStats copyWith({
    int? videoCount,
    int? totalLikes,
    int? followers,
    int? following,
    int? totalViews,
    DateTime? lastUpdated,
  }) => ProfileStats(
    videoCount: videoCount ?? this.videoCount,
    totalLikes: totalLikes ?? this.totalLikes,
    followers: followers ?? this.followers,
    following: following ?? this.following,
    totalViews: totalViews ?? this.totalViews,
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );

  @override
  String toString() =>
      'ProfileStats(videos: $videoCount, likes: $totalLikes, followers: $followers, following: $following, views: $totalViews)';
}

// SQLite-based persistent cache
final _cacheService = ProfileStatsCacheService();

/// Get cached stats if available and not expired
Future<ProfileStats?> _getCachedProfileStats(String pubkey) async {
  final stats = await _cacheService.getCachedStats(pubkey);

  if (stats != null) {
    final age = DateTime.now().difference(stats.lastUpdated);
    Log.debug(
      '📱 Using cached stats for $pubkey (age: ${age.inMinutes}min)',
      name: 'ProfileStatsProvider',
      category: LogCategory.ui,
    );
  }

  return stats;
}

/// Cache stats for a user
Future<void> _cacheProfileStats(String pubkey, ProfileStats stats) async {
  await _cacheService.saveStats(pubkey, stats);
  Log.debug(
    '📱 Cached stats for $pubkey',
    name: 'ProfileStatsProvider',
    category: LogCategory.ui,
  );
}

/// Clear all cached stats
Future<void> clearAllProfileStatsCache() async {
  await _cacheService.clearAll();
  Log.debug(
    '📱️ Cleared all stats cache',
    name: 'ProfileStatsProvider',
    category: LogCategory.ui,
  );
}

// TODO(any): refactor this method while doing https://github.com/divinevideo/divine-mobile/issues/571
/// Async provider for loading profile statistics.
/// Derives video count from profileFeedProvider to ensure consistency
/// and proper waiting for relay events.
@riverpod
Future<ProfileStats> fetchProfileStats(Ref ref, String pubkey) async {
  // Get the social service from app providers
  final socialService = ref.read(socialServiceProvider);

  // Always fetch fresh follower stats (has its own in-memory cache).
  // Start this immediately so it runs in parallel with cache/feed loading.
  final followerStatsFuture = socialService.getFollowerStats(pubkey);

  // Check cache for video data (video counts change rarely)
  final cached = await _getCachedProfileStats(pubkey);
  if (cached != null && cached.videoCount > 0) {
    // Use cached video/likes data but always get fresh follower stats
    final followerStats = await followerStatsFuture;
    final freshFollowers = followerStats['followers'] ?? 0;
    final freshFollowing = followerStats['following'] ?? 0;

    // Always use fresh follower/following data (unfollows should be
    // reflected immediately, not masked by cached higher values).
    final stats = cached.copyWith(
      followers: freshFollowers,
      following: freshFollowing,
      lastUpdated: DateTime.now(),
    );

    // Update cache if follower counts changed
    if (freshFollowers != cached.followers ||
        freshFollowing != cached.following) {
      await _cacheProfileStats(pubkey, stats);
    }

    return stats;
  }

  try {
    // Get video data from profileFeedProvider which properly waits for relay events.
    // This avoids the race condition of reading the bucket immediately after
    // subscription setup (before events arrive).
    final feedStateFuture = ref.watch(profileFeedProvider(pubkey).future);

    // Run feed loading and follower stats fetch in parallel
    final results = await Future.wait<Object>([
      feedStateFuture,
      followerStatsFuture,
    ]);

    // Extract feed state and follower stats
    final feedState = results[0] as VideoFeedState;
    final followerStats = results[1] as Map<String, int>;

    // Get video list from feed state (already filtered to non-reposts)
    final videos = feedState.videos;
    final videoCount = videos.length;

    // Sum up loops and likes from all user's videos
    int totalLoops = 0;
    int totalLikes = 0;

    for (final video in videos) {
      totalLoops += video.originalLoops ?? 0;
      totalLikes += video.originalLikes ?? 0;
    }

    final stats = ProfileStats(
      videoCount: videoCount,
      totalLikes: totalLikes,
      followers: followerStats['followers'] ?? 0,
      following: followerStats['following'] ?? 0,
      totalViews: totalLoops,
      lastUpdated: DateTime.now(),
    );

    // Cache the results (only if video count > 0 to avoid caching timing issues)
    if (videoCount > 0) {
      await _cacheProfileStats(pubkey, stats);
    }

    Log.info(
      'Profile stats loaded: $videoCount videos, ${StringUtils.formatCompactNumber(totalLoops)} views, ${StringUtils.formatCompactNumber(totalLikes)} likes',
      name: 'ProfileStatsProvider',
      category: LogCategory.system,
    );

    return stats;
  } catch (e) {
    Log.error(
      'Error loading profile stats: $e',
      name: 'ProfileStatsProvider',
      category: LogCategory.ui,
    );
    rethrow;
  }
}

/// Get a formatted string for large numbers (e.g., 1234 -> "1.2k")
/// Delegates to StringUtils.formatCompactNumber for consistent formatting
String formatProfileStatsCount(int count) {
  return StringUtils.formatCompactNumber(count);
}
