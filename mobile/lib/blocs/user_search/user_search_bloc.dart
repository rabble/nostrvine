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
      final results = await _profileRepository.searchUsers(query: query);
      emit(state.copyWith(status: UserSearchStatus.success, results: results));
    } on Exception {
      emit(state.copyWith(status: UserSearchStatus.failure));
    }
  }

  void _onCleared(UserSearchCleared event, Emitter<UserSearchState> emit) {
    emit(const UserSearchState());
  }
}
