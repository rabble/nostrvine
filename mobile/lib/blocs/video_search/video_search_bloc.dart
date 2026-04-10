// ABOUTME: BLoC for searching videos via VideosRepository.
// ABOUTME: Delegates search to the repository layer via a progressive stream.
// ABOUTME: Supports pagination via VideoSearchLoadMore for infinite scroll.

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/search_constants.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:videos_repository/videos_repository.dart';

part 'video_search_event.dart';
part 'video_search_state.dart';

/// Page size for API pagination.
const _pageSize = 50;

/// Event transformer that debounces and restarts on new events
EventTransformer<E> _debounceRestartable<E>() {
  return (events, mapper) {
    return restartable<E>().call(
      events.debounce(searchDebounceDuration),
      mapper,
    );
  };
}

/// BLoC for searching videos via [VideosRepository].
///
/// Delegates all search logic (local cache, REST API, NIP-50 relays)
/// to the repository layer, keeping the BLoC focused on state management.
///
/// Search is progressive — the repository stream yields accumulated
/// results as each source completes:
/// 1. Local cache results (instant)
/// 2. API or relay results (whichever finishes first)
/// 3. Remaining source results (all done)
///
/// After the initial search, [VideoSearchLoadMore] fetches additional
/// pages from the API for infinite scroll.
class VideoSearchBloc extends Bloc<VideoSearchEvent, VideoSearchState> {
  VideoSearchBloc({required VideosRepository videosRepository})
    : _videosRepository = videosRepository,
      super(const VideoSearchState()) {
    on<VideoSearchQueryChanged>(
      _onQueryChanged,
      transformer: _debounceRestartable(),
    );
    on<VideoSearchCleared>(_onCleared);
    on<VideoSearchLoadMore>(_onLoadMore, transformer: sequential());
  }

  final VideosRepository _videosRepository;

  Future<void> _onQueryChanged(
    VideoSearchQueryChanged event,
    Emitter<VideoSearchState> emit,
  ) async {
    final query = event.query.trim();

    if (query.isEmpty || query.length < minSearchQueryLength) {
      emit(const VideoSearchState());
      return;
    }

    if (query == state.query &&
        state.status != VideoSearchStatus.initial &&
        state.status != VideoSearchStatus.failure) {
      return;
    }

    emit(
      state.copyWith(
        status: VideoSearchStatus.searching,
        query: query,
        resultCount: null,
        apiOffset: 0,
        totalApiCount: null,
        hasMore: false,
        isLoadingMore: false,
      ),
    );

    try {
      await emit.forEach<List<VideoEvent>>(
        _videosRepository.searchVideos(query: query),
        onData: (videos) => state.copyWith(
          status: VideoSearchStatus.searching,
          videos: videos,
          resultCount: videos.length,
        ),
      );
      // Progressive stream complete — set pagination state.
      // One API page was consumed during the stream; assume more exist
      // only if we actually received results.
      emit(
        state.copyWith(
          status: VideoSearchStatus.success,
          apiOffset: _pageSize,
          hasMore: state.videos.isNotEmpty,
        ),
      );
    } on Exception catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: VideoSearchStatus.failure));
    }
  }

  Future<void> _onLoadMore(
    VideoSearchLoadMore event,
    Emitter<VideoSearchState> emit,
  ) async {
    if (!state.hasMore || state.isLoadingMore || state.query.isEmpty) return;

    emit(state.copyWith(isLoadingMore: true));

    try {
      final result = await _videosRepository.searchVideosViaApi(
        query: state.query,
        offset: state.apiOffset,
      );

      final merged = _videosRepository.deduplicateAndSortVideos(
        [...state.videos, ...result.videos],
      );
      final newOffset = state.apiOffset + _pageSize;

      emit(
        state.copyWith(
          videos: merged,
          resultCount: merged.length,
          apiOffset: newOffset,
          totalApiCount: result.totalCount,
          hasMore: newOffset < result.totalCount,
          isLoadingMore: false,
        ),
      );
    } on Exception catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  void _onCleared(VideoSearchCleared event, Emitter<VideoSearchState> emit) {
    emit(const VideoSearchState());
  }
}
