// ABOUTME: Riverpod providers for user lists (kind 30000) and curated video lists (kind 30005)
// ABOUTME: Manages list state and provides reactive updates for the Lists tab

import 'dart:async';

import 'package:nostr_sdk/filter.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/user_list_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'list_providers.g.dart';

/// Provider for all user lists (kind 30000 - people lists)
@riverpod
Future<List<UserList>> userLists(Ref ref) async {
  final service = await ref.watch(userListServiceProvider.future);
  return service.lists;
}

/// Provider for all curated video lists (kind 30005)
@riverpod
Future<List<CuratedList>> curatedLists(Ref ref) async {
  final service = await ref.watch(curatedListsStateProvider.future);
  return service;
}

/// Combined provider for both types of lists
@riverpod
Future<({List<UserList> userLists, List<CuratedList> curatedLists})> allLists(
  Ref ref,
) async {
  // Fetch both in parallel for better performance
  final results = await Future.wait([
    ref.watch(userListsProvider.future),
    ref.watch(curatedListsProvider.future),
  ]);

  return (
    userLists: results[0] as List<UserList>,
    curatedLists: results[1] as List<CuratedList>,
  );
}

/// State class for discovered public lists
class DiscoveredListsState {
  const DiscoveredListsState({
    this.lists = const [],
    this.isLoading = false,
    this.oldestTimestamp,
  });

  final List<CuratedList> lists;
  final bool isLoading;
  final DateTime? oldestTimestamp;

  DiscoveredListsState copyWith({
    List<CuratedList>? lists,
    bool? isLoading,
    DateTime? oldestTimestamp,
  }) {
    return DiscoveredListsState(
      lists: lists ?? this.lists,
      isLoading: isLoading ?? this.isLoading,
      oldestTimestamp: oldestTimestamp ?? this.oldestTimestamp,
    );
  }
}

/// Provider that caches discovered public lists across navigation
/// This persists the lists so they're not lost when leaving/returning to screen
@Riverpod(keepAlive: true)
class DiscoveredLists extends _$DiscoveredLists {
  @override
  DiscoveredListsState build() {
    return const DiscoveredListsState();
  }

  /// Update the list of discovered lists
  void setLists(List<CuratedList> lists) {
    state = state.copyWith(lists: lists);
  }

  /// Add new lists (for pagination/streaming)
  void addLists(List<CuratedList> newLists) {
    final existingIds = state.lists.map((l) => l.id).toSet();
    final trulyNew = newLists
        .where((l) => !existingIds.contains(l.id))
        .toList();
    if (trulyNew.isNotEmpty) {
      final combined = [...state.lists, ...trulyNew]
        ..sort(
          (a, b) => b.videoEventIds.length.compareTo(a.videoEventIds.length),
        );
      state = state.copyWith(lists: combined);
    }
  }

  /// Set loading state
  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  /// Update oldest timestamp for pagination
  void updateOldestTimestamp(DateTime timestamp) {
    if (state.oldestTimestamp == null ||
        timestamp.isBefore(state.oldestTimestamp!)) {
      state = state.copyWith(oldestTimestamp: timestamp);
    }
  }

  /// Clear all discovered lists (for manual refresh)
  void clear() {
    state = const DiscoveredListsState();
  }
}

/// Provider for videos in a specific curated list
@riverpod
Future<List<String>> curatedListVideos(Ref ref, String listId) async {
  final service = await ref.read(curatedListsStateProvider.notifier).service;
  final list = service?.getListById(listId);

  if (list == null) {
    return [];
  }

  // Return video IDs in the order specified by the list's playOrder setting
  return service?.getOrderedVideoIds(listId) ?? [];
}

/// Provider for videos from all members of a user list
@riverpod
Stream<List<VideoEvent>> userListMemberVideos(
  Ref ref,
  List<String> pubkeys,
) async* {
  // Watch discovery videos and filter to only those from list members
  final allVideosAsync = ref.watch(videoEventsProvider);

  await for (final _ in Stream.value(null)) {
    if (allVideosAsync.hasValue) {
      final allVideos = allVideosAsync.value!;

      // Filter videos to only those authored by list members
      final listMemberVideos = allVideos
          .where((video) => pubkeys.contains(video.pubkey))
          .toList();

      // Sort by creation time (newest first)
      listMemberVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      yield listMemberVideos;
    }
  }
}

/// Provider that streams public lists containing a specific video
/// Accumulates results as they arrive from Nostr relays, yielding updated list
/// on each new result. This enables progressive UI updates via Riverpod.
@riverpod
Stream<List<CuratedList>> publicListsContainingVideo(
  Ref ref,
  String videoId,
) async* {
  /// wait to initialize the curated list service
  await ref.read(curatedListsStateProvider.future);
  final curatedListStream = ref
      .read(curatedListsStateProvider.notifier)
      .service
      ?.streamPublicListsContainingVideo(videoId);
  final accumulated = <CuratedList>[];
  final seenIds = <String>{};

  // Yield an initial value to avoid hanging if the stream is empty
  yield const <CuratedList>[];

  // Stream events from Nostr relays, accumulating as they arrive
  await for (final list in curatedListStream ?? Stream.empty()) {
    if (!seenIds.contains(list.id)) {
      seenIds.add(list.id);
      accumulated.add(list);
      // Yield a copy of accumulated list on each new result
      yield List<CuratedList>.from(accumulated);
    }
  }

  // After stream completes (EOSE from relay), yield final accumulated result
  // This ensures the provider has data even if stream completes immediately
  yield accumulated;
}

/// Provider that fetches actual VideoEvent objects for a curated list
/// Streams videos as they are fetched from cache or relays
@riverpod
Stream<List<VideoEvent>> curatedListVideoEvents(Ref ref, String listId) async* {
  Log.info(
    '📋 Fetching videos for curated list: $listId',
    name: 'CuratedListVideoEvents',
    category: LogCategory.video,
  );

  // Get the video IDs from the curated list
  final videoIds = await ref.watch(curatedListVideosProvider(listId).future);

  if (videoIds.isEmpty) {
    Log.info(
      '📋 List $listId has no videos',
      name: 'CuratedListVideoEvents',
      category: LogCategory.video,
    );
    yield [];
    return;
  }

  Log.info(
    '📋 List has ${videoIds.length} video IDs to fetch',
    name: 'CuratedListVideoEvents',
    category: LogCategory.video,
  );

  // Separate video event IDs from addressable coordinates
  final eventIds = <String>[];
  final addressableCoords = <String>[]; // Format: 34236:pubkey:d-tag

  // Simple hex validation for 64-character Nostr event IDs
  final hexRegex = RegExp(r'^[a-fA-F0-9]{64}$');

  for (final id in videoIds) {
    if (id.contains(':')) {
      addressableCoords.add(id);
    } else if (hexRegex.hasMatch(id)) {
      eventIds.add(id);
    }
  }

  Log.info(
    '📋 IDs breakdown: ${eventIds.length} event IDs, '
    '${addressableCoords.length} addressable coords',
    name: 'CuratedListVideoEvents',
    category: LogCategory.video,
  );

  // First check cache via video event service
  final videoEventService = ref.read(videoEventServiceProvider);
  final foundVideos = <VideoEvent>[];
  final missingIds = <String>[];
  final missingCoords = <String>[];

  // Check cache for regular event IDs
  for (final eventId in eventIds) {
    final cached = videoEventService.getVideoById(eventId);
    if (cached != null) {
      foundVideos.add(cached);
    } else {
      missingIds.add(eventId);
    }
  }

  // Check cache for addressable coordinates (kind:pubkey:d-tag)
  // Combine videos from all subscription types for cache lookup
  final allCachedVideos = <VideoEvent>{
    ...videoEventService.discoveryVideos,
    ...videoEventService.homeFeedVideos,
    ...videoEventService.profileVideos,
  }.toList();
  Log.debug(
    '📋 Searching ${allCachedVideos.length} cached videos for ${addressableCoords.length} coords',
    name: 'CuratedListVideoEvents',
    category: LogCategory.video,
  );

  for (final coord in addressableCoords) {
    final parts = coord.split(':');
    if (parts.length >= 3) {
      final pubkey = parts[1];
      final dTag = parts[2];

      final cached = allCachedVideos.where((v) {
        if (v.pubkey != pubkey) return false;
        // Check d-tag in rawTags, vineId, or video id
        final videoDTag = v.rawTags['d'] ?? v.vineId ?? v.id;
        return videoDTag == dTag;
      }).firstOrNull;

      if (cached != null) {
        foundVideos.add(cached);
        Log.debug(
          '📋 Found addressable video in cache: ${cached.title ?? cached.id}',
          name: 'CuratedListVideoEvents',
          category: LogCategory.video,
        );
      } else {
        Log.debug(
          '📋 Cache miss for coord: $coord (pubkey=$pubkey, dTag=$dTag)',
          name: 'CuratedListVideoEvents',
          category: LogCategory.video,
        );
        missingCoords.add(coord);
      }
    }
  }

  Log.info(
    '📋 Found ${foundVideos.length} videos in cache '
    '(${missingIds.length} missing IDs, ${missingCoords.length} missing coords)',
    name: 'CuratedListVideoEvents',
    category: LogCategory.video,
  );

  // Yield cached videos immediately (but not empty - keep loading state)
  if (foundVideos.isNotEmpty) {
    yield List.from(foundVideos);
  }

  // Fetch missing videos from relays
  if (missingIds.isNotEmpty || missingCoords.isNotEmpty) {
    Log.info(
      '📋 Fetching ${missingIds.length} missing IDs + '
      '${missingCoords.length} missing coords from relays',
      name: 'CuratedListVideoEvents',
      category: LogCategory.video,
    );

    final nostrService = ref.read(nostrServiceProvider);

    // Build filters for missing videos
    final filters = <Filter>[];

    // Filter for regular event IDs
    if (missingIds.isNotEmpty) {
      filters.add(Filter(ids: missingIds));
    }

    // Filter for addressable events (kind 34236)
    for (final coord in missingCoords) {
      final parts = coord.split(':');
      if (parts.length >= 3) {
        final kind = int.tryParse(parts[0]);
        final pubkey = parts[1];
        final dTag = parts[2];
        if (kind != null) {
          filters.add(Filter(kinds: [kind], authors: [pubkey], d: [dTag]));
        }
      }
    }

    if (filters.isNotEmpty) {
      final eventStream = nostrService.subscribe(filters);
      final seenIds = foundVideos.map((v) => v.id).toSet();

      await for (final event in eventStream) {
        if (seenIds.contains(event.id)) continue;

        try {
          // Use permissive mode to accept all NIP-71 video kinds from curated lists
          final video = VideoEvent.fromNostrEvent(event, permissive: true);
          foundVideos.add(video);
          seenIds.add(event.id);

          // Also add to the video event service cache
          videoEventService.addVideoEvent(video);

          Log.info(
            '📋 Fetched video (kind ${event.kind}): ${video.title ?? video.id}',
            name: 'CuratedListVideoEvents',
            category: LogCategory.video,
          );

          // Yield updated list with new video
          yield List.from(foundVideos);
        } catch (e) {
          // Log the actual event kind to help diagnose issues
          Log.warning(
            '📋 Failed to parse event ${event.id} (kind ${event.kind}): $e',
            name: 'CuratedListVideoEvents',
            category: LogCategory.video,
          );
        }
      }
    }
  }

  Log.info(
    '📋 Finished fetching. Total videos: ${foundVideos.length}',
    name: 'CuratedListVideoEvents',
    category: LogCategory.video,
  );

  // Yield final result
  yield foundVideos;
}

/// Provider that fetches VideoEvent objects directly from a list of video IDs
/// Use this for discovered lists that aren't in local storage
@riverpod
Stream<List<VideoEvent>> videoEventsByIds(
  Ref ref,
  List<String> videoIds,
) async* {
  Log.info(
    '📋 Fetching ${videoIds.length} videos by IDs',
    name: 'VideoEventsByIds',
    category: LogCategory.video,
  );

  if (videoIds.isEmpty) {
    yield [];
    return;
  }

  // Separate video event IDs from addressable coordinates
  final eventIds = <String>[];
  final addressableCoords = <String>[]; // Format: 34236:pubkey:d-tag

  // Simple hex validation for 64-character Nostr event IDs
  final hexRegex = RegExp(r'^[a-fA-F0-9]{64}$');

  for (final id in videoIds) {
    if (id.contains(':')) {
      addressableCoords.add(id);
    } else if (hexRegex.hasMatch(id)) {
      eventIds.add(id);
    }
  }

  Log.info(
    '📋 IDs breakdown: ${eventIds.length} event IDs, '
    '${addressableCoords.length} addressable coords',
    name: 'VideoEventsByIds',
    category: LogCategory.video,
  );

  // First check cache via video event service
  final videoEventService = ref.read(videoEventServiceProvider);
  final foundVideos = <VideoEvent>[];
  final missingIds = <String>[];
  final missingCoords = <String>[];

  // Check cache for regular event IDs
  for (final eventId in eventIds) {
    final cached = videoEventService.getVideoById(eventId);
    if (cached != null) {
      foundVideos.add(cached);
    } else {
      missingIds.add(eventId);
    }
  }

  // Check cache for addressable coordinates (kind:pubkey:d-tag)
  // Combine videos from all subscription types for cache lookup
  final allCachedVideos = <VideoEvent>{
    ...videoEventService.discoveryVideos,
    ...videoEventService.homeFeedVideos,
    ...videoEventService.profileVideos,
  }.toList();
  Log.debug(
    '📋 Searching ${allCachedVideos.length} cached videos for ${addressableCoords.length} coords',
    name: 'VideoEventsByIds',
    category: LogCategory.video,
  );

  for (final coord in addressableCoords) {
    final parts = coord.split(':');
    if (parts.length >= 3) {
      final pubkey = parts[1];
      final dTag = parts[2];

      // Find video in cache that matches pubkey and d-tag
      final cached = allCachedVideos.where((v) {
        if (v.pubkey != pubkey) return false;
        // Check d-tag in rawTags, vineId, or even the video id itself
        final videoDTag = v.rawTags['d'] ?? v.vineId ?? v.id;
        return videoDTag == dTag;
      }).firstOrNull;

      if (cached != null) {
        foundVideos.add(cached);
        Log.debug(
          '📋 Found addressable video in cache: ${cached.title ?? cached.id}',
          name: 'VideoEventsByIds',
          category: LogCategory.video,
        );
      } else {
        // Log what we're looking for vs what's in cache for debugging
        final matchingPubkey = allCachedVideos
            .where((v) => v.pubkey == pubkey)
            .toList();
        Log.debug(
          '📋 Cache miss for coord: $coord\n'
          '   Looking for: pubkey=$pubkey, dTag=$dTag\n'
          '   Videos by same author: ${matchingPubkey.length}\n'
          '   Their d-tags: ${matchingPubkey.take(3).map((v) => v.rawTags['d'] ?? v.vineId ?? 'none').toList()}',
          name: 'VideoEventsByIds',
          category: LogCategory.video,
        );
        missingCoords.add(coord);
      }
    }
  }

  Log.info(
    '📋 Found ${foundVideos.length} videos in cache '
    '(${missingIds.length} missing IDs, ${missingCoords.length} missing coords)',
    name: 'VideoEventsByIds',
    category: LogCategory.video,
  );

  // Only yield cached videos if we have some - don't yield empty yet
  // (empty yield would show "No videos" instead of loading state)
  if (foundVideos.isNotEmpty) {
    yield List.from(foundVideos);
  }

  // Fetch missing videos from relays
  if (missingIds.isNotEmpty || missingCoords.isNotEmpty) {
    Log.info(
      '📋 Fetching ${missingIds.length} missing event IDs + '
      '${missingCoords.length} missing addressable coords from relays',
      name: 'VideoEventsByIds',
      category: LogCategory.video,
    );

    final nostrService = ref.read(nostrServiceProvider);

    // Build filters for missing videos
    final filters = <Filter>[];

    // Filter for regular event IDs
    if (missingIds.isNotEmpty) {
      filters.add(Filter(ids: missingIds));
    }

    // Filter for addressable events (NIP-71 video kinds)
    for (final coord in missingCoords) {
      final parts = coord.split(':');
      if (parts.length >= 3) {
        final kind = int.tryParse(parts[0]);
        final pubkey = parts[1];
        final dTag = parts[2];
        if (kind != null) {
          filters.add(Filter(kinds: [kind], authors: [pubkey], d: [dTag]));
        }
      }
    }

    if (filters.isNotEmpty) {
      final eventStream = nostrService.subscribe(filters);
      final seenIds = foundVideos.map((v) => v.id).toSet();

      await for (final event in eventStream) {
        if (seenIds.contains(event.id)) continue;

        try {
          // Use permissive mode to accept all NIP-71 video kinds from external sources
          final video = VideoEvent.fromNostrEvent(event, permissive: true);
          foundVideos.add(video);
          seenIds.add(event.id);

          // Also add to the video event service cache
          videoEventService.addVideoEvent(video);

          Log.info(
            '📋 Fetched video (kind ${event.kind}): ${video.title ?? video.id}',
            name: 'VideoEventsByIds',
            category: LogCategory.video,
          );

          // Yield updated list with new video
          yield List.from(foundVideos);
        } catch (e) {
          // Log the actual event kind to help diagnose issues
          Log.warning(
            '📋 Failed to parse event ${event.id} (kind ${event.kind}): $e',
            name: 'VideoEventsByIds',
            category: LogCategory.video,
          );
        }
      }
    }
  }

  Log.info(
    '📋 Finished fetching. Total videos: ${foundVideos.length}',
    name: 'VideoEventsByIds',
    category: LogCategory.video,
  );

  // Yield final result
  yield foundVideos;
}
