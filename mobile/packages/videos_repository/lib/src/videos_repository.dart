// ABOUTME: Repository for video operations with Nostr.
// ABOUTME: Orchestrates NostrClient for fetching and
// ABOUTME: VideoLocalStorage for caching.
// ABOUTME: Returns Future<List<VideoEvent>>, not streams -
// ABOUTME: loading is pagination-based.

import 'dart:developer' as developer;

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:videos_repository/src/home_feed_result.dart';
import 'package:videos_repository/src/in_memory_feed_cache.dart';
import 'package:videos_repository/src/video_content_filter.dart';
import 'package:videos_repository/src/video_event_filter.dart';
import 'package:videos_repository/src/video_local_storage.dart';

export 'package:models/src/nip71_video_kinds.dart' show NIP71VideoKinds;

/// NIP-71 video event kind for addressable short videos.
const int _videoKind = EventKind.videoVertical;

/// Default number of videos to fetch per page.
/// Kept small to stay "a couple videos ahead" in the buffer.
const int _defaultLimit = 5;

/// Timeout for relay search queries.
///
/// Set higher than the app-wide 5s default to accommodate slower
/// user-configured personal relays.
const Duration _relaySearchTimeout = Duration(seconds: 15);

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
    VideoWarningLabelsResolver? warningLabelsResolver,
    FunnelcakeApiClient? funnelcakeApiClient,
    InMemoryFeedCache? inMemoryFeedCache,
  }) : _nostrClient = nostrClient,
       _localStorage = localStorage,
       _blockFilter = blockFilter,
       _contentFilter = contentFilter,
       _warningLabelsResolver = warningLabelsResolver,
       _funnelcakeApiClient = funnelcakeApiClient,
       _inMemoryFeedCache = inMemoryFeedCache;

  final NostrClient _nostrClient;
  final VideoLocalStorage? _localStorage;
  final BlockedVideoFilter? _blockFilter;
  final VideoContentFilter? _contentFilter;
  final VideoWarningLabelsResolver? _warningLabelsResolver;
  final FunnelcakeApiClient? _funnelcakeApiClient;
  final InMemoryFeedCache? _inMemoryFeedCache;

  /// Clears the in-memory feed cache.
  ///
  /// When [key] is provided, only that feed mode's cache is removed
  /// (e.g. `"home"`, `"latest"`, `"popular"`). When omitted, all
  /// cached feeds are cleared.
  void clearInMemoryFeedCache({String? key}) {
    if (key != null) {
      _inMemoryFeedCache?.remove(key);
    } else {
      _inMemoryFeedCache?.clear();
    }
  }

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
  /// source curated lists. Returns empty result if both [authors] is empty
  /// and [userPubkey] is null. When [userPubkey] is provided, the Funnelcake
  /// API is attempted even with an empty [authors] list (fast-path startup).
  Future<HomeFeedResult> getHomeFeedVideos({
    required List<String> authors,
    Map<String, List<String>> videoRefs = const {},
    String? userPubkey,
    int limit = _defaultLimit,
    int? until,
    bool skipCache = false,
  }) async {
    if (authors.isEmpty && userPubkey == null) {
      return const HomeFeedResult(videos: []);
    }

    // Return in-memory cached result when available (initial page only).
    if (!skipCache && until == null) {
      final cached = _inMemoryFeedCache?.get('home');
      if (cached != null) return cached;
    }

    // 1. Fetch following videos (Funnelcake API → Nostr relay waterfall)
    final (:videos, :rawBody) = await _fetchFollowingVideos(
      authors: authors,
      userPubkey: userPubkey,
      limit: limit,
      until: until,
    );

    // 2. If no list refs, return following-only result
    if (videoRefs.isEmpty) {
      final result = HomeFeedResult(videos: videos, rawResponseBody: rawBody);
      if (until == null) _inMemoryFeedCache?.set('home', result);
      return result;
    }

    // 3. Merge list videos with following videos
    final result = await _mergeListVideos(
      followingVideos: videos,
      videoRefs: videoRefs,
    );
    if (until == null) _inMemoryFeedCache?.set('home', result);
    return result;
  }

  /// Fetches videos from followed users via Funnelcake API or Nostr relays.
  ///
  /// Returns a record with the videos and the raw JSON response body
  /// (when available from Funnelcake initial page) for cache-first loading.
  Future<({List<VideoEvent> videos, String? rawBody})> _fetchFollowingVideos({
    required List<String> authors,
    String? userPubkey,
    int limit = _defaultLimit,
    int? until,
  }) async {
    final effectiveUserPubkey =
        userPubkey ??
        (_nostrClient.publicKey.isNotEmpty ? _nostrClient.publicKey : null);

    // Try Funnelcake API first (if user pubkey provided)
    if (effectiveUserPubkey != null &&
        _funnelcakeApiClient != null &&
        _funnelcakeApiClient.isAvailable) {
      try {
        final response = await _funnelcakeApiClient.getHomeFeed(
          pubkey: effectiveUserPubkey,
          limit: limit,
          before: until,
        );

        final videos = _transformVideoStats(response.videos);
        final hydratedVideos = await _hydrateVideosWithBulkStats(videos);
        return (videos: hydratedVideos, rawBody: response.rawBody);
      } on FunnelcakeException {
        // Fall through to Nostr
      }
    }

    // Nostr fallback — skip when authors list is empty (fast-path startup
    // before follow list is ready).
    if (authors.isEmpty) return (videos: <VideoEvent>[], rawBody: null);

    final filter = Filter(
      kinds: [_videoKind],
      authors: authors,
      limit: limit,
      until: until,
    );

    final events = await _nostrClient.queryEvents([filter]);

    final videos = _transformAndFilter(events);
    final hydratedVideos = await _hydrateVideosWithBulkStats(videos);
    return (videos: hydratedVideos, rawBody: null);
  }

  Future<List<VideoEvent>> _hydrateVideosWithBulkStats(
    List<VideoEvent> videos,
  ) async {
    if (videos.isEmpty ||
        _funnelcakeApiClient == null ||
        !_funnelcakeApiClient.isAvailable) {
      return videos;
    }

    final videosNeedingStats = videos
        .where(
          (video) =>
              video.id.isNotEmpty &&
              (video.originalLoops == null ||
                  video.rawTags['views'] == null ||
                  video.originalLikes == null ||
                  video.originalComments == null ||
                  video.originalReposts == null ||
                  video.nostrLikeCount == null),
        )
        .toList();
    if (videosNeedingStats.isEmpty) return videos;

    try {
      final statsById = <String, BulkVideoStatsEntry>{};
      for (var i = 0; i < videosNeedingStats.length; i += 100) {
        final end = i + 100 > videosNeedingStats.length
            ? videosNeedingStats.length
            : i + 100;
        final chunk = videosNeedingStats.sublist(i, end);
        final response = await _funnelcakeApiClient.getBulkVideoStats(
          chunk.map((video) => video.id).toList(),
        );
        statsById.addAll(response.stats);
      }

      if (statsById.isEmpty) return videos;

      return videos.map((video) {
        final stats = statsById[video.id];
        if (stats == null) return video;

        return video.copyWith(
          originalLoops: stats.loops ?? video.originalLoops,
          originalLikes: video.originalLikes ?? stats.reactions,
          originalComments: video.originalComments ?? stats.comments,
          originalReposts: video.originalReposts ?? stats.reposts,
          // REST reaction totals already include the Nostr portion for the
          // fullscreen entry paths that rely on this hydration. Seeding
          // nostrLikeCount to 0 preserves totalLikes while still telling the
          // interactions bloc it has an initial count to display.
          nostrLikeCount: video.nostrLikeCount ?? 0,
          rawTags: video.rawTags['views'] == null && stats.views != null
              ? {...video.rawTags, 'views': stats.views.toString()}
              : video.rawTags,
        );
      }).toList();
    } on Object catch (e, stackTrace) {
      developer.log(
        'Failed to hydrate home feed videos with bulk stats',
        name: 'VideosRepository',
        error: e,
        stackTrace: stackTrace,
      );
      return videos;
    }
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
    return [for (final ref in videoRefs) ?refToVideo[ref]];
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
    bool skipCache = false,
  }) async {
    // Return in-memory cached result when available (initial page only).
    if (!skipCache && until == null) {
      final cached = _inMemoryFeedCache?.get('latest');
      if (cached != null) return cached.videos;
    }

    // 1. Try Funnelcake API first
    if (_funnelcakeApiClient != null && _funnelcakeApiClient.isAvailable) {
      try {
        final videoStats = await _funnelcakeApiClient.getRecentVideos(
          limit: limit,
          before: until,
        );

        final videos = _transformVideoStats(videoStats);
        if (until == null) {
          _inMemoryFeedCache?.set('latest', HomeFeedResult(videos: videos));
        }
        return videos;
      } on FunnelcakeException {
        // Fall through to Nostr
      }
    }

    // 2. Nostr fallback
    final filter = Filter(kinds: [_videoKind], limit: limit, until: until);

    final events = await _nostrClient.queryEvents([filter]);

    final videos = _transformAndFilter(events);
    if (until == null) {
      _inMemoryFeedCache?.set('latest', HomeFeedResult(videos: videos));
    }
    return videos;
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
    bool skipCache = false,
  }) async {
    // Return in-memory cached result when available (initial page only).
    if (!skipCache && until == null) {
      final cached = _inMemoryFeedCache?.get('popular');
      if (cached != null) return cached.videos;
    }

    // 1. Try Funnelcake API first (best engagement data).
    // Popular tab uses sort=watching (24h CDN view count, no age decay):
    // surfaces what people are looking at right now, including classic
    // Vines getting current attention — not all-time loop count or
    // trending engagement score.
    if (_funnelcakeApiClient != null && _funnelcakeApiClient.isAvailable) {
      try {
        final videoStats = await _funnelcakeApiClient.getWatchingVideos(
          limit: limit,
          before: until,
        );

        // Preserve API order.
        final videos = _transformVideoStats(videoStats, sortByCreatedAt: false);
        if (until == null) {
          _inMemoryFeedCache?.set('popular', HomeFeedResult(videos: videos));
        }
        return videos;
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
      final videos = _transformAndFilter(nip50Events, sortByCreatedAt: false);
      if (until == null) {
        _inMemoryFeedCache?.set('popular', HomeFeedResult(videos: videos));
      }
      return videos;
    }

    // 3. Fallback: relay doesn't support NIP-50, use client-side sorting
    // Fetch more videos than needed so we have a good pool to sort from
    final fetchLimit = limit * fetchMultiplier;

    final fallbackFilter = Filter(
      kinds: [_videoKind],
      limit: fetchLimit,
      until: until,
    );

    final events = await _nostrClient.queryEvents([fallbackFilter]);

    final videos = _transformAndFilter(events)
      // Sort by engagement score (uses VideoEvent's built-in comparator)
      ..sort(VideoEvent.compareByEngagementScore);

    // Return only the requested limit
    final result = videos.take(limit).toList();
    if (until == null) {
      _inMemoryFeedCache?.set('popular', HomeFeedResult(videos: result));
    }
    return result;
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
        final result = await _funnelcakeApiClient!.getVideosByAuthor(
          pubkey: pubkey,
        );

        // Find videos matching our d-tags and convert to VideoEvent
        for (final videoStats in result.videos) {
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
            // Reject non-loopback http:// URLs that the OS layer blocks
            // under release transport security (#3836).
            if (!_hasAllowedTransportScheme(video)) continue;
            if (video.isExpired) continue;

            final processed = _applyContentPreferences(video);
            if (processed == null) continue;

            foundVideos[videoAddressableId] = processed;
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

      // Reject non-loopback http:// URLs that the OS layer blocks under
      // release transport security (#3836).
      if (!_hasAllowedTransportScheme(video)) continue;

      // Skip expired videos (NIP-40)
      if (video.isExpired) continue;

      final processed = _applyContentPreferences(video);
      if (processed != null) {
        videos.add(processed);
      }
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
  VideoEvent? _tryParseAndFilter(
    Event event, {
    bool permissive = false,
    bool ignoreBlockFilter = false,
  }) {
    // Skip events that aren't valid video kinds
    final isSupported = permissive
        ? NIP71VideoKinds.isAcceptableVideoKind(event.kind)
        : NIP71VideoKinds.isVideoKind(event.kind);
    if (!isSupported) return null;

    // Block filter - check pubkey before parsing for efficiency
    if (!ignoreBlockFilter && (_blockFilter?.call(event.pubkey) ?? false)) {
      return null;
    }

    final video = VideoEvent.fromNostrEvent(event, permissive: permissive);

    // Skip videos without a playable URL
    if (!video.hasVideo) return null;

    // Reject non-loopback http:// URLs that the OS layer blocks under
    // release transport security (#3836).
    if (!_hasAllowedTransportScheme(video)) return null;

    // Skip expired videos (NIP-40)
    if (video.isExpired) return null;

    return _applyContentPreferences(video);
  }

  VideoEvent? _applyContentPreferences(VideoEvent video) {
    if (_contentFilter?.call(video) ?? false) return null;

    final warnLabels = _warningLabelsResolver?.call(video) ?? const <String>[];
    if (warnLabels.isEmpty) {
      return video.warnLabels.isEmpty
          ? video
          : video.copyWith(warnLabels: const <String>[]);
    }

    return video.copyWith(warnLabels: warnLabels);
  }

  /// Whether [video]'s primary playable URL uses a transport scheme that
  /// the OS will actually load on the platforms we ship.
  ///
  /// Release-build native transport-security on Android, iOS, and macOS
  /// rejects every cleartext request to a non-loopback host at the OS
  /// layer (see #3358 / PR #3788). A `kind:22` event whose `videoUrl` is
  /// non-loopback `http://` would be rejected by the OS at playback time;
  /// the in-feed retry logic in `FullscreenFeedBloc` would then treat
  /// the rejection as transient and keep the un-loadable entry visible
  /// forever. Reject at repository ingest so it never reaches the player.
  ///
  /// Loopback `http://` (`10.0.2.2`, `localhost`, `127.0.0.1`) is allowed
  /// so the local-stack development workflow keeps working. The host list
  /// is pinned to match the loopback allowlist in the native configs:
  ///   - mobile/android/app/src/main/res/xml/network_security_config.xml
  ///   - mobile/ios/Runner/Info.plist (NSAllowsLocalNetworking)
  ///   - mobile/macos/Runner/Info.plist (NSAllowsLocalNetworking)
  bool _hasAllowedTransportScheme(VideoEvent video) {
    final url = video.videoUrl;
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'https') return true;
    if (scheme != 'http') return false;
    final host = uri.host.toLowerCase();
    return host == '10.0.2.2' || host == 'localhost' || host == '127.0.0.1';
  }

  /// Applies the injected block filter, content filter, and warning-labels
  /// resolver to an already-parsed list of [VideoEvent]s.
  ///
  /// Use this when you have videos that were not produced by this
  /// repository's own parsing paths (e.g. entries restored from a local
  /// cache). Videos that fail the block filter, transport-scheme check
  /// (#3836), or content filter are removed; surviving videos have their
  /// `warnLabels` rewritten to reflect the current resolver output.
  ///
  /// This is a pure, synchronous operation. It does not touch the network
  /// or local storage.
  List<VideoEvent> applyContentPreferences(List<VideoEvent> videos) {
    final out = <VideoEvent>[];
    for (final video in videos) {
      if (_blockFilter?.call(video.pubkey) ?? false) continue;
      if (!_hasAllowedTransportScheme(video)) continue;
      final processed = _applyContentPreferences(video);
      if (processed != null) out.add(processed);
    }
    return out;
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

  /// Searches local cache for videos matching [query].
  ///
  /// Text-matches cached events by title, content, and hashtags (instant,
  /// no network). Returns empty if [query] is blank or no local storage
  /// is configured.
  ///
  /// Parameters:
  /// - [query]: The search query string. Returns empty if blank.
  ///
  /// Returns a list of matching [VideoEvent]s (unsorted — call
  /// [deduplicateAndSortVideos] to rank).
  Future<List<VideoEvent>> searchVideosLocally({required String query}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || _localStorage == null) return [];

    // Phase 1: SQL-level content search (fast, reduces event count)
    final contentMatches = await _localStorage.searchEvents(query: trimmed);

    // Phase 2: Hashtag search (tags stored as JSON, need separate query)
    final hashtagMatches = await _localStorage.getEventsByHashtags(
      hashtags: [trimmed],
      limit: 100,
    );

    // Merge and deduplicate by event ID
    final allMatches = <String, Event>{};
    for (final event in contentMatches) {
      allMatches[event.id] = event;
    }
    for (final event in hashtagMatches) {
      allMatches[event.id] = event;
    }

    // Transform to VideoEvent (now on ~20-50 events instead of 500)
    final localVideos = _transformAndFilter(allMatches.values.toList());

    // Precise in-memory refinement on parsed fields
    final queryLower = trimmed.toLowerCase();
    return localVideos
        .where(
          (v) =>
              (v.title?.toLowerCase().contains(queryLower) ?? false) ||
              v.content.toLowerCase().contains(queryLower) ||
              v.hashtags.any((h) => h.toLowerCase().contains(queryLower)),
        )
        .toList();
  }

  /// Counts local video matches without remote search.
  ///
  /// This still relies on local cache search, but avoids the remote API and
  /// relay phases when a tab only needs a badge count.
  Future<int> countVideosLocally({required String query}) async {
    final matches = await searchVideosLocally(query: query);
    return matches.length;
  }

  /// Searches NIP-50 relays for videos matching [query].
  ///
  /// Full-text search via [NostrClient.searchVideos] with a 5-second
  /// timeout to avoid blocking the caller. Returns empty on timeout or
  /// failure.
  ///
  /// Parameters:
  /// - [query]: The search query string. Returns empty if blank.
  /// - [limit]: Maximum number of results (default 100).
  ///
  /// Returns a list of matching [VideoEvent]s (unsorted — call
  /// [deduplicateAndSortVideos] to rank).
  Future<List<VideoEvent>> searchVideosOnRelays({
    required String query,
    int limit = 100,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final events = await _nostrClient
          .searchVideos(trimmed, limit: limit)
          .timeout(_relaySearchTimeout, onTimeout: (sink) => sink.close())
          .toList();
      return _transformAndFilter(events, sortByCreatedAt: false);
    } on Exception catch (e, stackTrace) {
      developer.log(
        'searchVideosOnRelays failed for "$trimmed"',
        name: 'VideosRepository',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Searches videos via the Funnelcake REST API.
  ///
  /// Returns empty list if the query is blank, the API client is null,
  /// or the API is unavailable. Results are converted from [VideoStats]
  /// to [VideoEvent] via [_transformVideoStats].
  ///
  /// Parameters:
  /// - [query]: The search query string. Returns empty if blank.
  /// - [limit]: Maximum number of results (default 50).
  ///
  /// Returns a record of matching [VideoEvent]s (unsorted — call
  /// [deduplicateAndSortVideos] to rank) and the total API result count.
  Future<({List<VideoEvent> videos, int totalCount})> searchVideosViaApi({
    required String query,
    int limit = 50,
    int offset = 0,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return (videos: <VideoEvent>[], totalCount: 0);
    }
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return (videos: <VideoEvent>[], totalCount: 0);
    }

    try {
      final response = await _funnelcakeApiClient.searchVideos(
        query: trimmed,
        limit: limit,
        offset: offset,
      );
      final videos = _transformVideoStats(
        response.videos,
        sortByCreatedAt: false,
      );
      return (videos: videos, totalCount: response.totalCount);
    } on FunnelcakeException catch (e, stackTrace) {
      developer.log(
        'searchVideosViaApi failed for "$trimmed"',
        name: 'VideosRepository',
        error: e,
        stackTrace: stackTrace,
      );
      return (videos: <VideoEvent>[], totalCount: 0);
    }
  }

  /// Deduplicates videos by ID and sorts by popularity (loops then time).
  ///
  /// Use this to combine results from [searchVideosLocally] and
  /// [searchVideosOnRelays] into a single ranked list.
  List<VideoEvent> deduplicateAndSortVideos(List<VideoEvent> videos) {
    final seenIds = <String>{};
    final unique = videos.where((v) {
      if (seenIds.contains(v.id)) return false;
      seenIds.add(v.id);
      return true;
    }).toList()..sort(VideoEvent.compareByLoopsThenTime);
    return unique;
  }

  /// Searches videos across all sources, yielding progressively.
  ///
  /// Returns a [Stream] that emits accumulated [VideoEvent] lists as each
  /// source completes:
  /// 1. Local cache results (instant)
  /// 2. Funnelcake API results (fast, ~1s)
  /// 3. NIP-50 relay results (slower, ~5s)
  ///
  /// Each emission contains the full deduplicated+sorted result set so far.
  /// Each phase is isolated — a failure in one phase does not prevent
  /// subsequent phases from yielding results.
  ///
  /// Parameters:
  /// - [query]: The search query string. Returns empty stream if blank.
  /// - [limit]: Maximum results per remote source (default 50).
  Stream<List<VideoEvent>> searchVideos({
    required String query,
    int limit = 50,
  }) async* {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    // Phase 1: Local cache (instant)
    final local = await searchVideosLocally(query: trimmed);
    var accumulated = deduplicateAndSortVideos(local);
    yield accumulated;

    // Phase 2: Funnelcake API (fast)
    try {
      final apiResult = await searchVideosViaApi(query: trimmed, limit: limit);
      if (apiResult.videos.isNotEmpty) {
        accumulated = deduplicateAndSortVideos([
          ...accumulated,
          ...apiResult.videos,
        ]);
        yield accumulated;
      }
    } on Exception catch (e, stackTrace) {
      developer.log(
        'searchVideos API phase failed for "$trimmed"',
        name: 'VideosRepository',
        error: e,
        stackTrace: stackTrace,
      );
    }

    // Phase 3: NIP-50 relay search (slower)
    // Note: searchVideosOnRelays handles exceptions internally and returns []
    // on failure, so no outer try-catch is needed.
    final relayResults = await searchVideosOnRelays(
      query: trimmed,
      limit: limit,
    );
    if (relayResults.isNotEmpty) {
      accumulated = deduplicateAndSortVideos([...accumulated, ...relayResults]);
      yield accumulated;
    }
  }

  /// Fetches confirmed collaborator videos for [taggedPubkey].
  ///
  /// Confirmed profile collabs come from Funnelcake's collaborator edge
  /// endpoint. Raw relay p-tag queries are intentionally not used here because
  /// a p-tag can represent a pending invite or generic mention, not a confirmed
  /// collaborator relationship.
  ///
  /// Returns an empty list while Funnelcake is unavailable or when the endpoint
  /// has no confirmed collabs for the profile.
  Future<List<VideoEvent>> getCollabVideos({
    required String taggedPubkey,
    int limit = _defaultLimit,
    int? until,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return [];
    }

    try {
      final stats = await _funnelcakeApiClient.getCollabVideos(
        pubkey: taggedPubkey,
        limit: limit,
        before: until,
      );
      return _transformVideoStats(stats);
    } on FunnelcakeNotFoundException {
      return [];
    }
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
    final result = await _funnelcakeApiClient.getVideosByAuthor(
      pubkey: pubkey,
      limit: limit,
      before: before,
    );
    return _transformVideoStats(result.videos);
  }

  /// Fetches a single video by event ID and enriches it with REST-side stats
  /// (loop counts, view counts) from the Funnelcake bulk-stats endpoint.
  ///
  /// Strategy:
  /// 1. Delegates to [getVideosByIds] for the cache→relay lookup and content
  ///    filtering (same path used by all feed providers).
  /// 2. Calls [_hydrateVideosWithBulkStats] on the result so the returned
  ///    [VideoEvent] carries accurate [VideoEvent.originalLoops] and view
  ///    counts — identical to what home/profile feeds receive.
  ///
  /// Returns `null` when the event is not found, fails content filtering, or
  /// the Funnelcake API is unavailable (stats are omitted but the video is
  /// still returned in that case via the hydration fallback).
  ///
  /// Intended for code paths that fetch a single video by ID outside of a
  /// feed context: notification taps and `divine.video/video/:id` deep-links.
  Future<VideoEvent?> fetchVideoWithStats(String eventId) async {
    if (eventId.isEmpty) return null;
    final videos = await getVideosByIds([eventId]);
    if (videos.isEmpty) return null;
    final hydrated = await _hydrateVideosWithBulkStats(videos);
    return hydrated.firstOrNull;
  }

  /// Resolves a video route identifier and returns the hydrated video.
  ///
  /// Supports raw event IDs, plain stable IDs / d-tags, and NIP-19
  /// `note1...`, `nevent1...`, and `naddr1...` references.
  Future<VideoEvent?> fetchVideoWithStatsForRouteId(String routeId) async {
    final candidate = _VideoRouteCandidate.parse(routeId);
    if (candidate == null) return null;

    if (candidate.eventId != null) {
      final byEventId = await _fetchRouteVideoByEventId(candidate.eventId!);
      if (byEventId != null) return byEventId;
    }

    if (candidate.addressableId != null) {
      final videos = await getVideosByAddressableIds([
        candidate.addressableId!,
      ]);
      if (videos.isNotEmpty) {
        final hydrated = await _hydrateVideosWithBulkStats(videos);
        if (hydrated.isNotEmpty) return hydrated.first;
      }
    }

    if (candidate.stableId != null) {
      final byStableId = await _fetchVideoByStableId(candidate.stableId!);
      if (byStableId != null) return byStableId;
    }

    final funnelcakeRouteId = candidate.stableId ?? candidate.eventId;
    if (funnelcakeRouteId != null) {
      final byFunnelcake = await _fetchVideoFromRouteApi(
        funnelcakeRouteId,
        permissive: true,
      );
      if (byFunnelcake != null) return byFunnelcake;
    }

    return null;
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

  Future<VideoEvent?> _fetchRouteVideoByEventId(String eventId) async {
    if (eventId.isEmpty) return null;

    final candidates = <Event>[];

    if (_localStorage != null) {
      // Shared links should be able to reopen a video from local cache on a
      // cold start before the relay layer has finished connecting.
      candidates.addAll(await _localStorage.getEventsByIds([eventId]));
    }

    if (candidates.isEmpty) {
      candidates.addAll(
        await _nostrClient.queryEvents([
          Filter(
            ids: [eventId],
            kinds: NIP71VideoKinds.getAllAcceptableVideoKinds(),
          ),
        ]),
      );
    }

    if (candidates.isEmpty) return null;

    final videos = <VideoEvent>[];
    for (final event in candidates) {
      final video = _tryParseAndFilter(
        event,
        permissive: true,
        ignoreBlockFilter: true,
      );
      if (video != null) {
        videos.add(video);
      }
    }
    if (videos.isEmpty) return null;

    final hydrated = await _hydrateVideosWithBulkStats(videos);
    return hydrated.firstOrNull;
  }

  Future<VideoEvent?> _fetchVideoByStableId(String stableId) async {
    final candidates = <Event>[];

    if (_localStorage != null) {
      candidates.addAll(await _localStorage.getEventsByDTag(stableId));
    }

    if (candidates.isEmpty) {
      candidates.addAll(
        await _nostrClient.queryEvents([
          Filter(
            // Route-specific lookups accept all supported NIP-71 video kinds so
            // older shared links still resolve instead of failing as not found.
            kinds: NIP71VideoKinds.getAllAcceptableVideoKinds(),
            d: [stableId],
            limit: 10,
          ),
        ]),
      );
    }

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final videos = <VideoEvent>[];
    for (final event in candidates) {
      final video = _tryParseAndFilter(
        event,
        permissive: true,
        ignoreBlockFilter: true,
      );
      if (video != null) {
        videos.add(video);
      }
    }
    if (videos.isEmpty) return null;

    final hydrated = await _hydrateVideosWithBulkStats(videos);
    return hydrated.isEmpty ? null : hydrated.first;
  }

  Future<VideoEvent?> _fetchVideoFromRouteApi(
    String routeId, {
    bool permissive = false,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return null;
    }

    final event = await _funnelcakeApiClient.getVideoEvent(routeId);
    if (event == null) return null;

    final video = _tryParseAndFilter(
      event,
      permissive: permissive,
      ignoreBlockFilter: true,
    );
    if (video == null) return null;

    final hydrated = await _hydrateVideosWithBulkStats([video]);
    return hydrated.firstOrNull;
  }
}

class _VideoRouteCandidate {
  const _VideoRouteCandidate({this.eventId, this.addressableId, this.stableId});

  final String? eventId;
  final String? addressableId;
  final String? stableId;

  static _VideoRouteCandidate? parse(String routeId) {
    final trimmed = routeId.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.length == 64 &&
        RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(trimmed)) {
      return _VideoRouteCandidate(
        eventId: trimmed.toLowerCase(),
        stableId: trimmed,
      );
    }

    if (Nip19.isNoteId(trimmed)) {
      final eventId = Nip19.decode(trimmed);
      return eventId.isEmpty ? null : _VideoRouteCandidate(eventId: eventId);
    }

    if (NIP19Tlv.isNevent(trimmed)) {
      final decoded = NIP19Tlv.decodeNevent(trimmed);
      return decoded == null ? null : _VideoRouteCandidate(eventId: decoded.id);
    }

    if (NIP19Tlv.isNaddr(trimmed)) {
      final decoded = NIP19Tlv.decodeNaddr(trimmed);
      if (decoded == null) return null;
      return _VideoRouteCandidate(
        addressableId: AId(
          kind: decoded.kind,
          pubkey: decoded.author,
          dTag: decoded.id,
        ).toAString(),
        stableId: decoded.id,
      );
    }

    return _VideoRouteCandidate(stableId: trimmed);
  }
}
