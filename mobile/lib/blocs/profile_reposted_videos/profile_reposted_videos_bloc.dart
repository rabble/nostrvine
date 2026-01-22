// ABOUTME: BLoC for managing profile reposted videos grid
// ABOUTME: Syncs repost records and fetches video data from cache/relays

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:reposts_repository/reposts_repository.dart';

part 'profile_reposted_videos_event.dart';
part 'profile_reposted_videos_state.dart';

/// Number of videos to load per page for pagination.
const _pageSize = 18;

/// BLoC for managing profile reposted videos.
///
/// Handles:
/// - Syncing repost records from RepostsRepository
/// - Resolving addressable IDs to VideoEvents from cache/relays
/// - Filtering: excludes unsupported video formats
/// - Listening for repost changes to update the list
/// - Pagination: loads videos in batches of [_pageSize]
class ProfileRepostedVideosBloc
    extends Bloc<ProfileRepostedVideosEvent, ProfileRepostedVideosState> {
  ProfileRepostedVideosBloc({
    required RepostsRepository repostsRepository,
    required VideoEventService videoEventService,
    required NostrClient nostrClient,
    String? targetUserPubkey,
  }) : _repostsRepository = repostsRepository,
       _videoEventService = videoEventService,
       _nostrClient = nostrClient,
       _targetUserPubkey = targetUserPubkey,
       super(const ProfileRepostedVideosState()) {
    on<ProfileRepostedVideosSyncRequested>(_onSyncRequested);
    on<ProfileRepostedVideosSubscriptionRequested>(_onSubscriptionRequested);
    on<ProfileRepostedVideosLoadMoreRequested>(_onLoadMoreRequested);
  }

  final RepostsRepository _repostsRepository;
  final VideoEventService _videoEventService;
  final NostrClient _nostrClient;

  /// The pubkey of the user whose reposts to display.
  /// If null or same as current user, uses RepostsRepository.
  /// If different, fetches reposts directly from Nostr relays.
  final String? _targetUserPubkey;

  /// Whether we're viewing another user's profile (not our own).
  bool get _isOtherUserProfile =>
      _targetUserPubkey != null && _targetUserPubkey != _nostrClient.publicKey;

  /// Handle sync request - syncs repost records from repository then loads
  /// videos.
  Future<void> _onSyncRequested(
    ProfileRepostedVideosSyncRequested event,
    Emitter<ProfileRepostedVideosState> emit,
  ) async {
    // Don't re-sync if already syncing
    if (state.status == ProfileRepostedVideosStatus.syncing) return;

    Log.info(
      'ProfileRepostedVideosBloc: Starting sync for '
      '${_isOtherUserProfile ? "other user" : "own profile"}',
      name: 'ProfileRepostedVideosBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(status: ProfileRepostedVideosStatus.syncing));

    try {
      // Get repost addressable IDs - either from repository (own) or relays
      // (other)
      final addressableIds = _isOtherUserProfile
          ? await _fetchOtherUserRepostedAddressableIds()
          : await _fetchOwnRepostedAddressableIds();

      Log.info(
        'ProfileRepostedVideosBloc: Synced ${addressableIds.length} repost '
        'addressable IDs',
        name: 'ProfileRepostedVideosBloc',
        category: LogCategory.video,
      );

      if (addressableIds.isEmpty) {
        emit(
          state.copyWith(
            status: ProfileRepostedVideosStatus.success,
            videos: [],
            repostedAddressableIds: [],
            hasMoreContent: false,
            clearError: true,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          status: ProfileRepostedVideosStatus.loading,
          repostedAddressableIds: addressableIds,
        ),
      );

      // Fetch video data for the first page of addressable IDs
      final firstPageIds = addressableIds.take(_pageSize).toList();
      final videos = await _fetchVideos(firstPageIds);

      Log.info(
        'ProfileRepostedVideosBloc: Loaded ${videos.length} videos '
        '(first page of ${addressableIds.length} total)',
        name: 'ProfileRepostedVideosBloc',
        category: LogCategory.video,
      );

      emit(
        state.copyWith(
          status: ProfileRepostedVideosStatus.success,
          videos: videos,
          hasMoreContent: addressableIds.length > _pageSize,
          clearError: true,
        ),
      );
    } on SyncFailedException catch (e) {
      Log.error(
        'ProfileRepostedVideosBloc: Sync failed - ${e.message}',
        name: 'ProfileRepostedVideosBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          status: ProfileRepostedVideosStatus.failure,
          error: ProfileRepostedVideosError.syncFailed,
        ),
      );
    } on FetchRepostsFailedException catch (e) {
      Log.error(
        'ProfileRepostedVideosBloc: Fetch reposts failed - ${e.message}',
        name: 'ProfileRepostedVideosBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          status: ProfileRepostedVideosStatus.failure,
          error: ProfileRepostedVideosError.syncFailed,
        ),
      );
    } catch (e) {
      Log.error(
        'ProfileRepostedVideosBloc: Failed to load videos - $e',
        name: 'ProfileRepostedVideosBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          status: ProfileRepostedVideosStatus.failure,
          error: ProfileRepostedVideosError.loadFailed,
        ),
      );
    }
  }

  /// Fetch reposted addressable IDs for the current user via RepostsRepository.
  Future<List<String>> _fetchOwnRepostedAddressableIds() async {
    final syncResult = await _repostsRepository.syncUserReposts();
    return syncResult.orderedAddressableIds;
  }

  /// Fetch reposted addressable IDs for another user via RepostsRepository.
  ///
  /// Delegates to [RepostsRepository.fetchUserReposts] which queries relays
  /// for Kind 16 reposts authored by the target user.
  Future<List<String>> _fetchOtherUserRepostedAddressableIds() async {
    return _repostsRepository.fetchUserReposts(_targetUserPubkey!);
  }

  /// Subscribe to reposted IDs changes and update the video list reactively.
  ///
  /// Uses emit.forEach to listen to the repository stream and emit state
  /// changes when reposted IDs change (videos added or removed).
  ///
  /// Note: This only works for the current user's own profile, as the
  /// RepostsRepository only tracks the authenticated user's reposts.
  /// For other users' profiles, this subscription has no effect.
  Future<void> _onSubscriptionRequested(
    ProfileRepostedVideosSubscriptionRequested event,
    Emitter<ProfileRepostedVideosState> emit,
  ) async {
    // Only subscribe for own profile - the repository only tracks current
    // user's reposts, so watching it for other users would show wrong data.
    if (_isOtherUserProfile) return;

    await emit.forEach<Set<String>>(
      _repostsRepository.watchRepostedAddressableIds(),
      onData: (repostedIdsSet) {
        final newIds = repostedIdsSet.toList();

        // Skip if IDs haven't changed
        if (listEquals(newIds, state.repostedAddressableIds)) return state;

        // Skip if we haven't done initial sync yet
        if (state.status == ProfileRepostedVideosStatus.initial ||
            state.status == ProfileRepostedVideosStatus.syncing) {
          return state;
        }

        Log.info(
          'ProfileRepostedVideosBloc: Reposted IDs changed, updating list',
          name: 'ProfileRepostedVideosBloc',
          category: LogCategory.video,
        );

        // If a video was unreposted, remove it from the list immediately
        if (newIds.length < state.repostedAddressableIds.length) {
          final removedIds = state.repostedAddressableIds
              .where((id) => !newIds.contains(id))
              .toSet();
          final updatedVideos = state.videos
              .where((v) => !removedIds.contains(_computeAddressableId(v)))
              .toList();

          return state.copyWith(
            repostedAddressableIds: newIds,
            videos: updatedVideos,
          );
        }

        // If a video was reposted, we need to fetch it asynchronously
        // For now, just update the IDs - the video will be fetched on next sync
        if (newIds.length > state.repostedAddressableIds.length) {
          return state.copyWith(repostedAddressableIds: newIds);
        }

        return state;
      },
    );
  }

  /// Handle load more request - fetches the next page of videos.
  ///
  /// Uses [state.videos.length] to determine the offset and fetches
  /// the next [_pageSize] videos from [state.repostedAddressableIds].
  Future<void> _onLoadMoreRequested(
    ProfileRepostedVideosLoadMoreRequested event,
    Emitter<ProfileRepostedVideosState> emit,
  ) async {
    // Skip if not in success state, already loading, or no more content
    if (state.status != ProfileRepostedVideosStatus.success ||
        state.isLoadingMore ||
        !state.hasMoreContent) {
      return;
    }

    final currentCount = state.videos.length;
    final totalCount = state.repostedAddressableIds.length;

    // No more to load
    if (currentCount >= totalCount) {
      emit(state.copyWith(hasMoreContent: false));
      return;
    }

    Log.info(
      'ProfileRepostedVideosBloc: Loading more videos '
      '(current: $currentCount, total: $totalCount)',
      name: 'ProfileRepostedVideosBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(isLoadingMore: true));

    try {
      // Get the next page of addressable IDs
      final nextPageIds = state.repostedAddressableIds
          .skip(currentCount)
          .take(_pageSize)
          .toList();

      // Fetch videos for the next page
      final newVideos = await _fetchVideos(nextPageIds);

      Log.info(
        'ProfileRepostedVideosBloc: Loaded ${newVideos.length} more videos',
        name: 'ProfileRepostedVideosBloc',
        category: LogCategory.video,
      );

      // Append to existing videos
      final allVideos = [...state.videos, ...newVideos];
      final hasMore = allVideos.length < totalCount;

      emit(
        state.copyWith(
          videos: allVideos,
          isLoadingMore: false,
          hasMoreContent: hasMore,
        ),
      );
    } catch (e) {
      Log.error(
        'ProfileRepostedVideosBloc: Failed to load more videos - $e',
        name: 'ProfileRepostedVideosBloc',
        category: LogCategory.video,
      );
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  /// Fetch videos for the given addressable IDs.
  ///
  /// 1. Parse addressable IDs to extract pubkey and d-tag
  /// 2. Check cache first
  /// 3. Fetch missing videos from relays
  /// 4. Return ordered list matching the input order
  Future<List<VideoEvent>> _fetchVideos(List<String> addressableIds) async {
    final cachedVideosMap = <String, VideoEvent>{};
    final missingIds = <String>[];

    // Check cache first
    for (final addressableId in addressableIds) {
      final cached = _findCachedVideoByAddressable(addressableId);
      if (cached != null) {
        cachedVideosMap[addressableId] = cached;
      } else {
        missingIds.add(addressableId);
      }
    }

    Log.info(
      'ProfileRepostedVideosBloc: Found ${cachedVideosMap.length} in cache, '
      '${missingIds.length} need relay fetch',
      name: 'ProfileRepostedVideosBloc',
      category: LogCategory.video,
    );

    // Fetch missing videos from relays
    if (missingIds.isNotEmpty) {
      final fetchedVideos = await _fetchVideosFromRelay(missingIds);
      for (final video in fetchedVideos) {
        final addressableId = _computeAddressableId(video);
        if (addressableId != null) {
          cachedVideosMap[addressableId] = video;
        }
      }

      Log.info(
        'ProfileRepostedVideosBloc: Fetched ${fetchedVideos.length} from relay',
        name: 'ProfileRepostedVideosBloc',
        category: LogCategory.video,
      );
    }

    // Build ordered list using the recency-ordered addressable IDs
    final orderedVideos = <VideoEvent>[];
    for (final addressableId in addressableIds) {
      final video = cachedVideosMap[addressableId];
      if (video != null) {
        orderedVideos.add(video);
      }
    }

    // Filter out unsupported videos (WebM on iOS/macOS)
    return orderedVideos.where((v) => v.isSupportedOnCurrentPlatform).toList();
  }

  /// Find a cached video by its addressable ID.
  ///
  /// Parses the addressable ID format (kind:pubkey:d-tag) and searches
  /// through cached videos from VideoEventService.
  VideoEvent? _findCachedVideoByAddressable(String addressableId) {
    final parsed = _parseAddressableId(addressableId);
    if (parsed == null) return null;

    // Search through author's videos for matching d-tag
    final authorVideos = _videoEventService.getVideosByAuthor(parsed.pubkey);
    for (final video in authorVideos) {
      if (video.rawTags['d'] == parsed.dTag) {
        return video;
      }
    }
    return null;
  }

  /// Parse addressable ID format: kind:pubkey:d-tag
  ({int kind, String pubkey, String dTag})? _parseAddressableId(
    String addressableId,
  ) {
    final parts = addressableId.split(':');
    if (parts.length < 3) return null;
    final kind = int.tryParse(parts[0]);
    if (kind == null) return null;
    return (kind: kind, pubkey: parts[1], dTag: parts[2]);
  }

  /// Compute the addressable ID for a video event.
  ///
  /// Format: `34236:<pubkey>:<d-tag>`
  /// Returns null if the video doesn't have a d-tag (vineId).
  String? _computeAddressableId(VideoEvent video) {
    if (video.vineId == null) return null;
    // NIP-71 addressable short video kind
    return '34236:${video.pubkey}:${video.vineId}';
  }

  /// Fetch videos from relays by their addressable IDs.
  Future<List<VideoEvent>> _fetchVideosFromRelay(
    List<String> addressableIds,
  ) async {
    if (addressableIds.isEmpty) return [];

    final completer = Completer<List<VideoEvent>>();
    final videos = <VideoEvent>[];
    final expectedCount = addressableIds.length;

    // Generate unique subscription ID for cleanup
    final subscriptionId =
        'reposted_videos_bloc_${DateTime.now().millisecondsSinceEpoch}';

    /// Helper to clean up subscription resources
    Future<void> cleanup() async {
      await _nostrClient.unsubscribe(subscriptionId);
    }

    try {
      // Build filters for addressable events
      // Each addressable ID needs to be fetched with authors + d filter
      final filters = <Filter>[];
      for (final addressableId in addressableIds) {
        final parsed = _parseAddressableId(addressableId);
        if (parsed != null && NIP71VideoKinds.isVideoKind(parsed.kind)) {
          filters.add(
            Filter(
              kinds: [parsed.kind],
              authors: [parsed.pubkey],
              d: [parsed.dTag],
              limit: 1,
            ),
          );
        }
      }

      if (filters.isEmpty) {
        return [];
      }

      final eventStream = _nostrClient.subscribe(
        filters,
        subscriptionId: subscriptionId,
        onEose: () {
          // Complete when all relays finish sending stored events
          if (!completer.isCompleted) {
            Log.info(
              'ProfileRepostedVideosBloc: EOSE received, completing with '
              '${videos.length} videos',
              name: 'ProfileRepostedVideosBloc',
              category: LogCategory.video,
            );
            cleanup();
            completer.complete(videos);
          }
        },
      );

      eventStream.listen(
        (event) {
          try {
            final video = VideoEvent.fromNostrEvent(event);
            videos.add(video);

            // Complete early if we've received all expected videos
            if (videos.length >= expectedCount && !completer.isCompleted) {
              cleanup();
              completer.complete(videos);
            }
          } catch (e) {
            Log.warning(
              'ProfileRepostedVideosBloc: Failed to parse event ${event.id}: '
              '$e',
              name: 'ProfileRepostedVideosBloc',
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
            'ProfileRepostedVideosBloc: Stream error: $error',
            name: 'ProfileRepostedVideosBloc',
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
        'ProfileRepostedVideosBloc: Failed to fetch from relay: $e',
        name: 'ProfileRepostedVideosBloc',
        category: LogCategory.video,
      );
      await cleanup();
      return videos;
    }
  }
}
