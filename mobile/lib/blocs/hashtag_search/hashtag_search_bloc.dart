// ABOUTME: BLoC for searching hashtags via HashtagService and TopHashtagsService.
// ABOUTME: Merges results from live video stats and curated top 1000 hashtags.

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/top_hashtags_service.dart';
import 'package:stream_transform/stream_transform.dart';

part 'hashtag_search_event.dart';
part 'hashtag_search_state.dart';

/// Debounce duration for search queries
const _debounceDuration = Duration(milliseconds: 300);

/// Maximum number of hashtag results to return
const _maxResults = 20;

/// Event transformer that debounces and restarts on new events
EventTransformer<E> _debounceRestartable<E>() {
  return (events, mapper) {
    return restartable<E>().call(events.debounce(_debounceDuration), mapper);
  };
}

/// BLoC for searching hashtags.
///
/// Merges results from two sources:
/// - [HashtagService]: live hashtag statistics from loaded video events
/// - [TopHashtagsService]: curated top 1000 popular hashtags
///
/// HashtagService results are prioritized, then TopHashtagsService fills
/// in additional matches not already found.
class HashtagSearchBloc extends Bloc<HashtagSearchEvent, HashtagSearchState> {
  HashtagSearchBloc({
    required HashtagService hashtagService,
    required TopHashtagsService topHashtagsService,
  }) : _hashtagService = hashtagService,
       _topHashtagsService = topHashtagsService,
       super(const HashtagSearchState()) {
    on<HashtagSearchQueryChanged>(
      _onQueryChanged,
      transformer: _debounceRestartable(),
    );
    on<HashtagSearchCleared>(_onCleared);
  }

  final HashtagService _hashtagService;
  final TopHashtagsService _topHashtagsService;

  void _onQueryChanged(
    HashtagSearchQueryChanged event,
    Emitter<HashtagSearchState> emit,
  ) {
    final query = event.query.trim();

    // Empty query resets to initial state
    if (query.isEmpty) {
      emit(const HashtagSearchState());
      return;
    }

    emit(state.copyWith(status: HashtagSearchStatus.loading, query: query));

    try {
      // Refresh stats to include any recently loaded videos
      _hashtagService.refreshHashtagStats();

      // Get results from both sources
      final liveResults = _hashtagService.searchHashtags(query);
      final curatedResults = _topHashtagsService.searchHashtags(query);

      // Merge: live results first, then curated for uncovered ones
      final seen = <String>{};
      final merged = <String>[];

      for (final hashtag in liveResults) {
        final lower = hashtag.toLowerCase();
        if (seen.add(lower)) {
          merged.add(hashtag);
        }
      }

      for (final hashtag in curatedResults) {
        final lower = hashtag.toLowerCase();
        if (seen.add(lower)) {
          merged.add(hashtag);
        }
      }

      final results = merged.take(_maxResults).toList();

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
