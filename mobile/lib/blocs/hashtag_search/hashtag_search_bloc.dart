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

typedef LocalHashtagSearch =
    Future<List<String>> Function(String query, {int limit});

/// Event transformer that debounces and restarts on new events
EventTransformer<E> _debounceRestartable<E>() {
  return (events, mapper) {
    return restartable<E>().call(
      events.debounce(searchDebounceDuration),
      mapper,
    );
  };
}

/// BLoC for searching hashtags via the Funnelcake API.
///
/// Delegates search to [HashtagRepository] which calls the server-side
/// hashtag search endpoint. Results are sorted by popularity/trending
/// on the server.
class HashtagSearchBloc extends Bloc<HashtagSearchEvent, HashtagSearchState> {
  HashtagSearchBloc({
    required HashtagRepository hashtagRepository,
    FeedPerformanceTracker? feedTracker,
    LocalHashtagSearch? localHashtagSearch,
  }) : _hashtagRepository = hashtagRepository,
       _feedTracker = feedTracker,
       _localHashtagSearch = localHashtagSearch,
       super(const HashtagSearchState()) {
    on<HashtagSearchQueryChanged>(
      _onQueryChanged,
      transformer: _debounceRestartable(),
    );
    on<HashtagSearchCleared>(_onCleared);
  }

  final HashtagRepository _hashtagRepository;
  final FeedPerformanceTracker? _feedTracker;
  final LocalHashtagSearch? _localHashtagSearch;

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

    if (!event.fetchResults) {
      emit(
        HashtagSearchState(
          query: query,
          resultCount: _hashtagRepository.countHashtagsLocally(query: query),
        ),
      );
      return;
    }

    if (query == state.query && state.status != HashtagSearchStatus.initial) {
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
      final remoteResults = await _hashtagRepository.searchHashtags(
        query: query,
      );
      final results = await _resolveResults(query, remoteResults);

      _feedTracker?.markFirstVideosReceived(
        'hashtag_search',
        results.length,
      );

      emit(
        state.copyWith(
          status: HashtagSearchStatus.success,
          results: results,
          resultCount: results.length,
        ),
      );

      _feedTracker?.markFeedDisplayed('hashtag_search', results.length);
    } on Exception catch (e) {
      final fallbackResults = await _searchLocalHashtags(query);
      if (fallbackResults.isNotEmpty) {
        _feedTracker?.markFirstVideosReceived(
          'hashtag_search',
          fallbackResults.length,
        );
        emit(
          state.copyWith(
            status: HashtagSearchStatus.success,
            results: fallbackResults,
            resultCount: fallbackResults.length,
          ),
        );
        _feedTracker?.markFeedDisplayed(
          'hashtag_search',
          fallbackResults.length,
        );
        return;
      }

      _feedTracker?.trackFeedError(
        'hashtag_search',
        errorType: 'search_failed',
        errorMessage: e.toString(),
      );
      emit(state.copyWith(status: HashtagSearchStatus.failure));
    }
  }

  void _onCleared(
    HashtagSearchCleared event,
    Emitter<HashtagSearchState> emit,
  ) {
    emit(const HashtagSearchState());
  }

  Future<List<String>> _resolveResults(
    String query,
    List<String> remoteResults,
  ) async {
    final filteredRemote = remoteResults
        .where((tag) => tag.toLowerCase().contains(query))
        .toList();
    if (filteredRemote.isNotEmpty) {
      return filteredRemote;
    }
    return _searchLocalHashtags(query);
  }

  Future<List<String>> _searchLocalHashtags(String query) async {
    final localHashtagSearch = _localHashtagSearch;
    if (localHashtagSearch == null) {
      return const [];
    }

    try {
      return await localHashtagSearch(query, limit: 20);
    } on Exception {
      return const [];
    }
  }
}
