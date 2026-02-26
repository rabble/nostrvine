// ABOUTME: Repository for video operations with Nostr.
// ABOUTME: Orchestrates NostrClient for fetching and
// ABOUTME: VideoLocalStorage for caching.
// ABOUTME: Returns Future<List<VideoEvent>>, not streams -
// ABOUTME: loading is pagination-based.

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:videos_repository/src/home_feed_result.dart';
import 'package:videos_repository/src/video_content_filter.dart';
import 'package:videos_repository/src/video_event_filter.dart';
import 'package:videos_repository/src/video_local_storage.dart';

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
/// Optionally accepts a [VideoLocalStorage] for cache-first lookups.
/// When provided, methods like [getVideosByIds] will check the cache first
/// before querying relays.
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
    VideoLocalStorage? localStorage,
    BlockedVideoFilter? blockFilter,
    VideoContentFilter? contentFilter,
    FunnelcakeApiClient? funnelcakeApiClient,
  }) : _nostrClient = nostrClient,
       _localStorage = localStorage,
       _blockFilter = blockFilter,
       _contentFilter = contentFilter,
       _funnelcakeApiClient = funnelcakeApiClient;

  final NostrClient _nostrClient;
  final VideoLocalStorage? _localStorage;
  final BlockedVideoFilter? _blockFilter;
  final VideoContentFilter? _contentFilter;
  final FunnelcakeApiClient? _funnelcakeApiClient;

  /// Fetches videos from followed users for the home feed, optionally
  /// merging in videos from subscribed curated lists.
  ///
  /// This is the "Home" feed mode - shows videos from followed users
  /// plus any videos referenced by subscribed curated lists.
  ///
  /// Strategy:
  /// 1. If [userPubkey] is provided and Funnelcake API is available, tries
  ///    the REST API first (faster, pre-computed feeds)
  /// 2. Falls back to Nostr relay query with [authors] filter
  /// 3. If [videoRefs] is non-empty, fetches list videos and merges them
  ///    with following videos, building attribution metadata
  ///
  /// Parameters:
  /// - [authors]: List of pubkeys to filter by (followed users)
  /// - [videoRefs]: Map of listId → video references from subscribed
  ///   curated lists. References can be 64-char hex event IDs or
  ///   addressable coordinates (`kind:pubkey:d-tag`). Defaults to empty.
  /// - [userPubkey]: The current user's pubkey for Funnelcake API lookups.
  ///   Required for API-first path; when null, goes directly to Nostr.
  /// - [limit]: Maximum number of videos to return (default 5)
  /// - [until]: Only return videos created before this Unix timestamp
  ///   (for pagination - pass `previousVideo.createdAt`)
  ///
  /// Returns a [HomeFeedResult] containing videos sorted by creation time
  /// (newest first) plus attribution metadata mapping videos to their
  /// source curated lists. Returns empty result if [authors] is empty.
  Future<HomeFeedResult> getHomeFeedVideos({
    required List<String> authors,
    Map<String, List<String>> videoRefs = const {},
    String? userPubkey,
    int limit = _defaultLimit,
    int? until,
  }) async {
    if (authors.isEmpty) return const HomeFeedResult(videos: []);

    // 1. Fetch following videos (Funnelcake API → Nostr relay waterfall)
    final followingVideos = await _fetchFollowingVideos(
      authors: authors,
      userPubkey: userPubkey,
      limit: limit,
      until: until,
    );

    // 2. If no list refs, return following-only result
    if (videoRefs.isEmpty) {
      return HomeFeedResult(videos: followingVideos);
    }

    // 3. Merge list videos with following videos
    return _mergeListVideos(
      followingVideos: followingVideos,
      videoRefs: videoRefs,
    );
  }

  /// Fetches videos from followed users via Funnelcake API or Nostr relays.
  Future<List<VideoEvent>> _fetchFollowingVideos({
    required List<String> authors,
    String? userPubkey,
    int limit = _defaultLimit,
    int? until,
  }) async {
    // Try Funnelcake API first (if user pubkey provided)
    if (userPubkey != null &&
        _funnelcakeApiClient != null &&
        _funnelcakeApiClient.isAvailable) {
      try {
        final response = await _funnelcakeApiClient.getHomeFeed(
          pubkey: userPubkey,
          limit: limit,
          before: until,
        );

        final videos = _transformVideoStats(response.videos);
        if (videos.isNotEmpty) return videos;
      } on FunnelcakeException {
        // Fall through to Nostr
      }
    }

    // Nostr fallback
    final filter = Filter(
      kinds: [_videoKind],
      authors: authors,
      limit: limit,
      until: until,
    );

    final events = await _nostrClient.queryEvents([filter]);

    return _transformAndFilter(events);
  }

  /// Merges list videos with following videos and builds attribution.
  ///
  /// Deduplicates videos that appear in both following and lists.
  /// Builds [HomeFeedResult.videoListSources] mapping each list video
  /// to its source lists, and [HomeFeedResult.listOnlyVideoIds] for
  /// videos present only because of list subscriptions.
  ///
  // TODO(curated-list-migration): Optimize by fetching following and list
  // videos in parallel — currently list video fetches wait for following
  // to complete even though they don't depend on each other. Refactor
  // getHomeFeedVideos to launch both concurrently (Phase 3).
  Future<HomeFeedResult> _mergeListVideos({
    required List<VideoEvent> followingVideos,
    required Map<String, List<String>> videoRefs,
  }) async {
    // Build set of following video IDs for dedup (case-insensitive)
    final followingVideoIds = <String>{
      for (final v in followingVideos) v.id.toLowerCase(),
    };

    // Flatten all refs and separate by type
    final eventIds = <String>[];
    final addressableIds = <String>[];

    for (final refs in videoRefs.values) {
      for (final ref in refs) {
        if (ref.contains(':')) {
          addressableIds.add(ref);
        } else {
          eventIds.add(ref);
        }
      }
    }

    // Deduplicate refs
    final uniqueEventIds = eventIds.toSet().toList();
    final uniqueAddressableIds = addressableIds.toSet().toList();

    // Fetch list videos in parallel
    final results = await Future.wait([
      if (uniqueEventIds.isNotEmpty) getVideosByIds(uniqueEventIds),
      if (uniqueAddressableIds.isNotEmpty)
        getVideosByAddressableIds(uniqueAddressableIds),
    ]);

    // Build ref → video lookup
    final refToVideo = <String, VideoEvent>{};
    var resultIndex = 0;

    if (uniqueEventIds.isNotEmpty) {
      for (final video in results[resultIndex]) {
        refToVideo[video.id] = video;
      }
      resultIndex++;
    }
    if (uniqueAddressableIds.isNotEmpty) {
      // getVideosByAddressableIds returns videos in the same order as
      // the input list (omitting not-found). Build a vineId → ref
      // reverse lookup to map fetched videos back to their refs.
      final vineIdToRef = <String, String>{};
      for (final ref in uniqueAddressableIds) {
        final parsed = AId.fromString(ref);
        if (parsed != null) {
          vineIdToRef[parsed.dTag] = ref;
        }
      }
      for (final video in results[resultIndex]) {
        final dTag = video.vineId ?? '';
        final ref = vineIdToRef[dTag];
        if (ref != null) {
          refToVideo[ref] = video;
        }
      }
    }

    // Build attribution metadata
    final videoListSources = <String, Set<String>>{};
    final listOnlyVideoIds = <String>{};
    final listOnlyVideos = <VideoEvent>[];
    final seenListVideoIds = <String>{};

    for (final entry in videoRefs.entries) {
      final listId = entry.key;
      for (final ref in entry.value) {
        final video = refToVideo[ref];
        if (video == null) continue;

        // Track which lists reference this video
        videoListSources.putIfAbsent(video.id, () => <String>{}).add(listId);

        // If not from following, it's list-only
        if (!followingVideoIds.contains(video.id.toLowerCase())) {
          listOnlyVideoIds.add(video.id);

          // Add to merge list (dedup across lists)
          if (seenListVideoIds.add(video.id.toLowerCase())) {
            listOnlyVideos.add(video);
          }
        }
      }
    }

    // Merge following + list-only videos, sorted by createdAt descending
    final merged = [...followingVideos, ...listOnlyVideos]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return HomeFeedResult(
      videos: merged,
      videoListSources: videoListSources,
      listOnlyVideoIds: listOnlyVideoIds,
    );
  }

  /// Fetches videos for a specific curated list.
  ///
  /// Separates [videoRefs] into event IDs and addressable coordinates,
  /// fetches both, and returns videos in the ref order (preserving
  /// the list's ordering).
  ///
  /// Returns an empty list if [videoRefs] is empty or no videos are found.
  Future<List<VideoEvent>> getVideosForList(List<String> videoRefs) async {
    if (videoRefs.isEmpty) return [];

    // Separate refs by type
    final eventIds = <String>[];
    final addressableIds = <String>[];

    for (final ref in videoRefs) {
      if (ref.contains(':')) {
        addressableIds.add(ref);
      } else {
        eventIds.add(ref);
      }
    }

    // Fetch both types in parallel
    final results = await Future.wait([
      if (eventIds.isNotEmpty) getVideosByIds(eventIds),
      if (addressableIds.isNotEmpty) getVideosByAddressableIds(addressableIds),
    ]);

    // Build lookup map: ref → video
    final refToVideo = <String, VideoEvent>{};
    var resultIndex = 0;

    if (eventIds.isNotEmpty) {
      for (final video in results[resultIndex]) {
        refToVideo[video.id] = video;
      }
      resultIndex++;
    }
    if (addressableIds.isNotEmpty) {
      final vineIdToRef = <String, String>{};
      for (final ref in addressableIds) {
        final parsed = AId.fromString(ref);
        if (parsed != null) {
          vineIdToRef[parsed.dTag] = ref;
        }
      }
      for (final video in results[resultIndex]) {
        final dTag = video.vineId ?? '';
        final ref = vineIdToRef[dTag];
        if (ref != null) {
          refToVideo[ref] = video;
        }
      }
    }

    // Return in ref order, omitting unresolved refs
    return [
      for (final ref in videoRefs) ?refToVideo[ref],
    ];
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
  /// Strategy:
  /// 1. If Funnelcake API is available, tries the REST API first (faster)
  /// 2. Falls back to Nostr relay query
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
    // 1. Try Funnelcake API first
    if (_funnelcakeApiClient != null && _funnelcakeApiClient.isAvailable) {
      try {
        final videoStats = await _funnelcakeApiClient.getRecentVideos(
          limit: limit,
          before: until,
        );

        final videos = _transformVideoStats(videoStats);
        if (videos.isNotEmpty) return videos;
      } on FunnelcakeException {
        // Fall through to Nostr
      }
    }

    // 2. Nostr fallback
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
  /// 1. If Funnelcake API is available, tries the REST API first (best
  ///    engagement data from ClickHouse)
  /// 2. Tries NIP-50 `sort:hot` server-side sorting (if relay supports)
  /// 3. Falls back to client-side sorting by engagement score if NIP-50
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
    // 1. Try Funnelcake API first (best engagement data)
    if (_funnelcakeApiClient != null && _funnelcakeApiClient.isAvailable) {
      try {
        final videoStats = await _funnelcakeApiClient.getTrendingVideos(
          limit: limit,
          before: until,
        );

        // Preserve API order (sorted by trending score)
        final videos = _transformVideoStats(
          videoStats,
          sortByCreatedAt: false,
        );
        if (videos.isNotEmpty) return videos;
      } on FunnelcakeException {
        // Fall through to NIP-50
      }
    }

    // 2. Try NIP-50 server-side sorting
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

    // 3. Fallback: relay doesn't support NIP-50, use client-side sorting
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
  /// Implements cache-first lookup:
  /// 1. Check local storage for cached events
  /// 2. Query relays for missing events
  /// 3. Optionally save fetched events to cache
  ///
  /// Parameters:
  /// - [eventIds]: List of event IDs to fetch
  /// - [cacheResults]: If true, saves fetched events to local storage.
  ///   Defaults to false to avoid cache bloat from pagination.
  ///   Set to true for first-page loads that should be cached.
  ///
  /// Returns a list of [VideoEvent] in the same order as [eventIds].
  /// Videos that couldn't be found or failed to parse are omitted.
  Future<List<VideoEvent>> getVideosByIds(
    List<String> eventIds, {
    bool cacheResults = false,
  }) async {
    if (eventIds.isEmpty) return [];

    // Build a map for results
    final eventMap = <String, Event>{};

    // 1. Check cache first (if available)
    if (_localStorage != null) {
      final cachedEvents = await _localStorage.getEventsByIds(eventIds);
      for (final event in cachedEvents) {
        eventMap[event.id] = event;
      }
    }

    // 2. Find missing IDs and query relay
    final missingIds = eventIds
        .where((id) => !eventMap.containsKey(id))
        .toList();

    if (missingIds.isNotEmpty) {
      final filter = Filter(
        ids: missingIds,
        kinds: NIP71VideoKinds.getAllVideoKinds(),
      );

      final relayEvents = await _nostrClient.queryEvents([filter]);

      for (final event in relayEvents) {
        eventMap[event.id] = event;
      }

      // 3. Optionally save fetched events to cache
      if (cacheResults && _localStorage != null && relayEvents.isNotEmpty) {
        await _localStorage.saveEventsBatch(relayEvents);
      }
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
  /// 3. Optionally saves fetched events to local storage
  ///
  /// Parameters:
  /// - [addressableIds]: List of addressable IDs in `kind:pubkey:d-tag` format
  /// - [cacheResults]: If true, saves fetched events to local storage.
  ///   Defaults to false to avoid cache bloat from pagination.
  ///   Set to true for first-page loads that should be cached.
  ///
  /// Returns a list of [VideoEvent] in the same order as [addressableIds].
  /// Videos that couldn't be found or failed to parse are omitted.
  Future<List<VideoEvent>> getVideosByAddressableIds(
    List<String> addressableIds, {
    bool cacheResults = false,
  }) async {
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

    // Optionally save fetched events to cache
    if (cacheResults && _localStorage != null && events.isNotEmpty) {
      await _localStorage.saveEventsBatch(events);
    }

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

  /// Transforms [VideoStats] from Funnelcake API into filtered [VideoEvent]s.
  ///
  /// Converts each [VideoStats] to a [VideoEvent] via [VideoStats.toVideoEvent]
  /// then applies the same filtering pipeline as [_transformAndFilter]:
  /// - Block filter (pubkey blocklist)
  /// - Video URL validation
  /// - Expiration check (NIP-40)
  /// - Content filter (NSFW, etc.)
  ///
  /// By default, sorts by creation time (newest first). Set [sortByCreatedAt]
  /// to false to preserve the API's original order (e.g., trending sort).
  List<VideoEvent> _transformVideoStats(
    List<VideoStats> videoStatsList, {
    bool sortByCreatedAt = true,
  }) {
    final videos = <VideoEvent>[];

    for (final stats in videoStatsList) {
      final video = stats.toVideoEvent();

      // Block filter - check pubkey
      if (_blockFilter?.call(video.pubkey) ?? false) continue;

      // Skip videos without a playable URL
      if (!video.hasVideo) continue;

      // Skip expired videos (NIP-40)
      if (video.isExpired) continue;

      // Content filter - check parsed video (NSFW, etc.)
      if (_contentFilter?.call(video) ?? false) continue;

      videos.add(video);
    }

    if (sortByCreatedAt) {
      videos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return videos;
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

  /// Fetches videos where [taggedPubkey] appears in a p-tag.
  ///
  /// Uses Funnelcake REST API when available, with Nostr
  /// relay p-tag query as fallback.
  ///
  /// The caller should client-side filter results to confirm
  /// collaborator status (pubkey != event author).
  Future<List<VideoEvent>> getCollabVideos({
    required String taggedPubkey,
    int limit = _defaultLimit,
    int? until,
  }) async {
    // Try Funnelcake REST API first
    if (_funnelcakeApiClient != null && _funnelcakeApiClient.isAvailable) {
      try {
        final stats = await _funnelcakeApiClient.getCollabVideos(
          pubkey: taggedPubkey,
          limit: limit,
          before: until,
        );
        if (stats.isNotEmpty) {
          return stats
              .map((s) => s.toVideoEvent())
              .where((v) => v.hasVideo)
              .where((v) => !v.isExpired)
              .where((v) => !(_blockFilter?.call(v.pubkey) ?? false))
              .where((v) => !(_contentFilter?.call(v) ?? false))
              .toList();
        }
      } on FunnelcakeException {
        // Fall through to relay query
      }
    }

    // Fallback: Nostr relay p-tag query
    final filter = Filter(
      kinds: [_videoKind],
      p: [taggedPubkey],
      limit: limit,
      until: until,
    );
    final events = await _nostrClient.queryEvents([filter]);
    return _transformAndFilter(events);
  }

  /// Fetches videos sorted by loop count (most looped first).
  ///
  /// Returns empty list if Funnelcake API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<List<VideoEvent>> getVideosByLoops({
    int limit = 20,
    int? before,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return [];
    }
    final stats = await _funnelcakeApiClient.getVideosByLoops(
      limit: limit,
      before: before,
    );
    return _transformVideoStats(stats, sortByCreatedAt: false);
  }

  /// Fetches videos for a specific hashtag.
  ///
  /// Returns empty list if Funnelcake API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<List<VideoEvent>> getVideosByHashtag({
    required String hashtag,
    int limit = 20,
    int? before,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return [];
    }
    final stats = await _funnelcakeApiClient.getVideosByHashtag(
      hashtag: hashtag,
      limit: limit,
      before: before,
    );
    return _transformVideoStats(stats, sortByCreatedAt: false);
  }

  /// Fetches classic videos (pre-Nostr) for a specific hashtag.
  ///
  /// Returns empty list if Funnelcake API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<List<VideoEvent>> getClassicVideosByHashtag({
    required String hashtag,
    int limit = 20,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return [];
    }
    final stats = await _funnelcakeApiClient.getClassicVideosByHashtag(
      hashtag: hashtag,
      limit: limit,
    );
    return _transformVideoStats(stats, sortByCreatedAt: false);
  }

  /// Searches videos by text query.
  ///
  /// Returns empty list if Funnelcake API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<List<VideoEvent>> searchVideos({
    required String query,
    int limit = 20,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return [];
    }
    final stats = await _funnelcakeApiClient.searchVideos(
      query: query,
      limit: limit,
    );
    return _transformVideoStats(stats, sortByCreatedAt: false);
  }

  /// Fetches classic Vine videos (pre-Nostr archive).
  ///
  /// Returns empty list if Funnelcake API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<List<VideoEvent>> getClassicVines({
    String sort = 'popular',
    int limit = 20,
    int? offset,
    int? before,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return [];
    }
    final stats = await _funnelcakeApiClient.getClassicVines(
      sort: sort,
      limit: limit,
      offset: offset ?? 0,
      before: before,
    );
    return _transformVideoStats(stats, sortByCreatedAt: false);
  }

  /// Fetches videos by a specific author from the Funnelcake API.
  ///
  /// Returns empty list if Funnelcake API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<List<VideoEvent>> getVideosByAuthor({
    required String pubkey,
    int limit = 20,
    int? before,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return [];
    }
    final stats = await _funnelcakeApiClient.getVideosByAuthor(
      pubkey: pubkey,
      limit: limit,
      before: before,
    );
    return _transformVideoStats(stats);
  }

  /// Fetches stats for a single video.
  ///
  /// Returns null if Funnelcake API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<VideoStats?> getVideoStats(String eventId) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return null;
    }
    return _funnelcakeApiClient.getVideoStats(eventId);
  }

  /// Fetches view count for a single video.
  ///
  /// Returns null if Funnelcake API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<int?> getVideoViews(String eventId) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return null;
    }
    return _funnelcakeApiClient.getVideoViews(eventId);
  }

  /// Fetches bulk video stats for multiple event IDs.
  ///
  /// Returns null if Funnelcake API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<BulkVideoStatsResponse?> getBulkVideoStats(
    List<String> eventIds,
  ) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return null;
    }
    return _funnelcakeApiClient.getBulkVideoStats(eventIds);
  }

  /// Fetches personalized video recommendations.
  ///
  /// Returns null if Funnelcake API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<RecommendationsResponse?> getRecommendations({
    required String pubkey,
    int limit = 20,
    String fallback = 'popular',
    String? category,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return null;
    }
    return _funnelcakeApiClient.getRecommendations(
      pubkey: pubkey,
      limit: limit,
      fallback: fallback,
      category: category,
    );
  }
}
