// ABOUTME: BLoC for searching hashtags via HashtagRepository (Funnelcake API).
// ABOUTME: Debounces queries and delegates to server-side hashtag search.

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:openvine/constants/search_constants.dart';
import 'package:openvine/services/feed_performance_tracker.dart';
import 'package:stream_transform/stream_transform.dart';

part 'hashtag_search_event.dart';
part 'hashtag_search_state.dart';

/// Event transformer that debounces and restarts on new events
EventTransformer<E> _debounceRestartable<E>() {
  return (events, mapper) {
    return restartable<E>().call(
      events.debounce(searchDebounceDuration),
      mapper,
    );
  };
}

/// Number of results per page for hashtag search pagination.
const _pageSize = 20;

/// BLoC for searching hashtags via the Funnelcake API.
///
/// Delegates search to [HashtagRepository] which handles remote search
/// with local fallback. Results are sorted by popularity/trending
/// on the server.
class HashtagSearchBloc extends Bloc<HashtagSearchEvent, HashtagSearchState> {
  HashtagSearchBloc({
    required HashtagRepository hashtagRepository,
    FeedPerformanceTracker? feedTracker,
  }) : _hashtagRepository = hashtagRepository,
       _feedTracker = feedTracker,
       super(const HashtagSearchState()) {
    on<HashtagSearchQueryChanged>(
      _onQueryChanged,
      transformer: _debounceRestartable(),
    );
    on<HashtagSearchLoadMore>(_onLoadMore, transformer: sequential());
    on<HashtagSearchCleared>(_onCleared);
  }

  final HashtagRepository _hashtagRepository;
  final FeedPerformanceTracker? _feedTracker;

  Future<void> _onQueryChanged(
    HashtagSearchQueryChanged event,
    Emitter<HashtagSearchState> emit,
  ) async {
    final query = event.query.trim().toLowerCase();

    // Empty query resets to initial state
    if (query.isEmpty || query.length < minSearchQueryLength) {
      emit(const HashtagSearchState());
      return;
    }

    if (query == state.query &&
        state.status != HashtagSearchStatus.initial &&
        state.status != HashtagSearchStatus.failure) {
      return;
    }

    emit(
      state.copyWith(
        status: HashtagSearchStatus.loading,
        query: query,
        resultCount: null,
      ),
    );

    _feedTracker?.startFeedLoad('hashtag_search');

    try {
      final results = await _hashtagRepository.searchHashtags(query: query);

      _feedTracker?.markFirstVideosReceived('hashtag_search', results.length);

      emit(
        state.copyWith(
          status: HashtagSearchStatus.success,
          results: results,
          resultCount: results.length,
          offset: results.length,
          hasMore: results.length == _pageSize,
          isLoadingMore: false,
        ),
      );

      _feedTracker?.markFeedDisplayed('hashtag_search', results.length);
    } on Exception catch (e) {
      // Defensive: repository.searchHashtags should never throw per its
      // contract, but we guard against unexpected violations to avoid
      // unhandled exceptions in the UI.
      _feedTracker?.trackFeedError(
        'hashtag_search',
        errorType: 'search_failed',
        errorMessage: e.toString(),
      );
      emit(state.copyWith(status: HashtagSearchStatus.failure));
    }
  }

  Future<void> _onLoadMore(
    HashtagSearchLoadMore event,
    Emitter<HashtagSearchState> emit,
  ) async {
    if (!state.hasMore || state.isLoadingMore || state.query.isEmpty) return;

    emit(state.copyWith(isLoadingMore: true));

    try {
      final moreResults = await _hashtagRepository.searchHashtags(
        query: state.query,
        offset: state.offset,
      );

      final existing = state.results.toSet();
      final deduped = moreResults.where((r) => !existing.contains(r)).toList();
      final allResults = [...state.results, ...deduped];

      emit(
        state.copyWith(
          results: allResults,
          offset: allResults.length,
          hasMore: moreResults.length == _pageSize,
          isLoadingMore: false,
        ),
      );
    } on Exception catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  void _onCleared(
    HashtagSearchCleared event,
    Emitter<HashtagSearchState> emit,
  ) {
    emit(const HashtagSearchState());
  }
}
