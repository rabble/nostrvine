// ABOUTME: BLoC for unified video feed with mode switching
// ABOUTME: Manages Home (following), New (latest), and Popular feeds
// ABOUTME: Uses VideosRepository for data fetching with cursor-based pagination

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

part 'video_feed_event.dart';
part 'video_feed_state.dart';

/// Number of videos to load per page.
const _pageSize = 5;

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
  }) : _videosRepository = videosRepository,
       _followRepository = followRepository,
       super(const VideoFeedState()) {
    on<VideoFeedStarted>(_onStarted);
    on<VideoFeedModeChanged>(_onModeChanged);
    on<VideoFeedLoadMoreRequested>(_onLoadMoreRequested);
    on<VideoFeedRefreshRequested>(_onRefreshRequested);
  }

  final VideosRepository _videosRepository;
  final FollowRepository _followRepository;

  /// Handle feed started event.
  Future<void> _onStarted(
    VideoFeedStarted event,
    Emitter<VideoFeedState> emit,
  ) async {
    emit(state.copyWith(status: VideoFeedStatus.loading, mode: event.mode));

    await _loadVideos(event.mode, emit);
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
      // Get cursor from oldest video
      final cursor = state.videos.last.createdAt;
      final newVideos = await _fetchVideosForMode(state.mode, until: cursor);

      emit(
        state.copyWith(
          videos: [...state.videos, ...newVideos],
          hasMore: newVideos.length == _pageSize,
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

  /// Load videos for the specified mode.
  Future<void> _loadVideos(FeedMode mode, Emitter<VideoFeedState> emit) async {
    try {
      final videos = await _fetchVideosForMode(mode);

      // Check for empty home feed due to no followed users
      if (mode == FeedMode.home &&
          videos.isEmpty &&
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

      emit(
        state.copyWith(
          status: VideoFeedStatus.success,
          videos: videos,
          hasMore: videos.length == _pageSize,
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
      case FeedMode.home:
        final authors = _followRepository.followingPubkeys;
        return _videosRepository.getHomeFeedVideos(
          authors: authors,
          limit: _pageSize,
          until: until,
        );

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
