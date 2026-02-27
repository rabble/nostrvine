// ABOUTME: Riverpod provider for managing profile statistics with async loading and caching
// ABOUTME: Aggregates user video count, likes, and other metrics from Nostr events

import 'dart:async';

import 'package:db_client/db_client.dart' hide ProfileStats;
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_stats_provider.g.dart';

/// Get cached stats from Drift if available and not expired.
Future<ProfileStats?> _getCachedProfileStats(
  ProfileStatsDao dao,
  String pubkey,
) async {
  final row = await dao.getStats(pubkey);
  if (row == null) return null;

  final stats = ProfileStats(
    pubkey: pubkey,
    videoCount: row.videoCount ?? 0,
    totalLikes: row.totalLikes ?? 0,
    followers: row.followerCount ?? 0,
    following: row.followingCount ?? 0,
    totalViews: row.totalViews ?? 0,
    lastUpdated: row.cachedAt,
  );

  final age = DateTime.now().difference(stats.lastUpdated!);
  Log.debug(
    'Using cached stats for $pubkey (age: ${age.inMinutes}min)',
    name: 'ProfileStatsProvider',
    category: LogCategory.ui,
  );

  return stats;
}

/// Cache stats to Drift.
Future<void> _cacheProfileStats(
  ProfileStatsDao dao,
  String pubkey,
  ProfileStats stats,
) async {
  await dao.upsertStats(
    pubkey: pubkey,
    videoCount: stats.videoCount,
    followerCount: stats.followers,
    followingCount: stats.following,
    totalViews: stats.totalViews,
    totalLikes: stats.totalLikes,
  );
  Log.debug(
    'Cached stats for $pubkey',
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
  final statsDao = ref.watch(databaseProvider).profileStatsDao;
  // Get the social service from app providers
  final socialService = ref.read(socialServiceProvider);

  // Always fetch fresh follower stats (has its own in-memory cache).
  // Start this immediately so it runs in parallel with cache/feed loading.
  final followerStatsFuture = socialService.getFollowerStats(pubkey);

  // Check cache for video data (video counts change rarely)
  final cached = await _getCachedProfileStats(statsDao, pubkey);
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
      await _cacheProfileStats(statsDao, pubkey, stats);
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
      pubkey: pubkey,
      videoCount: videoCount,
      totalLikes: totalLikes,
      followers: followerStats['followers'] ?? 0,
      following: followerStats['following'] ?? 0,
      totalViews: totalLoops,
      lastUpdated: DateTime.now(),
    );

    // Cache the results (only if video count > 0 to avoid caching timing issues)
    if (videoCount > 0) {
      await _cacheProfileStats(statsDao, pubkey, stats);
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
