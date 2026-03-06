// ABOUTME: BLoC for searching user profiles via ProfileRepository.

import 'dart:developer' as developer;

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/search_constants.dart';
import 'package:openvine/services/feed_performance_tracker.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:stream_transform/stream_transform.dart';

part 'user_search_event.dart';
part 'user_search_state.dart';

/// Number of results per page
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

/// BLoC for searching user profiles.
class UserSearchBloc extends Bloc<UserSearchEvent, UserSearchState> {
  UserSearchBloc({
    required ProfileRepository profileRepository,
    this.hasVideos = true,
    FeedPerformanceTracker? feedTracker,
  }) : _profileRepository = profileRepository,
       _feedTracker = feedTracker,
       super(const UserSearchState()) {
    on<UserSearchQueryChanged>(
      _onQueryChanged,
      transformer: _debounceRestartable(),
    );
    on<UserSearchCleared>(_onCleared);
    on<UserSearchLoadMore>(_onLoadMore, transformer: sequential());
  }

  final ProfileRepository _profileRepository;
  final FeedPerformanceTracker? _feedTracker;

  /// Whether to filter results to users who have uploaded videos.
  final bool hasVideos;

  Future<void> _onQueryChanged(
    UserSearchQueryChanged event,
    Emitter<UserSearchState> emit,
  ) async {
    final query = event.query.trim();

    // Empty query resets to initial state
    if (query.isEmpty || query.length < minSearchQueryLength) {
      emit(const UserSearchState());
      return;
    }

    if (!event.fetchResults) {
      final count = await _profileRepository.countUsersLocally(query: query);
      emit(
        UserSearchState(
          query: query,
          resultCount: count,
        ),
      );
      return;
    }

    if (query == state.query && state.status != UserSearchStatus.initial) {
      return;
    }

    emit(
      state.copyWith(
        status: UserSearchStatus.loading,
        query: query,
        resultCount: null,
        isLoadingMore: false,
      ),
    );

    _feedTracker?.startFeedLoad('user_search');

    try {
      final results = await _profileRepository.searchUsers(
        query: query,
        limit: _pageSize,
        sortBy: 'followers',
        hasVideos: hasVideos,
      );

      final withPic = results.where((p) => p.picture != null).length;
      developer.log(
        'Query "$query": ${results.length} results, '
        '$withPic with picture',
        name: 'UserSearchBloc',
      );

      _feedTracker?.markFirstVideosReceived(
        'user_search',
        results.length,
      );

      emit(
        state.copyWith(
          status: UserSearchStatus.success,
          results: results,
          resultCount: results.length,
          offset: results.length,
          hasMore: results.length == _pageSize,
          isLoadingMore: false,
        ),
      );

      _feedTracker?.markFeedDisplayed('user_search', results.length);
    } on Exception catch (e) {
      _feedTracker?.trackFeedError(
        'user_search',
        errorType: 'search_failed',
        errorMessage: e.toString(),
      );
      emit(state.copyWith(status: UserSearchStatus.failure));
    }
  }

  Future<void> _onLoadMore(
    UserSearchLoadMore event,
    Emitter<UserSearchState> emit,
  ) async {
    if (!state.hasMore || state.isLoadingMore || state.query.isEmpty) return;

    emit(state.copyWith(isLoadingMore: true));

    try {
      final moreResults = await _profileRepository.searchUsers(
        query: state.query,
        limit: _pageSize,
        offset: state.offset,
        sortBy: 'followers',
        hasVideos: hasVideos,
      );

      final allResults = [...state.results, ...moreResults];

      emit(
        state.copyWith(
          results: allResults,
          offset: allResults.length,
          hasMore: moreResults.length == _pageSize,
          isLoadingMore: false,
        ),
      );
    } on Exception {
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  void _onCleared(UserSearchCleared event, Emitter<UserSearchState> emit) {
    emit(const UserSearchState());
  }
}
