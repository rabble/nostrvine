// ABOUTME: BLoC for unified video feed with mode switching
// ABOUTME: Manages For You, Home (following), New (latest), and Popular feeds
// ABOUTME: Uses VideosRepository for data fetching with cursor-based pagination

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

part 'video_feed_event.dart';
part 'video_feed_state.dart';

/// Number of videos to load per page.
const _pageSize = 5;

/// Default interval between auto-refreshes of the home feed.
const _defaultAutoRefreshMinInterval = Duration(minutes: 10);

/// SharedPreferences key for persisting the selected feed mode.
const _feedModeKey = 'selected_feed_mode';

/// BLoC for managing the unified video feed.
///
/// Handles:
/// - Multiple feed modes (home, latest, popular)
/// - Pagination via cursor-based loading
/// - Following list changes for home feed
/// - Pull-to-refresh functionality
class VideoFeedBloc extends Bloc<VideoFeedEvent, VideoFeedState> {
  VideoFeedBloc({
    required VideosRepository videosRepository,
    required FollowRepository followRepository,
    SharedPreferences? sharedPreferences,
    Duration autoRefreshMinInterval = _defaultAutoRefreshMinInterval,
  }) : _videosRepository = videosRepository,
       _followRepository = followRepository,
       _sharedPreferences = sharedPreferences,
       _autoRefreshMinInterval = autoRefreshMinInterval,
       super(const VideoFeedState()) {
    on<VideoFeedStarted>(_onStarted);
    on<VideoFeedModeChanged>(_onModeChanged);
    on<VideoFeedLoadMoreRequested>(
      _onLoadMoreRequested,
      transformer: droppable(),
    );
    on<VideoFeedRefreshRequested>(_onRefreshRequested);
    on<VideoFeedAutoRefreshRequested>(_onAutoRefreshRequested);
    on<VideoFeedFollowingListChanged>(_onFollowingListChanged);
  }

  final VideosRepository _videosRepository;
  final FollowRepository _followRepository;
  final SharedPreferences? _sharedPreferences;
  final Duration _autoRefreshMinInterval;

  /// Tracks when the last successful load completed, used by
  /// [_onAutoRefreshRequested] to skip refreshes when data is fresh.
  DateTime? _lastRefreshedAt;

  /// Handle feed started event.
  ///
  /// After the initial load, subscribes to [FollowRepository.followingStream]
  /// so the home feed refreshes reactively when the user follows/unfollows
  /// someone. The first emission is skipped (BehaviorSubject replays its
  /// seed/last value) to avoid a redundant refresh on startup.
  ///
  /// If a feed mode was previously saved to SharedPreferences, that mode is
  /// restored. Otherwise [event.mode] is used.
  Future<void> _onStarted(
    VideoFeedStarted event,
    Emitter<VideoFeedState> emit,
  ) async {
    final savedModeName = _sharedPreferences?.getString(_feedModeKey);
    final mode = savedModeName != null
        ? FeedMode.values.firstWhere(
            (m) => m.name == savedModeName,
            orElse: () => event.mode,
          )
        : event.mode;

    emit(state.copyWith(status: VideoFeedStatus.loading, mode: mode));

    await _loadVideos(mode, emit);

    await emit.onEach<List<String>>(
      _followRepository.followingStream.skip(1),
      onData: (pubkeys) => add(VideoFeedFollowingListChanged(pubkeys)),
    );
  }

  /// Handle mode changed event.
  Future<void> _onModeChanged(
    VideoFeedModeChanged event,
    Emitter<VideoFeedState> emit,
  ) async {
    // Skip if already on this mode
    if (state.mode == event.mode && state.status == VideoFeedStatus.success) {
      return;
    }

    await _sharedPreferences?.setString(_feedModeKey, event.mode.name);

    emit(
      state.copyWith(
        status: VideoFeedStatus.loading,
        mode: event.mode,
        videos: [],
        hasMore: true,
        clearError: true,
      ),
    );

    await _loadVideos(event.mode, emit);
  }

  /// Handle load more request (pagination).
  Future<void> _onLoadMoreRequested(
    VideoFeedLoadMoreRequested event,
    Emitter<VideoFeedState> emit,
  ) async {
    // Skip if not in success state, already loading more, or no more content
    if (state.status != VideoFeedStatus.success ||
        state.isLoadingMore ||
        !state.hasMore ||
        state.videos.isEmpty) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    try {
      // Find the oldest createdAt among all loaded videos for the cursor.
      // For popular feed (sorted by engagement), state.videos.last is the
      // lowest-engagement video, not the oldest — using its createdAt would
      // skip older popular videos.
      final oldestCreatedAt = state.videos
          .map((v) => v.createdAt)
          .reduce((a, b) => a < b ? a : b);
      final cursor = oldestCreatedAt - 1;

      final newVideos = await _fetchVideosForMode(state.mode, until: cursor);

      // Filter out videos without valid URLs
      final validNewVideos = newVideos
          .where((v) => v.videoUrl != null)
          .toList();

      // Deduplicate by event ID. Funnelcake and Nostr can return
      // overlapping videos when Funnelcake runs out and we fall through
      // to Nostr. Without dedup, PooledVideoFeed's internal dedup
      // causes a count mismatch that breaks the pagination trigger.
      final seenIds = <String>{};
      final updatedVideos = <VideoEvent>[];
      for (final video in [...state.videos, ...validNewVideos]) {
        if (seenIds.add(video.id)) {
          updatedVideos.add(video);
        }
      }

      // Only sort chronological feeds by createdAt.
      // Popular feed preserves its engagement-based order.
      if (state.mode != FeedMode.popular) {
        updatedVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      emit(
        state.copyWith(
          videos: updatedVideos,
          // Only stop pagination when the server returns nothing.
          // Fewer than _pageSize can happen due to server-side filtering.
          hasMore: newVideos.isNotEmpty,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      Log.error(
        'VideoFeedBloc: Failed to load more videos - $e',
        name: 'VideoFeedBloc',
        category: LogCategory.video,
      );
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  /// Handle refresh request.
  Future<void> _onRefreshRequested(
    VideoFeedRefreshRequested event,
    Emitter<VideoFeedState> emit,
  ) async {
    emit(
      state.copyWith(
        status: VideoFeedStatus.loading,
        videos: [],
        hasMore: true,
        clearError: true,
      ),
    );

    await _loadVideos(state.mode, emit);
  }

  /// Handle auto-refresh request (dispatched by UI on app resume).
  ///
  /// Only refreshes when:
  /// - The current feed mode is [FeedMode.home]
  /// - The data is stale (last refresh was longer ago than
  ///   [_autoRefreshMinInterval])
  Future<void> _onAutoRefreshRequested(
    VideoFeedAutoRefreshRequested event,
    Emitter<VideoFeedState> emit,
  ) async {
    if (state.mode != FeedMode.home) return;

    final lastRefresh = _lastRefreshedAt;
    if (lastRefresh != null &&
        DateTime.now().difference(lastRefresh) < _autoRefreshMinInterval) {
      return;
    }

    emit(
      state.copyWith(
        status: VideoFeedStatus.loading,
        videos: [],
        hasMore: true,
        clearError: true,
      ),
    );

    await _loadVideos(state.mode, emit);
  }

  /// Handle following list changes from [FollowRepository].
  ///
  /// Only refreshes when the current mode is [FeedMode.home] and the
  /// feed has already been loaded (avoids double-loading on startup).
  Future<void> _onFollowingListChanged(
    VideoFeedFollowingListChanged event,
    Emitter<VideoFeedState> emit,
  ) async {
    if (state.mode != FeedMode.home) return;
    if (state.status == VideoFeedStatus.loading) return;

    emit(
      state.copyWith(
        status: VideoFeedStatus.loading,
        videos: [],
        hasMore: true,
        clearError: true,
      ),
    );

    await _loadVideos(FeedMode.home, emit);
  }

  /// Load videos for the specified mode.
  Future<void> _loadVideos(FeedMode mode, Emitter<VideoFeedState> emit) async {
    try {
      final videos = await _fetchVideosForMode(mode);

      // Filter out videos without valid URLs
      final validVideos = videos.where((v) => v.videoUrl != null).toList();

      // Check for empty home feed due to no followed users
      if (mode == FeedMode.home &&
          validVideos.isEmpty &&
          _followRepository.followingPubkeys.isEmpty) {
        emit(
          state.copyWith(
            status: VideoFeedStatus.success,
            videos: [],
            hasMore: false,
            error: VideoFeedError.noFollowedUsers,
          ),
        );
        return;
      }

      _lastRefreshedAt = DateTime.now();

      emit(
        state.copyWith(
          status: VideoFeedStatus.success,
          videos: validVideos,
          // Only stop pagination when no results at all.
          // Fewer than _pageSize can happen due to server-side filtering.
          hasMore: validVideos.isNotEmpty,
          clearError: true,
        ),
      );
    } catch (e) {
      Log.error(
        'VideoFeedBloc: Failed to load videos - $e',
        name: 'VideoFeedBloc',
        category: LogCategory.video,
      );

      emit(
        state.copyWith(
          status: VideoFeedStatus.failure,
          error: VideoFeedError.loadFailed,
        ),
      );
    }
  }

  /// Fetch videos for a specific mode from the repository.
  Future<List<VideoEvent>> _fetchVideosForMode(
    FeedMode mode, {
    int? until,
  }) async {
    switch (mode) {
      case FeedMode.forYou:
        final authors = _followRepository.followingPubkeys;
        final result = await _videosRepository.getHomeFeedVideos(
          authors: authors,
          limit: _pageSize,
          until: until,
        );
        return result.videos;

      case FeedMode.home:
        final authors = _followRepository.followingPubkeys;
        final result = await _videosRepository.getHomeFeedVideos(
          authors: authors,
          limit: _pageSize,
          until: until,
        );
        return result.videos;

      case FeedMode.latest:
        return _videosRepository.getNewVideos(limit: _pageSize, until: until);

      case FeedMode.popular:
        return _videosRepository.getPopularVideos(
          limit: _pageSize,
          until: until,
        );
    }
  }
}
