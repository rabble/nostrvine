// ABOUTME: Repository for video operations with Nostr.
// ABOUTME: Orchestrates NostrClient for fetching and
// ABOUTME: VideoLocalStorage for caching.
// ABOUTME: Returns Future<List<VideoEvent>>, not streams -
// ABOUTME: loading is pagination-based.

import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

export 'package:models/src/nip71_video_kinds.dart' show NIP71VideoKinds;

/// NIP-71 video event kind for addressable short videos.
const int _videoKind = EventKind.videoVertical;

/// Default number of videos to fetch per page.
/// Kept small to stay "a couple videos ahead" in the buffer.
const int _defaultLimit = 5;

/// {@template videos_repository}
/// Repository for video operations with Nostr.
///
/// Coordinates between NostrClient (relay I/O) and local storage for
/// efficient video feed loading. Uses pagination-based loading (Futures)
/// rather than real-time subscriptions (Streams).
///
/// {@endtemplate}
class VideosRepository {
  /// {@macro videos_repository}
  const VideosRepository({
    required NostrClient nostrClient,
  }) : _nostrClient = nostrClient;

  final NostrClient _nostrClient;

  /// Fetches videos from followed users for the home feed.
  ///
  /// This is the "Home" feed mode - shows videos only from users the
  /// current user follows.
  ///
  /// Parameters:
  /// - [authors]: List of pubkeys to filter by (followed users)
  /// - [limit]: Maximum number of videos to return (default 5)
  /// - [until]: Only return videos created before this Unix timestamp
  ///   (for pagination - pass `previousVideo.createdAt`)
  ///
  /// Returns a list of [VideoEvent] sorted by creation time (newest first).
  /// Returns an empty list if [authors] is empty, no videos are found,
  /// or on error.
  Future<List<VideoEvent>> getHomeFeedVideos({
    required List<String> authors,
    int limit = _defaultLimit,
    int? until,
  }) async {
    if (authors.isEmpty) return [];

    final filter = Filter(
      kinds: [_videoKind],
      authors: authors,
      limit: limit,
      until: until,
    );

    final events = await _nostrClient.queryEvents([filter]);

    return _transformAndFilter(events);
  }

  /// Fetches the latest videos in chronological order (newest first).
  ///
  /// This is the "New" feed mode - shows all public videos sorted by
  /// creation time.
  ///
  /// Parameters:
  /// - [limit]: Maximum number of videos to return (default 5)
  /// - [until]: Only return videos created before this Unix timestamp
  ///   (for pagination - pass `previousVideo.createdAt`)
  ///
  /// Returns a list of [VideoEvent] sorted by creation time (newest first).
  /// Returns an empty list if no videos are found or on error.
  Future<List<VideoEvent>> getNewVideos({
    int limit = _defaultLimit,
    int? until,
  }) async {
    final filter = Filter(
      kinds: [_videoKind],
      limit: limit,
      until: until,
    );

    final events = await _nostrClient.queryEvents([filter]);

    return _transformAndFilter(events);
  }

  /// Fetches popular videos sorted by engagement score.
  ///
  /// This is the "Popular" feed mode - shows videos ranked by their
  /// engagement metrics (loops, likes, comments, reposts).
  ///
  /// Since Nostr relays don't support sorting by custom fields, this method:
  /// 1. Fetches a larger batch of recent videos
  /// 2. Sorts them client-side by engagement score
  /// 3. Returns the top [limit] results
  ///
  /// Parameters:
  /// - [limit]: Maximum number of videos to return (default 5)
  /// - [until]: Only return videos created before this Unix timestamp
  ///   (for pagination)
  /// - [fetchMultiplier]: How many more videos to fetch for sorting
  ///   (default 4x, so limit=5 fetches 20 videos to sort)
  ///
  /// Returns a list of [VideoEvent] sorted by engagement score (highest first).
  /// Returns an empty list if no videos are found or on error.
  Future<List<VideoEvent>> getPopularVideos({
    int limit = _defaultLimit,
    int? until,
    int fetchMultiplier = 4,
  }) async {
    // Fetch more videos than needed so we have a good pool to sort from
    final fetchLimit = limit * fetchMultiplier;

    final filter = Filter(
      kinds: [_videoKind],
      limit: fetchLimit,
      until: until,
    );

    final events = await _nostrClient.queryEvents([filter]);

    final videos = _transformAndFilter(events)
      // Sort by engagement score (uses VideoEvent's built-in comparator)
      ..sort(VideoEvent.compareByEngagementScore);

    // Return only the requested limit
    return videos.take(limit).toList();
  }

  /// Transforms raw Nostr events to VideoEvents and filters invalid ones.
  ///
  /// - Parses events using [VideoEvent.fromNostrEvent]
  /// - Filters out videos without a valid video URL
  /// - Filters out expired videos (NIP-40)
  /// - Sorts by creation time (newest first) for consistent ordering
  List<VideoEvent> _transformAndFilter(List<Event> events) {
    final videos = <VideoEvent>[];

    for (final event in events) {
      // Skip events that aren't valid video kinds
      if (!NIP71VideoKinds.isVideoKind(event.kind)) continue;

      final video = VideoEvent.fromNostrEvent(event);

      // Skip videos without a playable URL
      if (!video.hasVideo) continue;

      // Skip expired videos (NIP-40)
      if (video.isExpired) continue;

      videos.add(video);
    }

    // Sort by creation time (newest first)
    videos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return videos;
  }
}
