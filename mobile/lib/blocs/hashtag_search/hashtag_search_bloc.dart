// ABOUTME: BLoC for searching hashtags via HashtagRepository (Funnelcake API).
// ABOUTME: Debounces queries and delegates to server-side hashtag search.

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:stream_transform/stream_transform.dart';

part 'hashtag_search_event.dart';
part 'hashtag_search_state.dart';

/// Debounce duration for search queries
const _debounceDuration = Duration(milliseconds: 300);

/// Event transformer that debounces and restarts on new events
EventTransformer<E> _debounceRestartable<E>() {
  return (events, mapper) {
    return restartable<E>().call(events.debounce(_debounceDuration), mapper);
  };
}

/// BLoC for searching hashtags via the Funnelcake API.
///
/// Delegates search to [HashtagRepository] which calls the server-side
/// hashtag search endpoint. Results are sorted by popularity/trending
/// on the server.
class HashtagSearchBloc extends Bloc<HashtagSearchEvent, HashtagSearchState> {
  HashtagSearchBloc({required HashtagRepository hashtagRepository})
    : _hashtagRepository = hashtagRepository,
      super(const HashtagSearchState()) {
    on<HashtagSearchQueryChanged>(
      _onQueryChanged,
      transformer: _debounceRestartable(),
    );
    on<HashtagSearchCleared>(_onCleared);
  }

  final HashtagRepository _hashtagRepository;

  Future<void> _onQueryChanged(
    HashtagSearchQueryChanged event,
    Emitter<HashtagSearchState> emit,
  ) async {
    final query = event.query.trim().toLowerCase();

    // Empty query resets to initial state
    if (query.isEmpty) {
      emit(const HashtagSearchState());
      return;
    }

    emit(state.copyWith(status: HashtagSearchStatus.loading, query: query));

    try {
      final results = await _hashtagRepository.searchHashtags(
        query: query,
      );

      emit(
        state.copyWith(status: HashtagSearchStatus.success, results: results),
      );
    } on Exception {
      emit(state.copyWith(status: HashtagSearchStatus.failure));
    }
  }

  void _onCleared(
    HashtagSearchCleared event,
    Emitter<HashtagSearchState> emit,
  ) {
    emit(const HashtagSearchState());
  }
}
