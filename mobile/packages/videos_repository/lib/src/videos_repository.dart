// ABOUTME: Repository for video operations with Nostr.
// ABOUTME: Orchestrates NostrClient for fetching and
// ABOUTME: VideoLocalStorage for caching.
// ABOUTME: Returns Future<List<VideoEvent>>, not streams -
// ABOUTME: loading is pagination-based.

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:videos_repository/src/video_content_filter.dart';
import 'package:videos_repository/src/video_event_filter.dart';

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
/// Optionally accepts a [FunnelcakeApiClient] to fallback to REST API
/// for videos not found on Nostr relays (e.g., videos from Explore that
/// may not be on the app's configured relays).
///
/// {@endtemplate}
class VideosRepository {
  /// {@macro videos_repository}
  const VideosRepository({
    required NostrClient nostrClient,
    BlockedVideoFilter? blockFilter,
    VideoContentFilter? contentFilter,
    FunnelcakeApiClient? funnelcakeApiClient,
  }) : _nostrClient = nostrClient,
       _blockFilter = blockFilter,
       _contentFilter = contentFilter,
       _funnelcakeApiClient = funnelcakeApiClient;

  final NostrClient _nostrClient;
  final BlockedVideoFilter? _blockFilter;
  final VideoContentFilter? _contentFilter;
  final FunnelcakeApiClient? _funnelcakeApiClient;

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

  /// Fetches videos published by a specific author.
  ///
  /// This is for profile pages - shows all videos from a single user
  /// sorted by creation time (newest first).
  ///
  /// Parameters:
  /// - [authorPubkey]: The pubkey of the user whose videos to fetch
  /// - [limit]: Maximum number of videos to return (default 5)
  /// - [until]: Only return videos created before this Unix timestamp
  ///   (for pagination - pass `previousVideo.createdAt`)
  ///
  /// Returns a list of [VideoEvent] sorted by creation time (newest first).
  /// Returns an empty list if no videos are found or on error.
  Future<List<VideoEvent>> getProfileVideos({
    required String authorPubkey,
    int limit = _defaultLimit,
    int? until,
  }) async {
    final filter = Filter(
      kinds: [_videoKind],
      authors: [authorPubkey],
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
  /// Strategy:
  /// 1. First tries NIP-50 `sort:hot` server-side sorting (if relay supports)
  /// 2. Falls back to client-side sorting by engagement score if NIP-50
  ///    returns empty (relay doesn't support NIP-50)
  ///
  /// Parameters:
  /// - [limit]: Maximum number of videos to return (default 5)
  /// - [until]: Only return videos created before this Unix timestamp
  ///   (for pagination)
  /// - [fetchMultiplier]: How many more videos to fetch for client-side sorting
  ///   fallback (default 4x, so limit=5 fetches 20 videos to sort)
  ///
  /// Returns a list of [VideoEvent] sorted by engagement/popularity
  /// (highest first).
  /// Returns an empty list if no videos are found or on error.
  Future<List<VideoEvent>> getPopularVideos({
    int limit = _defaultLimit,
    int? until,
    int fetchMultiplier = 4,
  }) async {
    // 1. Try NIP-50 server-side sorting first
    final nip50Filter = Filter(
      kinds: [_videoKind],
      limit: limit,
      until: until,
      search: 'sort:hot', // NIP-50 sort by engagement
    );

    final nip50Events = await _nostrClient.queryEvents(
      [nip50Filter],
      useCache: false, // Relay ordering is source of truth
    );

    if (nip50Events.isNotEmpty) {
      // NIP-50 worked - relay returned sorted results
      // Preserve relay order (don't re-sort by createdAt)
      return _transformAndFilter(nip50Events, sortByCreatedAt: false);
    }

    // 2. Fallback: relay doesn't support NIP-50, use client-side sorting
    // Fetch more videos than needed so we have a good pool to sort from
    final fetchLimit = limit * fetchMultiplier;

    final fallbackFilter = Filter(
      kinds: [_videoKind],
      limit: fetchLimit,
      until: until,
    );

    final events = await _nostrClient.queryEvents(
      [fallbackFilter],
    );

    final videos = _transformAndFilter(events)
      // Sort by engagement score (uses VideoEvent's built-in comparator)
      ..sort(VideoEvent.compareByEngagementScore);

    // Return only the requested limit
    return videos.take(limit).toList();
  }

  /// Fetches videos by their event IDs.
  ///
  /// This is used for fetching videos that a user has liked (Kind 7 reactions
  /// reference videos by their event ID).
  ///
  /// Parameters:
  /// - [eventIds]: List of event IDs to fetch
  ///
  /// Returns a list of [VideoEvent] in the same order as [eventIds].
  /// Videos that couldn't be found or failed to parse are omitted.
  Future<List<VideoEvent>> getVideosByIds(List<String> eventIds) async {
    if (eventIds.isEmpty) return [];

    final filter = Filter(
      ids: eventIds,
      kinds: NIP71VideoKinds.getAllVideoKinds(),
    );

    final events = await _nostrClient.queryEvents([filter]);

    // Build a map for ordering
    final eventMap = <String, Event>{};
    for (final event in events) {
      eventMap[event.id] = event;
    }

    // Transform and filter, preserving input order
    final videos = <VideoEvent>[];
    for (final id in eventIds) {
      final event = eventMap[id];
      if (event == null) continue;

      final video = _tryParseAndFilter(event);
      if (video != null) videos.add(video);
    }

    return videos;
  }

  /// Number of filters to batch in a single relay query.
  ///
  /// Batching improves performance while staying compatible with relays
  /// that may have issues with too many filters in one REQ.
  static const int _addressableIdBatchSize = 20;

  /// Fetches videos by their addressable IDs.
  ///
  /// Addressable IDs follow the format: `kind:pubkey:d-tag`
  /// This is used for fetching videos that a user has reposted (Kind 16
  /// generic reposts reference addressable events via the 'a' tag).
  ///
  /// Strategy:
  /// 1. First tries Nostr relays via NostrClient
  /// 2. For videos not found on relays, tries Funnelcake REST API fallback
  ///    (if configured) - useful for videos from Explore that may not be
  ///    on the app's configured relays
  ///
  /// Parameters:
  /// - [addressableIds]: List of addressable IDs in `kind:pubkey:d-tag` format
  ///
  /// Returns a list of [VideoEvent] in the same order as [addressableIds].
  /// Videos that couldn't be found or failed to parse are omitted.
  Future<List<VideoEvent>> getVideosByAddressableIds(
    List<String> addressableIds,
  ) async {
    if (addressableIds.isEmpty) return [];

    // Parse addressable IDs and build filters
    final filters = <Filter>[];

    for (final addressableId in addressableIds) {
      final parsed = AId.fromString(addressableId);
      if (parsed != null && NIP71VideoKinds.isVideoKind(parsed.kind)) {
        // Note: No limit needed - addressable events are unique by
        // kind:pubkey:d-tag, so there's only one latest version per ID.
        // Adding limit:1 per filter causes issues when batching multiple
        // filters, as relays may apply a global limit.
        filters.add(
          Filter(
            kinds: [parsed.kind],
            authors: [parsed.pubkey],
            d: [parsed.dTag],
          ),
        );
      }
    }

    if (filters.isEmpty) return [];

    // Batch filters to balance performance with relay compatibility.
    // Some relays have issues with too many filters in a single REQ,
    // so we batch them in chunks rather than sending all at once or
    // querying one at a time.
    final futures = <Future<List<Event>>>[];
    for (var i = 0; i < filters.length; i += _addressableIdBatchSize) {
      final batchEnd = (i + _addressableIdBatchSize).clamp(0, filters.length);
      final batch = filters.sublist(i, batchEnd);
      futures.add(_nostrClient.queryEvents(batch));
    }

    final results = await Future.wait(futures);
    final events = results.expand((e) => e).toList();

    // Build a map keyed by addressable ID for ordering
    final foundVideos = <String, VideoEvent>{};
    for (final event in events) {
      final dTag = event.dTagValue;
      if (dTag.isNotEmpty) {
        final addressableId = '${event.kind}:${event.pubkey}:$dTag';
        final video = _tryParseAndFilter(event);
        if (video != null) {
          foundVideos[addressableId] = video;
        }
      }
    }

    // Find which IDs weren't found on Nostr
    final missingIds = addressableIds
        .where((id) => !foundVideos.containsKey(id))
        .toList();

    // Try Funnelcake API fallback for missing videos
    if (missingIds.isNotEmpty &&
        _funnelcakeApiClient != null &&
        _funnelcakeApiClient.isAvailable) {
      await _fetchMissingVideosFromFunnelcake(missingIds, foundVideos);
    }

    // Build result list preserving original order
    final videos = <VideoEvent>[];
    for (final addressableId in addressableIds) {
      final video = foundVideos[addressableId];
      if (video != null) {
        videos.add(video);
      }
    }

    return videos;
  }

  /// Fetches missing videos from Funnelcake API and adds them to [foundVideos].
  ///
  /// Groups missing IDs by author pubkey to batch API requests.
  Future<void> _fetchMissingVideosFromFunnelcake(
    List<String> missingIds,
    Map<String, VideoEvent> foundVideos,
  ) async {
    // Group missing IDs by pubkey to batch queries
    final missingByPubkey = <String, List<String>>{};
    for (final addressableId in missingIds) {
      final parsed = AId.fromString(addressableId);
      if (parsed != null) {
        missingByPubkey.putIfAbsent(parsed.pubkey, () => []).add(parsed.dTag);
      }
    }

    // Query Funnelcake API for each author's videos
    for (final entry in missingByPubkey.entries) {
      final pubkey = entry.key;
      final dTags = entry.value.toSet();

      try {
        // Fetch videos by author from Funnelcake API
        final authorVideoStats = await _funnelcakeApiClient!.getVideosByAuthor(
          pubkey: pubkey,
          limit: 100,
        );

        // Find videos matching our d-tags and convert to VideoEvent
        for (final videoStats in authorVideoStats) {
          final video = videoStats.toVideoEvent();
          if (video.vineId != null && dTags.contains(video.vineId)) {
            final videoAddressableId = AId(
              kind: EventKind.videoVertical,
              pubkey: video.pubkey,
              dTag: video.vineId!,
            ).toAString();

            // Apply content filter if configured
            if (_blockFilter?.call(video.pubkey) ?? false) continue;
            if (!video.hasVideo) continue;
            if (video.isExpired) continue;
            if (_contentFilter?.call(video) ?? false) continue;

            foundVideos[videoAddressableId] = video;
          }
        }
      } on FunnelcakeException {
        // Silently ignore Funnelcake API failures - this is a fallback,
        // so we don't want to fail the whole operation if it doesn't work.
        // The video simply won't be included in the results.
      }
    }
  }

  /// Attempts to parse an event into a VideoEvent and apply filters.
  ///
  /// Returns the [VideoEvent] if it passes all filters, or null if:
  /// - The event kind is not a video kind
  /// - The pubkey is blocked
  /// - The video has no playable URL
  /// - The video is expired (NIP-40)
  /// - The video fails content filtering
  VideoEvent? _tryParseAndFilter(Event event) {
    // Skip events that aren't valid video kinds
    if (!NIP71VideoKinds.isVideoKind(event.kind)) return null;

    // Block filter - check pubkey before parsing for efficiency
    if (_blockFilter?.call(event.pubkey) ?? false) return null;

    final video = VideoEvent.fromNostrEvent(event);

    // Skip videos without a playable URL
    if (!video.hasVideo) return null;

    // Skip expired videos (NIP-40)
    if (video.isExpired) return null;

    // Content filter - check parsed video (NSFW, etc.)
    if (_contentFilter?.call(video) ?? false) return null;

    return video;
  }

  /// Transforms raw Nostr events to VideoEvents and filters invalid ones.
  ///
  /// Applies two-stage filtering:
  /// 1. [_blockFilter] - pubkey-based filtering (blocklist/mutes) BEFORE
  ///    parsing for efficiency
  /// 2. [_contentFilter] - content-based filtering (NSFW, etc.) AFTER
  ///    parsing when video metadata is available
  ///
  /// Also:
  /// - Applies content filter (blocklist/mutes) if configured
  /// - Parses events using [VideoEvent.fromNostrEvent]
  /// - Filters out videos without a valid video URL
  /// - Filters out expired videos (NIP-40)
  /// - Sorts by creation time (newest first) by default, unless
  ///   [sortByCreatedAt] is false (e.g., for NIP-50 results where
  ///   relay order should be preserved)
  List<VideoEvent> _transformAndFilter(
    List<Event> events, {
    bool sortByCreatedAt = true,
  }) {
    final videos = <VideoEvent>[];

    for (final event in events) {
      final video = _tryParseAndFilter(event);
      if (video != null) videos.add(video);
    }

    // Sort by creation time (newest first) unless preserving relay order
    if (sortByCreatedAt) {
      videos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return videos;
  }
}
