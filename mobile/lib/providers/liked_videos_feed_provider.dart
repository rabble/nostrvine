// ABOUTME: Provider for liked videos feed state used by active video tracking
// ABOUTME: Watches LikesRepository directly and fetches videos for liked IDs

import 'dart:async';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'liked_videos_feed_provider.g.dart';

/// Provider that returns liked videos as VideoFeedState for route-based video
/// tracking.
///
/// This provider:
/// 1. Watches LikesRepository for the list of liked event IDs
/// 2. Fetches video data from cache and relays
/// 3. Returns VideoFeedState for use by active_video_provider
@riverpod
Future<VideoFeedState> likedVideosFeed(Ref ref) async {
  final likesRepository = ref.watch(likesRepositoryProvider);

  // If not authenticated, return empty state
  if (likesRepository == null) {
    return const VideoFeedState(
      videos: [],
      hasMoreContent: false,
      isLoadingMore: false,
    );
  }

  // Get ordered liked event IDs from repository
  final orderedLikedEventIds = await likesRepository.getOrderedLikedEventIds();

  Log.info(
    'LikedVideosFeed: Building with ${orderedLikedEventIds.length} liked IDs',
    name: 'LikedVideosFeedProvider',
    category: LogCategory.video,
  );

  if (orderedLikedEventIds.isEmpty) {
    return const VideoFeedState(
      videos: [],
      hasMoreContent: false,
      isLoadingMore: false,
    );
  }

  // Fetch videos for the liked event IDs
  final videoService = ref.read(videoEventServiceProvider);
  final nostrClient = ref.read(nostrServiceProvider);

  final videos = await _fetchVideos(
    videoService,
    nostrClient,
    orderedLikedEventIds,
  );

  Log.info(
    'LikedVideosFeed: Returning ${videos.length} videos',
    name: 'LikedVideosFeedProvider',
    category: LogCategory.video,
  );

  return VideoFeedState(
    videos: videos,
    hasMoreContent: false,
    isLoadingMore: false,
    lastUpdated: DateTime.now(),
  );
}

/// Fetch videos for the given event IDs.
///
/// 1. Check cache first
/// 2. Fetch missing videos from relays
/// 3. Return ordered list matching the input order
Future<List<VideoEvent>> _fetchVideos(
  dynamic videoService,
  NostrClient nostrClient,
  List<String> likedEventIds,
) async {
  final cachedVideosMap = <String, VideoEvent>{};
  final missingIds = <String>[];

  // Check cache first
  for (final eventId in likedEventIds) {
    final cached = videoService.getVideoById(eventId) as VideoEvent?;
    if (cached != null) {
      cachedVideosMap[eventId] = cached;
    } else {
      missingIds.add(eventId);
    }
  }

  Log.info(
    'LikedVideosFeed: Found ${cachedVideosMap.length} in cache, '
    '${missingIds.length} need relay fetch',
    name: 'LikedVideosFeedProvider',
    category: LogCategory.video,
  );

  // Fetch missing videos from relays
  if (missingIds.isNotEmpty) {
    final fetchedVideos = await _fetchVideosFromRelay(nostrClient, missingIds);
    for (final video in fetchedVideos) {
      cachedVideosMap[video.id] = video;
    }

    Log.info(
      'LikedVideosFeed: Fetched ${fetchedVideos.length} from relay',
      name: 'LikedVideosFeedProvider',
      category: LogCategory.video,
    );
  }

  // Build ordered list using the recency-ordered IDs
  final orderedVideos = <VideoEvent>[];
  for (final eventId in likedEventIds) {
    final video = cachedVideosMap[eventId];
    if (video != null) {
      orderedVideos.add(video);
    }
  }

  // Filter out unsupported videos (WebM on iOS/macOS)
  return orderedVideos.where((v) => v.isSupportedOnCurrentPlatform).toList();
}

/// Fetch videos from relays by their event IDs.
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
      'liked_videos_feed_${DateTime.now().millisecondsSinceEpoch}';

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
            'LikedVideosFeed: Failed to parse event ${event.id}: $e',
            name: 'LikedVideosFeedProvider',
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
          'LikedVideosFeed: Stream error: $error',
          name: 'LikedVideosFeedProvider',
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
      'LikedVideosFeed: Failed to fetch from relay: $e',
      name: 'LikedVideosFeedProvider',
      category: LogCategory.video,
    );
    await cleanup();
    return videos;
  }
}
