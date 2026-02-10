// ABOUTME: BLoC for searching user profiles via ProfileRepository.

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:stream_transform/stream_transform.dart';

part 'user_search_event.dart';
part 'user_search_state.dart';

/// Debounce duration for search queries
const _debounceDuration = Duration(milliseconds: 300);

/// Number of results per page
const _pageSize = 50;

/// Event transformer that debounces and restarts on new events
EventTransformer<E> _debounceRestartable<E>() {
  return (events, mapper) {
    return restartable<E>().call(events.debounce(_debounceDuration), mapper);
  };
}

/// BLoC for searching user profiles.
///
class UserSearchBloc extends Bloc<UserSearchEvent, UserSearchState> {
  UserSearchBloc({required ProfileRepository profileRepository})
    : _profileRepository = profileRepository,
      super(const UserSearchState()) {
    on<UserSearchQueryChanged>(
      _onQueryChanged,
      transformer: _debounceRestartable(),
    );
    on<UserSearchCleared>(_onCleared);
    on<UserSearchLoadMore>(_onLoadMore, transformer: sequential());
  }

  final ProfileRepository _profileRepository;

  Future<void> _onQueryChanged(
    UserSearchQueryChanged event,
    Emitter<UserSearchState> emit,
  ) async {
    final query = event.query.trim();

    // Empty query resets to initial state
    if (query.isEmpty) {
      emit(const UserSearchState());
      return;
    }

    emit(state.copyWith(status: UserSearchStatus.loading, query: query));

    try {
      final results = await _profileRepository.searchUsers(
        query: query,
        limit: _pageSize,
        sortBy: 'followers',
        hasVideos: true,
      );
      emit(
        state.copyWith(
          status: UserSearchStatus.success,
          results: results,
          offset: results.length,
          hasMore: results.length == _pageSize,
          isLoadingMore: false,
        ),
      );
    } on Exception {
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
        hasVideos: true,
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
