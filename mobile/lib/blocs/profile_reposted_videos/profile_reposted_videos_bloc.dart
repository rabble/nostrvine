// ABOUTME: BLoC for managing profile reposted videos grid
// ABOUTME: Coordinates between RepostsRepository (for IDs) and VideosRepository
// ABOUTME: (cache-aware relay fetch with SQLite local storage)

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_sdk/aid.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:videos_repository/videos_repository.dart';

part 'profile_reposted_videos_event.dart';
part 'profile_reposted_videos_state.dart';

/// Number of videos to load per page for pagination.
const _pageSize = 18;

/// BLoC for managing profile reposted videos.
///
/// Coordinates between:
/// - [RepostsRepository]: Provides reposted addressable IDs (sync for own,
///   fetch for other)
/// - [VideosRepository]: Fetches video data with cache-first lookups via
///   SQLite local storage. Automatically checks cache before relay queries.
///
/// Handles:
/// - Syncing repost records from RepostsRepository
/// - Resolving addressable IDs to VideoEvents with cache-first pattern
/// - Filtering: excludes unsupported video formats
/// - Listening for repost changes to update the list
/// - Pagination: loads videos in batches of [_pageSize]
class ProfileRepostedVideosBloc
    extends Bloc<ProfileRepostedVideosEvent, ProfileRepostedVideosState> {
  ProfileRepostedVideosBloc({
    required RepostsRepository repostsRepository,
    required VideosRepository videosRepository,
    required String currentUserPubkey,
    String? targetUserPubkey,
  }) : _repostsRepository = repostsRepository,
       _videosRepository = videosRepository,
       _currentUserPubkey = currentUserPubkey,
       _targetUserPubkey = targetUserPubkey,
       super(const ProfileRepostedVideosState()) {
    on<ProfileRepostedVideosSyncRequested>(_onSyncRequested);
    on<ProfileRepostedVideosSubscriptionRequested>(_onSubscriptionRequested);
    on<ProfileRepostedVideosLoadMoreRequested>(_onLoadMoreRequested);
  }

  final RepostsRepository _repostsRepository;
  final VideosRepository _videosRepository;
  final String _currentUserPubkey;

  /// The pubkey of the user whose reposts to display.
  /// If null or same as current user, uses RepostsRepository sync.
  /// If different, fetches reposts directly from Nostr relays.
  final String? _targetUserPubkey;

  /// Whether we're viewing another user's profile (not our own).
  bool get _isOtherUserProfile =>
      _targetUserPubkey != null && _targetUserPubkey != _currentUserPubkey;

  /// Handle sync request - syncs repost records from repository then loads
  /// videos.
  ///
  /// For own profile: Uses "show cached first, refresh in background" pattern:
  /// 1. Load cached IDs from local storage (instant)
  /// 2. Fetch videos for cached IDs and show immediately
  /// 3. Sync from relay in background, update if new reposts found
  ///
  /// For other profiles: Fetch from relay (no cache available).
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

    // For other profiles, use the original flow (no cache available)
    if (_isOtherUserProfile) {
      await _syncOtherUserReposts(emit);
      return;
    }

    // For own profile: show cached data first, then refresh in background
    await _syncOwnProfileReposts(emit);
  }

  /// Sync reposts for other user's profile (no cache available).
  Future<void> _syncOtherUserReposts(
    Emitter<ProfileRepostedVideosState> emit,
  ) async {
    emit(state.copyWith(status: ProfileRepostedVideosStatus.syncing));

    try {
      final addressableIds = await _repostsRepository.fetchUserReposts(
        _targetUserPubkey!,
      );

      Log.info(
        'ProfileRepostedVideosBloc: Fetched ${addressableIds.length} repost '
        'IDs for other user',
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

      final firstPageIds = addressableIds.take(_pageSize).toList();
      final videos = await _fetchVideos(firstPageIds, cacheResults: true);

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

  /// Sync reposts for own profile using "show cached first" pattern.
  Future<void> _syncOwnProfileReposts(
    Emitter<ProfileRepostedVideosState> emit,
  ) async {
    try {
      // Step 1: Get cached IDs from local storage (instant - no relay)
      final cachedIds = await _repostsRepository
          .getOrderedRepostedAddressableIds();

      Log.info(
        'ProfileRepostedVideosBloc: Got ${cachedIds.length} cached repost IDs',
        name: 'ProfileRepostedVideosBloc',
        category: LogCategory.video,
      );

      // If we have cached data, load videos immediately
      if (cachedIds.isNotEmpty) {
        emit(
          state.copyWith(
            status: ProfileRepostedVideosStatus.loading,
            repostedAddressableIds: cachedIds,
          ),
        );

        // Fetch videos for cached IDs
        final firstPageIds = cachedIds.take(_pageSize).toList();
        final videos = await _fetchVideos(firstPageIds, cacheResults: true);

        Log.info(
          'ProfileRepostedVideosBloc: Loaded ${videos.length} videos from '
          'cache (first page of ${cachedIds.length} total)',
          name: 'ProfileRepostedVideosBloc',
          category: LogCategory.video,
        );

        emit(
          state.copyWith(
            status: ProfileRepostedVideosStatus.success,
            videos: videos,
            hasMoreContent: cachedIds.length > _pageSize,
            clearError: true,
          ),
        );

        // Step 2: Sync from relay in background (fire and forget)
        // The subscription handler will update the list if new reposts are found
        unawaited(
          _repostsRepository
              .syncUserReposts()
              .then((_) {
                Log.debug(
                  'ProfileRepostedVideosBloc: Background relay sync completed',
                  name: 'ProfileRepostedVideosBloc',
                  category: LogCategory.video,
                );
              })
              .catchError((e) {
                Log.warning(
                  'ProfileRepostedVideosBloc: Background sync failed - $e',
                  name: 'ProfileRepostedVideosBloc',
                  category: LogCategory.video,
                );
              }),
        );
      } else {
        // No cached data - need to sync from relay (show loading state)
        emit(state.copyWith(status: ProfileRepostedVideosStatus.syncing));

        final syncResult = await _repostsRepository.syncUserReposts();
        final addressableIds = syncResult.orderedAddressableIds;

        Log.info(
          'ProfileRepostedVideosBloc: Synced ${addressableIds.length} repost '
          'IDs from relay (no cache)',
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

        final firstPageIds = addressableIds.take(_pageSize).toList();
        final videos = await _fetchVideos(firstPageIds, cacheResults: true);

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
      }
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

        // If a video was reposted, we need to fetch it asynchronously.
        // For now, just update the IDs - the video will be fetched on next
        // sync.
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
  /// Uses [VideosRepository.getVideosByAddressableIds] which:
  /// 1. Queries Nostr relays for the videos
  /// 2. Falls back to Funnelcake API for videos not found on relays
  /// 3. Optionally saves fetched events to local storage
  ///
  /// When [cacheResults] is true, videos fetched from relay are saved to
  /// local storage for future cache hits. Only use for first page loads
  /// to avoid bloating the cache.
  ///
  /// Returns videos in the same order as [addressableIds], excluding:
  /// - Videos not found in cache or relay
  /// - Unsupported video formats (WebM on iOS/macOS)
  Future<List<VideoEvent>> _fetchVideos(
    List<String> addressableIds, {
    bool cacheResults = false,
  }) async {
    if (addressableIds.isEmpty) return [];

    // VideosRepository handles relay + Funnelcake fallback internally
    final videos = await _videosRepository.getVideosByAddressableIds(
      addressableIds,
      cacheResults: cacheResults,
    );

    Log.debug(
      'ProfileRepostedVideosBloc: Fetched ${videos.length}/${addressableIds.length} '
      'videos (cacheResults: $cacheResults)',
      name: 'ProfileRepostedVideosBloc',
      category: LogCategory.video,
    );

    // Filter unsupported formats
    return videos.where((v) => v.isSupportedOnCurrentPlatform).toList();
  }

  /// Compute the addressable ID for a video event.
  ///
  /// Format: `kind:pubkey:d-tag`
  /// Returns null if the video doesn't have a d-tag (vineId).
  String? _computeAddressableId(VideoEvent video) {
    if (video.vineId == null) return null;
    return AId(
      kind: EventKind.videoVertical,
      pubkey: video.pubkey,
      dTag: video.vineId!,
    ).toAString();
  }
}
