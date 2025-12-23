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
    final likedEventIds = likesState.likedEventIds;

    Log.info(
      'ProfileLikedVideos: Building with ${likedEventIds.length} liked event IDs',
      name: 'ProfileLikedVideosProvider',
      category: LogCategory.video,
    );

    if (likedEventIds.isEmpty) {
      return [];
    }

    // Get video service to check cache
    final videoService = ref.read(videoEventServiceProvider);

    final cachedVideos = <VideoEvent>[];
    final missingIds = <String>[];

    // Check cache first
    for (final eventId in likedEventIds) {
      final cached = videoService.getVideoById(eventId);
      if (cached != null) {
        cachedVideos.add(cached);
      } else {
        missingIds.add(eventId);
      }
    }

    Log.info(
      'ProfileLikedVideos: Found ${cachedVideos.length} in cache, '
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
      cachedVideos.addAll(fetchedVideos);

      Log.info(
        'ProfileLikedVideos: Fetched ${fetchedVideos.length} from relay',
        name: 'ProfileLikedVideosProvider',
        category: LogCategory.video,
      );
    }

    // Sort by like order (most recently liked first)
    // Since likedEventIds is a Set, we use the order from the state
    final orderedVideos = <VideoEvent>[];
    for (final eventId in likedEventIds) {
      final video = cachedVideos.where((v) => v.id == eventId).firstOrNull;
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

    try {
      // Create filter for video events by ID
      // NIP-71 kinds: 34235 (horizontal), 34236 (vertical/short)
      final filter = Filter(ids: eventIds, kinds: [34235, 34236]);

      final eventStream = nostrClient.subscribe([filter]);
      late StreamSubscription<Event> subscription;

      // Set timeout for relay response
      timeoutTimer = Timer(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          subscription.cancel();
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
            timeoutTimer?.cancel();
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
            timeoutTimer?.cancel();
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
      timeoutTimer?.cancel();
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
