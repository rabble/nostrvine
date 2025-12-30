// ABOUTME: Provider for fetching videos that a user has liked
// ABOUTME: Searches video cache first, then fetches from relays for missing videos

import 'dart:async';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/likes_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_liked_videos_provider.g.dart';

/// Provider that returns videos the current user has liked
///
/// Combines liked event IDs from likesProvider with video data from:
/// 1. Local cache (VideoEventService)
/// 2. Relay queries for any missing videos
@riverpod
class ProfileLikedVideos extends _$ProfileLikedVideos {
  @override
  Future<List<VideoEvent>> build() async {
    // Watch likes state for reactive updates
    final likesState = ref.watch(likesProvider);
    // Use ordered list (most recently liked first) instead of unordered set
    final orderedLikedEventIds = likesState.orderedLikedEventIds;

    Log.info(
      'ProfileLikedVideos: Building with ${orderedLikedEventIds.length} '
      'liked event IDs',
      name: 'ProfileLikedVideosProvider',
      category: LogCategory.video,
    );

    if (orderedLikedEventIds.isEmpty) {
      return [];
    }

    // Get video service to check cache
    final videoService = ref.read(videoEventServiceProvider);

    final cachedVideosMap = <String, VideoEvent>{};
    final missingIds = <String>[];

    // Check cache first
    for (final eventId in orderedLikedEventIds) {
      final cached = videoService.getVideoById(eventId);
      if (cached != null) {
        cachedVideosMap[eventId] = cached;
      } else {
        missingIds.add(eventId);
      }
    }

    Log.info(
      'ProfileLikedVideos: Found ${cachedVideosMap.length} in cache, '
      '${missingIds.length} need relay fetch',
      name: 'ProfileLikedVideosProvider',
      category: LogCategory.video,
    );

    // Fetch missing videos from relays
    if (missingIds.isNotEmpty) {
      final nostrClient = ref.read(nostrServiceProvider);
      final fetchedVideos = await _fetchVideosFromRelay(
        nostrClient,
        missingIds,
      );
      for (final video in fetchedVideos) {
        cachedVideosMap[video.id] = video;
      }

      Log.info(
        'ProfileLikedVideos: Fetched ${fetchedVideos.length} from relay',
        name: 'ProfileLikedVideosProvider',
        category: LogCategory.video,
      );
    }

    // Build ordered list using the recency-ordered IDs from likes state
    final orderedVideos = <VideoEvent>[];
    for (final eventId in orderedLikedEventIds) {
      final video = cachedVideosMap[eventId];
      if (video != null) {
        orderedVideos.add(video);
      }
    }

    // Filter out unsupported videos (WebM on iOS/macOS)
    final supportedVideos = orderedVideos
        .where((v) => v.isSupportedOnCurrentPlatform)
        .toList();

    Log.info(
      'ProfileLikedVideos: Returning ${supportedVideos.length} videos',
      name: 'ProfileLikedVideosProvider',
      category: LogCategory.video,
    );

    return supportedVideos;
  }

  /// Fetch videos from relays by their event IDs
  Future<List<VideoEvent>> _fetchVideosFromRelay(
    NostrClient nostrClient,
    List<String> eventIds,
  ) async {
    if (eventIds.isEmpty) return [];

    final completer = Completer<List<VideoEvent>>();
    final videos = <VideoEvent>[];
    Timer? timeoutTimer;

    // Generate unique subscription ID for cleanup
    final subscriptionId =
        'liked_videos_${DateTime.now().millisecondsSinceEpoch}';

    /// Helper to clean up subscription resources
    Future<void> cleanup() async {
      timeoutTimer?.cancel();
      await nostrClient.unsubscribe(subscriptionId);
    }

    try {
      // Create filter for video events by ID
      // NIP-71 kinds: 34235 (horizontal), 34236 (vertical/short)
      final filter = Filter(ids: eventIds, kinds: [34235, 34236]);

      final eventStream = nostrClient.subscribe([
        filter,
      ], subscriptionId: subscriptionId);
      late StreamSubscription<Event> subscription;

      // Set timeout for relay response
      timeoutTimer = Timer(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          subscription.cancel();
          cleanup();
          completer.complete(videos);
        }
      });

      subscription = eventStream.listen(
        (event) {
          try {
            final video = VideoEvent.fromNostrEvent(event);
            videos.add(video);
          } catch (e) {
            Log.warning(
              'ProfileLikedVideos: Failed to parse event ${event.id}: $e',
              name: 'ProfileLikedVideosProvider',
              category: LogCategory.video,
            );
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            cleanup();
            completer.complete(videos);
          }
        },
        onError: (Object error) {
          Log.error(
            'ProfileLikedVideos: Stream error: $error',
            name: 'ProfileLikedVideosProvider',
            category: LogCategory.video,
          );
          if (!completer.isCompleted) {
            cleanup();
            completer.complete(videos);
          }
        },
      );

      return completer.future;
    } catch (e) {
      Log.error(
        'ProfileLikedVideos: Failed to fetch from relay: $e',
        name: 'ProfileLikedVideosProvider',
        category: LogCategory.video,
      );
      await cleanup();
      return videos;
    }
  }

  /// Refresh liked videos (invalidates and rebuilds)
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// Provider that wraps liked videos into VideoFeedState for route-based video tracking
@riverpod
Future<VideoFeedState> likedVideosFeedState(Ref ref) async {
  final likedVideos = await ref.watch(profileLikedVideosProvider.future);
  return VideoFeedState(
    videos: likedVideos,
    hasMoreContent: false, // Liked videos don't have pagination currently
    isLoadingMore: false,
    lastUpdated: DateTime.now(),
  );
}
