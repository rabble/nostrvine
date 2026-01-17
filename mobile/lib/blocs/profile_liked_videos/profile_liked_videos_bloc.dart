// ABOUTME: BLoC for managing profile liked videos grid
// ABOUTME: Syncs liked event IDs and fetches video data from cache/relays

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'profile_liked_videos_event.dart';
part 'profile_liked_videos_state.dart';

/// Number of videos to load per page for pagination.
const _pageSize = 18;

/// BLoC for managing profile liked videos.
///
/// Handles:
/// - Syncing liked event IDs from LikesRepository
/// - Loading video data for liked event IDs
/// - Caching: checks VideoEventService cache first
/// - Fetching: fetches missing videos from Nostr relays
/// - Filtering: excludes unsupported video formats
/// - Listening for like changes to update the list
/// - Pagination: loads videos in batches of [_pageSize]
class ProfileLikedVideosBloc
    extends Bloc<ProfileLikedVideosEvent, ProfileLikedVideosState> {
  ProfileLikedVideosBloc({
    required LikesRepository likesRepository,
    required VideoEventService videoEventService,
    required NostrClient nostrClient,
    String? targetUserPubkey,
  }) : _likesRepository = likesRepository,
       _videoEventService = videoEventService,
       _nostrClient = nostrClient,
       _targetUserPubkey = targetUserPubkey,
       super(const ProfileLikedVideosState()) {
    on<ProfileLikedVideosSyncRequested>(_onSyncRequested);
    on<ProfileLikedVideosSubscriptionRequested>(_onSubscriptionRequested);
    on<ProfileLikedVideosLoadMoreRequested>(_onLoadMoreRequested);
  }

  final LikesRepository _likesRepository;
  final VideoEventService _videoEventService;
  final NostrClient _nostrClient;

  /// The pubkey of the user whose likes to display.
  /// If null or same as current user, uses LikesRepository.
  /// If different, fetches likes directly from Nostr relays.
  final String? _targetUserPubkey;

  /// Whether we're viewing another user's profile (not our own).
  bool get _isOtherUserProfile =>
      _targetUserPubkey != null && _targetUserPubkey != _nostrClient.publicKey;

  /// Handle sync request - syncs liked IDs from repository then loads videos.
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

    emit(state.copyWith(status: ProfileLikedVideosStatus.syncing));

    try {
      // Get liked event IDs - either from repository (own) or relays (other)
      final likedEventIds = _isOtherUserProfile
          ? await _fetchOtherUserLikedEventIds()
          : await _fetchOwnLikedEventIds();

      Log.info(
        'ProfileLikedVideosBloc: Synced ${likedEventIds.length} liked IDs',
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

      // Fetch video data for the first page of liked IDs
      final firstPageIds = likedEventIds.take(_pageSize).toList();
      final videos = await _fetchVideos(firstPageIds);

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
          hasMoreContent: likedEventIds.length > _pageSize,
          clearError: true,
        ),
      );
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

  /// Fetch liked event IDs for the current user via LikesRepository.
  Future<List<String>> _fetchOwnLikedEventIds() async {
    final syncResult = await _likesRepository.syncUserReactions();
    return syncResult.orderedEventIds;
  }

  /// Fetch liked event IDs for another user via LikesRepository.
  ///
  /// Delegates to [LikesRepository.fetchUserLikes] which queries relays
  /// for Kind 7 reactions authored by the target user.
  Future<List<String>> _fetchOtherUserLikedEventIds() async {
    return _likesRepository.fetchUserLikes(_targetUserPubkey!);
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

    await emit.forEach<Set<String>>(
      _likesRepository.watchLikedEventIds(),
      onData: (likedIdsSet) {
        final newIds = likedIdsSet.toList();

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

          return state.copyWith(likedEventIds: newIds, videos: updatedVideos);
        }

        // If a video was liked, we need to fetch it asynchronously
        // For now, just update the IDs - the video will be fetched on next sync
        if (newIds.length > state.likedEventIds.length) {
          return state.copyWith(likedEventIds: newIds);
        }

        return state;
      },
    );
  }

  /// Handle load more request - fetches the next page of videos.
  ///
  /// Uses [state.videos.length] to determine the offset and fetches
  /// the next [_pageSize] videos from [state.likedEventIds].
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

    final currentCount = state.videos.length;
    final totalCount = state.likedEventIds.length;

    // No more to load
    if (currentCount >= totalCount) {
      emit(state.copyWith(hasMoreContent: false));
      return;
    }

    Log.info(
      'ProfileLikedVideosBloc: Loading more videos '
      '(current: $currentCount, total: $totalCount)',
      name: 'ProfileLikedVideosBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(isLoadingMore: true));

    try {
      // Get the next page of IDs
      final nextPageIds = state.likedEventIds
          .skip(currentCount)
          .take(_pageSize)
          .toList();

      // Fetch videos for the next page
      final newVideos = await _fetchVideos(nextPageIds);

      Log.info(
        'ProfileLikedVideosBloc: Loaded ${newVideos.length} more videos',
        name: 'ProfileLikedVideosBloc',
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
        'ProfileLikedVideosBloc: Failed to load more videos - $e',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  // TODO(any): Make logic easier, export part of logic in repository
  /// Fetch videos for the given event IDs.
  ///
  /// 1. Check cache first
  /// 2. Fetch missing videos from relays
  /// 3. Return ordered list matching the input order
  Future<List<VideoEvent>> _fetchVideos(List<String> likedEventIds) async {
    final cachedVideosMap = <String, VideoEvent>{};
    final missingIds = <String>[];

    // Check cache first
    for (final eventId in likedEventIds) {
      final cached = _videoEventService.getVideoById(eventId);
      if (cached != null) {
        cachedVideosMap[eventId] = cached;
      } else {
        missingIds.add(eventId);
      }
    }

    Log.info(
      'ProfileLikedVideosBloc: Found ${cachedVideosMap.length} in cache, '
      '${missingIds.length} need relay fetch',
      name: 'ProfileLikedVideosBloc',
      category: LogCategory.video,
    );

    // Fetch missing videos from relays
    if (missingIds.isNotEmpty) {
      final fetchedVideos = await _fetchVideosFromRelay(missingIds);
      for (final video in fetchedVideos) {
        cachedVideosMap[video.id] = video;
      }

      Log.info(
        'ProfileLikedVideosBloc: Fetched ${fetchedVideos.length} from relay',
        name: 'ProfileLikedVideosBloc',
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
  Future<List<VideoEvent>> _fetchVideosFromRelay(List<String> eventIds) async {
    if (eventIds.isEmpty) return [];

    final completer = Completer<List<VideoEvent>>();
    final videos = <VideoEvent>[];

    // Generate unique subscription ID for cleanup
    final subscriptionId =
        'liked_videos_bloc_${DateTime.now().millisecondsSinceEpoch}';

    /// Helper to clean up subscription resources
    Future<void> cleanup() async {
      await _nostrClient.unsubscribe(subscriptionId);
    }

    try {
      // Create filter for video events by ID
      // NIP-71 kinds: 34235 (horizontal), 34236 (vertical/short)
      final filter = Filter(ids: eventIds, kinds: [34235, 34236]);

      final eventStream = _nostrClient.subscribe(
        [filter],
        subscriptionId: subscriptionId,
        onEose: () {
          // Complete when all relays finish sending stored events
          if (!completer.isCompleted) {
            Log.info(
              'ProfileLikedVideosBloc: EOSE received, completing with '
              '${videos.length} videos',
              name: 'ProfileLikedVideosBloc',
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
          } catch (e) {
            Log.warning(
              'ProfileLikedVideosBloc: Failed to parse event ${event.id}: $e',
              name: 'ProfileLikedVideosBloc',
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
            'ProfileLikedVideosBloc: Stream error: $error',
            name: 'ProfileLikedVideosBloc',
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
        'ProfileLikedVideosBloc: Failed to fetch from relay: $e',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );
      await cleanup();
      return videos;
    }
  }
}
