// ABOUTME: BLoC for searching user profiles via NIP-50
// ABOUTME: Handles search query changes and manages search state

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:profile_repository/profile_repository.dart';

part 'user_search_event.dart';
part 'user_search_state.dart';

/// BLoC for searching user profiles.
///
/// Handles:
/// - Searching users via NIP-50 full-text search
/// - Managing loading and error states
/// - Clearing search results
class UserSearchBloc extends Bloc<UserSearchEvent, UserSearchState> {
  UserSearchBloc({
    required ProfileRepository profileRepository,
  }) : _profileRepository = profileRepository,
       super(const UserSearchState()) {
    on<UserSearchQueryChanged>(_onQueryChanged);
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

      emit(
        state.copyWith(
          status: UserSearchStatus.success,
          results: results,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: UserSearchStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onCleared(UserSearchCleared event, Emitter<UserSearchState> emit) {
    emit(const UserSearchState());
  }
}
