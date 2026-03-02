// ABOUTME: BLoC for searching videos via VideosRepository.
// ABOUTME: Delegates search to the repository layer via a progressive stream.
// ABOUTME: Uses emit.forEach on VideosRepository.searchVideos().

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:videos_repository/videos_repository.dart';

part 'video_search_event.dart';
part 'video_search_state.dart';

/// Debounce duration for search queries
const _debounceDuration = Duration(milliseconds: 300);

/// Event transformer that debounces and restarts on new events
EventTransformer<E> _debounceRestartable<E>() {
  return (events, mapper) {
    return restartable<E>().call(events.debounce(_debounceDuration), mapper);
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
class VideoSearchBloc extends Bloc<VideoSearchEvent, VideoSearchState> {
  VideoSearchBloc({required VideosRepository videosRepository})
    : _videosRepository = videosRepository,
      super(const VideoSearchState()) {
    on<VideoSearchQueryChanged>(
      _onQueryChanged,
      transformer: _debounceRestartable(),
    );
    on<VideoSearchCleared>(_onCleared);
  }

  final VideosRepository _videosRepository;

  Future<void> _onQueryChanged(
    VideoSearchQueryChanged event,
    Emitter<VideoSearchState> emit,
  ) async {
    final query = event.query.trim();

    if (query.isEmpty) {
      emit(const VideoSearchState());
      return;
    }

    if (query == state.query) return;

    emit(state.copyWith(status: VideoSearchStatus.searching, query: query));

    try {
      await emit.forEach<List<VideoEvent>>(
        _videosRepository.searchVideos(query: query),
        onData: (videos) => state.copyWith(
          status: VideoSearchStatus.searching,
          videos: videos,
        ),
      );
      emit(state.copyWith(status: VideoSearchStatus.success));
    } on Exception {
      emit(state.copyWith(status: VideoSearchStatus.failure));
    }
  }

  void _onCleared(VideoSearchCleared event, Emitter<VideoSearchState> emit) {
    emit(const VideoSearchState());
  }
}
