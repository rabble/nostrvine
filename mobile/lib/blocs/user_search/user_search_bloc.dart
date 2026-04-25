// ABOUTME: BLoC for searching user profiles via ProfileRepository.

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/search_constants.dart';
import 'package:openvine/services/feed_performance_tracker.dart';
import 'package:profile_repository/profile_repository.dart';

part 'user_search_event.dart';
part 'user_search_state.dart';

/// Number of results per page
const _pageSize = 50;

/// BLoC for searching user profiles.
class UserSearchBloc extends Bloc<UserSearchEvent, UserSearchState> {
  UserSearchBloc({
    required ProfileRepository profileRepository,
    FollowRepository? followRepository,
    this.hasVideos = false,
    this.searchTimeout = const Duration(seconds: 20),
    FeedPerformanceTracker? feedTracker,
  }) : _profileRepository = profileRepository,
       _followRepository = followRepository,
       _feedTracker = feedTracker,
       super(const UserSearchState()) {
    on<UserSearchQueryChanged>(
      _onQueryChanged,
      transformer: debounceRestartable(),
    );
    on<UserSearchCleared>(_onCleared);
    on<UserSearchLoadMore>(_onLoadMore, transformer: sequential());
  }

  final ProfileRepository _profileRepository;

  /// Optional follow graph used to boost followed users to the top of the
  /// initial search page. Null for consumers that want raw server ranking.
  final FollowRepository? _followRepository;

  final FeedPerformanceTracker? _feedTracker;

  /// Whether to filter results to users who have uploaded videos.
  final bool hasVideos;

  /// Optional timeout for the progressive search stream.
  ///
  /// Set to `null` to disable the timeout entirely, which is useful in widget
  /// tests that rely on `pumpAndSettle()` with internally created blocs.
  final Duration? searchTimeout;

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

    // No dedup guard here — the restartable() transformer already cancels the
    // previous in-flight handler via switchMap. Adding a same-query skip caused
    // the search to get stuck in loading/empty-success states with no recovery
    // path (the user could never re-trigger the same query).

    emit(
      state.copyWith(
        status: UserSearchStatus.loading,
        query: query,
        offset: 0,
        hasMore: false,
        isLoadingMore: false,
      ),
    );

    _feedTracker?.startFeedLoad('user_search');
    var trackedFirst = false;

    // Snapshot the follow graph once for this query so every progressive
    // yield uses the same boost set. Boost ordering is applied inside the
    // repository (see ProfileRepository.searchUsersProgressive), keeping
    // ranking logic out of the BLoC.
    final followedPubkeys = _followRepository?.followingPubkeys.toSet();

    try {
      final searchStream = _profileRepository.searchUsersProgressive(
        query: query,
        limit: _pageSize,
        sortBy: 'followers',
        hasVideos: hasVideos,
        boostPubkeys: followedPubkeys,
      );

      await emit.forEach<List<UserProfile>>(
        searchTimeout == null
            ? searchStream
            : searchStream.timeout(searchTimeout!),
        onData: (results) {
          if (!trackedFirst && results.isNotEmpty) {
            trackedFirst = true;
            _feedTracker?.markFirstVideosReceived(
              'user_search',
              results.length,
            );
          }
          return state.copyWith(
            status: UserSearchStatus.loading,
            results: results,
            resultCount: results.length,
          );
        },
      );

      emit(
        state.copyWith(
          status: UserSearchStatus.success,
          offset: state.results.length,
          hasMore: state.results.length == _pageSize,
          isLoadingMore: false,
        ),
      );

      _feedTracker?.markFeedDisplayed('user_search', state.results.length);
    } on TimeoutException {
      // Stream timed out — emit success with whatever results accumulated
      // so far rather than leaving the UI stuck in loading.
      emit(
        state.copyWith(
          status: UserSearchStatus.success,
          offset: state.results.length,
          hasMore: false,
          isLoadingMore: false,
        ),
      );
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
      final moreResults = await _profileRepository
          .searchUsersProgressive(
            query: state.query,
            limit: _pageSize,
            offset: state.offset,
            sortBy: 'followers',
            hasVideos: hasVideos,
          )
          .last; // Stream always emits at least once for non-empty queries.

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
