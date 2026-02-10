// ABOUTME: BLoC for hashtag video feed
// ABOUTME: Uses VideosRepository.getVideosByHashtag for data fetching
// ABOUTME: Supports offset-based pagination (Funnelcake) with relay fallback

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:videos_repository/videos_repository.dart';

part 'hashtag_feed_event.dart';
part 'hashtag_feed_state.dart';

/// Number of videos to load per page.
///
/// Funnelcake returns lightweight search results (thumbnail + metadata)
/// so this can be larger than feeds that require relay lookups.
const _pageSize = 20;

/// BLoC for managing the hashtag video feed.
///
/// Handles:
/// - Loading videos by hashtag (via Funnelcake API or relay fallback)
/// - Offset-based pagination
/// - Pull-to-refresh functionality
class HashtagFeedBloc extends Bloc<HashtagFeedEvent, HashtagFeedState> {
  HashtagFeedBloc({required VideosRepository videosRepository})
    : _videosRepository = videosRepository,
      super(const HashtagFeedState()) {
    on<HashtagFeedStarted>(_onStarted);
    on<HashtagFeedLoadMoreRequested>(_onLoadMoreRequested);
    on<HashtagFeedRefreshRequested>(_onRefreshRequested);
  }

  final VideosRepository _videosRepository;

  /// Handle feed started event.
  Future<void> _onStarted(
    HashtagFeedStarted event,
    Emitter<HashtagFeedState> emit,
  ) async {
    emit(
      state.copyWith(status: HashtagFeedStatus.loading, hashtag: event.hashtag),
    );

    try {
      final videos = await _videosRepository.getVideosByHashtag(
        tag: event.hashtag,
        limit: _pageSize,
      );

      emit(
        state.copyWith(
          status: HashtagFeedStatus.success,
          videos: videos,
          hasMore: videos.length == _pageSize,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: HashtagFeedStatus.failure));
    }
  }

  /// Handle load more request (pagination).
  Future<void> _onLoadMoreRequested(
    HashtagFeedLoadMoreRequested event,
    Emitter<HashtagFeedState> emit,
  ) async {
    if (state.status != HashtagFeedStatus.success ||
        state.isLoadingMore ||
        !state.hasMore ||
        state.videos.isEmpty) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    try {
      final newVideos = await _videosRepository.getVideosByHashtag(
        tag: state.hashtag,
        limit: _pageSize,
        offset: state.videos.length,
      );

      emit(
        state.copyWith(
          videos: [...state.videos, ...newVideos],
          hasMore: newVideos.length == _pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  /// Handle refresh request.
  Future<void> _onRefreshRequested(
    HashtagFeedRefreshRequested event,
    Emitter<HashtagFeedState> emit,
  ) async {
    emit(
      state.copyWith(
        status: HashtagFeedStatus.loading,
        videos: [],
        hasMore: true,
      ),
    );

    try {
      final videos = await _videosRepository.getVideosByHashtag(
        tag: state.hashtag,
        limit: _pageSize,
      );

      emit(
        state.copyWith(
          status: HashtagFeedStatus.success,
          videos: videos,
          hasMore: videos.length == _pageSize,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: HashtagFeedStatus.failure));
    }
  }
}
