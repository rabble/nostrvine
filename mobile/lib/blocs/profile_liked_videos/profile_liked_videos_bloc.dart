// ABOUTME: BLoC for managing profile liked videos grid
// ABOUTME: Coordinates between LikesRepository (for IDs) and VideosRepository
// ABOUTME: (cache-aware relay fetch with SQLite local storage)

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

part 'profile_liked_videos_event.dart';
part 'profile_liked_videos_state.dart';

/// Number of videos to load per page for pagination.
const _pageSize = 18;

/// BLoC for managing profile liked videos.
///
/// Coordinates between:
/// - [LikesRepository]: Provides liked event IDs (sync for own, fetch for other)
/// - [VideosRepository]: Fetches video data with cache-first lookups via
///   SQLite local storage. Automatically checks cache before relay queries.
///
/// Handles:
/// - Syncing liked event IDs from LikesRepository
/// - Loading video data with cache-first pattern (SQLite → relay fallback)
/// - Filtering: excludes unsupported video formats
/// - Listening for like changes to update the list
/// - Pagination: loads videos in batches of [_pageSize]
class ProfileLikedVideosBloc
    extends Bloc<ProfileLikedVideosEvent, ProfileLikedVideosState> {
  ProfileLikedVideosBloc({
    required LikesRepository likesRepository,
    required VideosRepository videosRepository,
    required String currentUserPubkey,
    String? targetUserPubkey,
  }) : _likesRepository = likesRepository,
       _videosRepository = videosRepository,
       _currentUserPubkey = currentUserPubkey,
       _targetUserPubkey = targetUserPubkey,
       super(const ProfileLikedVideosState()) {
    on<ProfileLikedVideosSyncRequested>(_onSyncRequested);
    on<ProfileLikedVideosSubscriptionRequested>(_onSubscriptionRequested);
    on<ProfileLikedVideosLoadMoreRequested>(_onLoadMoreRequested);
  }

  final LikesRepository _likesRepository;
  final VideosRepository _videosRepository;
  final String _currentUserPubkey;

  /// The pubkey of the user whose likes to display.
  /// If null or same as current user, uses LikesRepository sync.
  /// If different, fetches likes directly from Nostr relays.
  final String? _targetUserPubkey;

  /// Whether we're viewing another user's profile (not our own).
  bool get _isOtherUserProfile =>
      _targetUserPubkey != null && _targetUserPubkey != _currentUserPubkey;

  /// Handle sync request - syncs liked IDs from repository then loads videos.
  ///
  /// For own profile: Uses "show cached first, refresh in background" pattern:
  /// 1. Load cached IDs from local storage (instant)
  /// 2. Fetch videos for cached IDs and show immediately
  /// 3. Sync from relay in background, update if new likes found
  ///
  /// For other profiles: Fetch from relay (no cache available).
  Future<void> _onSyncRequested(
    ProfileLikedVideosSyncRequested event,
    Emitter<ProfileLikedVideosState> emit,
  ) async {
    // Don't re-sync if already syncing
    if (state.status == ProfileLikedVideosStatus.syncing) return;

    Log.info(
      'ProfileLikedVideosBloc: Starting sync for '
      '${_isOtherUserProfile ? "other user" : "own profile"}',
      name: 'ProfileLikedVideosBloc',
      category: LogCategory.video,
    );

    // For other profiles, use the original flow (no cache available)
    if (_isOtherUserProfile) {
      await _syncOtherUserLikes(emit);
      return;
    }

    // For own profile: show cached data first, then refresh in background
    await _syncOwnProfileLikes(emit);
  }

  /// Sync likes for other user's profile (no cache available).
  Future<void> _syncOtherUserLikes(
    Emitter<ProfileLikedVideosState> emit,
  ) async {
    emit(state.copyWith(status: ProfileLikedVideosStatus.syncing));

    try {
      final likedEventIds = await _likesRepository.fetchUserLikes(
        _targetUserPubkey!,
      );

      Log.info(
        'ProfileLikedVideosBloc: Fetched ${likedEventIds.length} liked IDs '
        'for other user',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );

      if (likedEventIds.isEmpty) {
        emit(
          state.copyWith(
            status: ProfileLikedVideosStatus.success,
            videos: [],
            likedEventIds: [],
            hasMoreContent: false,
            clearError: true,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          status: ProfileLikedVideosStatus.loading,
          likedEventIds: likedEventIds,
        ),
      );

      final firstPageIds = likedEventIds.take(_pageSize).toList();
      final videos = await _fetchVideos(firstPageIds, cacheResults: true);

      Log.info(
        'ProfileLikedVideosBloc: Loaded ${videos.length} videos '
        '(first page of ${likedEventIds.length} total)',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );

      emit(
        state.copyWith(
          status: ProfileLikedVideosStatus.success,
          videos: videos,
          hasMoreContent: likedEventIds.length > firstPageIds.length,
          nextPageOffset: firstPageIds.length,
          clearError: true,
        ),
      );
    } on FetchLikesFailedException catch (e) {
      Log.error(
        'ProfileLikedVideosBloc: Fetch likes failed - ${e.message}',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          status: ProfileLikedVideosStatus.failure,
          error: ProfileLikedVideosError.syncFailed,
        ),
      );
    } catch (e) {
      Log.error(
        'ProfileLikedVideosBloc: Failed to load videos - $e',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          status: ProfileLikedVideosStatus.failure,
          error: ProfileLikedVideosError.loadFailed,
        ),
      );
    }
  }

  /// Sync likes for own profile using "show cached first" pattern.
  Future<void> _syncOwnProfileLikes(
    Emitter<ProfileLikedVideosState> emit,
  ) async {
    try {
      // Step 1: Get cached IDs from local storage (instant - no relay)
      final cachedIds = await _likesRepository.getOrderedLikedEventIds();

      Log.info(
        'ProfileLikedVideosBloc: Got ${cachedIds.length} cached liked IDs',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );

      // If we have cached data, load videos immediately
      if (cachedIds.isNotEmpty) {
        emit(
          state.copyWith(
            status: ProfileLikedVideosStatus.loading,
            likedEventIds: cachedIds,
          ),
        );

        // Fetch videos for cached IDs
        final firstPageIds = cachedIds.take(_pageSize).toList();
        final videos = await _fetchVideos(firstPageIds, cacheResults: true);

        Log.info(
          'ProfileLikedVideosBloc: Loaded ${videos.length} videos from cache '
          '(first page of ${cachedIds.length} total)',
          name: 'ProfileLikedVideosBloc',
          category: LogCategory.video,
        );

        emit(
          state.copyWith(
            status: ProfileLikedVideosStatus.success,
            videos: videos,
            hasMoreContent: cachedIds.length > firstPageIds.length,
            nextPageOffset: firstPageIds.length,
            clearError: true,
          ),
        );

        // Step 2: Sync from relay in background (fire and forget)
        // The subscription handler will update the list if new likes are found
        unawaited(
          _likesRepository
              .syncUserReactions()
              .then((_) {
                Log.debug(
                  'ProfileLikedVideosBloc: Background relay sync completed',
                  name: 'ProfileLikedVideosBloc',
                  category: LogCategory.video,
                );
              })
              .catchError((e) {
                Log.warning(
                  'ProfileLikedVideosBloc: Background sync failed - $e',
                  name: 'ProfileLikedVideosBloc',
                  category: LogCategory.video,
                );
              }),
        );
      } else {
        // No cached data - need to sync from relay (show loading state)
        emit(state.copyWith(status: ProfileLikedVideosStatus.syncing));

        final syncResult = await _likesRepository.syncUserReactions();
        final likedEventIds = syncResult.orderedEventIds;

        Log.info(
          'ProfileLikedVideosBloc: Synced ${likedEventIds.length} liked IDs '
          'from relay (no cache)',
          name: 'ProfileLikedVideosBloc',
          category: LogCategory.video,
        );

        if (likedEventIds.isEmpty) {
          emit(
            state.copyWith(
              status: ProfileLikedVideosStatus.success,
              videos: [],
              likedEventIds: [],
              hasMoreContent: false,
              clearError: true,
            ),
          );
          return;
        }

        emit(
          state.copyWith(
            status: ProfileLikedVideosStatus.loading,
            likedEventIds: likedEventIds,
          ),
        );

        final firstPageIds = likedEventIds.take(_pageSize).toList();
        final videos = await _fetchVideos(firstPageIds, cacheResults: true);

        Log.info(
          'ProfileLikedVideosBloc: Loaded ${videos.length} videos '
          '(first page of ${likedEventIds.length} total)',
          name: 'ProfileLikedVideosBloc',
          category: LogCategory.video,
        );

        emit(
          state.copyWith(
            status: ProfileLikedVideosStatus.success,
            videos: videos,
            hasMoreContent: likedEventIds.length > firstPageIds.length,
            nextPageOffset: firstPageIds.length,
            clearError: true,
          ),
        );
      }
    } on SyncFailedException catch (e) {
      Log.error(
        'ProfileLikedVideosBloc: Sync failed - ${e.message}',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          status: ProfileLikedVideosStatus.failure,
          error: ProfileLikedVideosError.syncFailed,
        ),
      );
    } catch (e) {
      Log.error(
        'ProfileLikedVideosBloc: Failed to load videos - $e',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          status: ProfileLikedVideosStatus.failure,
          error: ProfileLikedVideosError.loadFailed,
        ),
      );
    }
  }

  /// Subscribe to liked IDs changes and update the video list reactively.
  ///
  /// Uses emit.forEach to listen to the repository stream and emit state
  /// changes when liked IDs change (videos added or removed).
  ///
  /// Note: This only works for the current user's own profile, as the
  /// LikesRepository only tracks the authenticated user's likes.
  /// For other users' profiles, this subscription has no effect.
  Future<void> _onSubscriptionRequested(
    ProfileLikedVideosSubscriptionRequested event,
    Emitter<ProfileLikedVideosState> emit,
  ) async {
    // Only subscribe for own profile - the repository only tracks current
    // user's likes, so watching it for other users would show wrong data.
    if (_isOtherUserProfile) return;

    await emit.forEach<List<String>>(
      _likesRepository.watchLikedEventIds(),
      onData: (newIds) {
        // Skip if IDs haven't changed
        if (listEquals(newIds, state.likedEventIds)) return state;

        // Skip if we haven't done initial sync yet
        if (state.status == ProfileLikedVideosStatus.initial ||
            state.status == ProfileLikedVideosStatus.syncing) {
          return state;
        }

        Log.info(
          'ProfileLikedVideosBloc: Liked IDs changed, updating list',
          name: 'ProfileLikedVideosBloc',
          category: LogCategory.video,
        );

        // If a video was unliked, remove it from the list immediately
        if (newIds.length < state.likedEventIds.length) {
          final removedIds = state.likedEventIds
              .where((id) => !newIds.contains(id))
              .toSet();
          final updatedVideos = state.videos
              .where((v) => !removedIds.contains(v.id))
              .toList();

          // Clamp offset to new list length (removed IDs may shift it)
          final adjustedOffset = state.nextPageOffset.clamp(0, newIds.length);

          return state.copyWith(
            likedEventIds: newIds,
            videos: updatedVideos,
            nextPageOffset: adjustedOffset,
          );
        }

        // If a video was liked, we need to fetch it asynchronously.
        // New likes are prepended (most recent first), so shift the offset
        // forward to keep existing pagination position correct.
        if (newIds.length > state.likedEventIds.length) {
          final addedCount = newIds.length - state.likedEventIds.length;
          return state.copyWith(
            likedEventIds: newIds,
            nextPageOffset: state.nextPageOffset + addedCount,
          );
        }

        return state;
      },
    );
  }

  /// Handle load more request - fetches the next page of videos.
  ///
  /// Uses [state.nextPageOffset] to track the position in [state.likedEventIds]
  /// and fetches the next [_pageSize] IDs. The offset advances by the number
  /// of IDs consumed, not the number of videos loaded (some IDs may not
  /// resolve to videos due to relay unavailability or format filtering).
  Future<void> _onLoadMoreRequested(
    ProfileLikedVideosLoadMoreRequested event,
    Emitter<ProfileLikedVideosState> emit,
  ) async {
    // Skip if not in success state, already loading, or no more content
    if (state.status != ProfileLikedVideosStatus.success ||
        state.isLoadingMore ||
        !state.hasMoreContent) {
      return;
    }

    final offset = state.nextPageOffset;
    final totalCount = state.likedEventIds.length;

    // No more IDs to consume
    if (offset >= totalCount) {
      emit(state.copyWith(hasMoreContent: false));
      return;
    }

    Log.info(
      'ProfileLikedVideosBloc: Loading more videos '
      '(offset: $offset, total: $totalCount)',
      name: 'ProfileLikedVideosBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(isLoadingMore: true));

    try {
      // Get the next page of IDs
      final nextPageIds = state.likedEventIds
          .skip(offset)
          .take(_pageSize)
          .toList();

      // Fetch videos for the next page
      final newVideos = await _fetchVideos(nextPageIds);

      Log.info(
        'ProfileLikedVideosBloc: Loaded ${newVideos.length} more videos',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );

      // Deduplicate: filter out any videos already loaded
      final existingIds = state.videos.map((v) => v.id).toSet();
      final uniqueNewVideos = newVideos
          .where((v) => !existingIds.contains(v.id))
          .toList();

      // Advance offset by IDs consumed (not videos loaded)
      final newOffset = offset + nextPageIds.length;

      // Append only unique videos
      final allVideos = [...state.videos, ...uniqueNewVideos];
      final hasMore = newOffset < totalCount;

      emit(
        state.copyWith(
          videos: allVideos,
          isLoadingMore: false,
          hasMoreContent: hasMore,
          nextPageOffset: newOffset,
        ),
      );
    } catch (e) {
      Log.error(
        'ProfileLikedVideosBloc: Failed to load more videos - $e',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  /// Fetch videos for the given event IDs.
  ///
  /// Uses [VideosRepository.getVideosByIds] which implements cache-first:
  /// 1. Checks SQLite local storage for cached events
  /// 2. Queries Nostr relays only for missing events
  /// 3. Optionally saves fetched events to cache
  ///
  /// When [cacheResults] is true, videos fetched from relay are saved to
  /// local storage for future cache hits. Only use for first page loads
  /// to avoid bloating the cache.
  ///
  /// Returns videos in the same order as [eventIds], excluding:
  /// - Videos not found in cache or relay
  /// - Unsupported video formats (WebM on iOS/macOS)
  Future<List<VideoEvent>> _fetchVideos(
    List<String> eventIds, {
    bool cacheResults = false,
  }) async {
    if (eventIds.isEmpty) return [];

    // VideosRepository handles cache-first lookup internally
    final videos = await _videosRepository.getVideosByIds(
      eventIds,
      cacheResults: cacheResults,
    );

    Log.debug(
      'ProfileLikedVideosBloc: Fetched ${videos.length}/${eventIds.length} videos '
      '(cacheResults: $cacheResults)',
      name: 'ProfileLikedVideosBloc',
      category: LogCategory.video,
    );

    // Filter unsupported formats
    return videos.where((v) => v.isSupportedOnCurrentPlatform).toList();
  }
}
