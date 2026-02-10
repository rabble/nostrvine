// ABOUTME: BLoC for searching user profiles via ProfileRepository.
// ABOUTME: Enriches results with profile pictures from UserProfileService.

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/services/user_profile_service.dart';
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
/// After search results arrive, triggers background profile fetches for
/// results missing pictures. When [UserProfileService] notifies that
/// profiles have been updated, enriches the results with cached pictures.
class UserSearchBloc extends Bloc<UserSearchEvent, UserSearchState> {
  UserSearchBloc({
    required ProfileRepository profileRepository,
    UserProfileService? userProfileService,
  }) : _profileRepository = profileRepository,
       _userProfileService = userProfileService,
       super(const UserSearchState()) {
    on<UserSearchQueryChanged>(
      _onQueryChanged,
      transformer: _debounceRestartable(),
    );
    on<UserSearchCleared>(_onCleared);
    on<UserSearchLoadMore>(_onLoadMore, transformer: sequential());
    on<UserSearchProfilesEnriched>(
      _onProfilesEnriched,
      transformer: droppable(),
    );

    _userProfileService?.addListener(_onProfileCacheUpdated);
  }

  final ProfileRepository _profileRepository;
  final UserProfileService? _userProfileService;

  void _onProfileCacheUpdated() {
    if (state.status != UserSearchStatus.success || state.results.isEmpty)
      return;
    add(const UserSearchProfilesEnriched());
  }

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

      _prefetchMissingProfiles(results);
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

      _prefetchMissingProfiles(moreResults);
    } on Exception {
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  void _onProfilesEnriched(
    UserSearchProfilesEnriched event,
    Emitter<UserSearchState> emit,
  ) {
    final service = _userProfileService;
    if (service == null) return;

    var changed = false;
    final enriched = state.results.map((profile) {
      if (profile.picture?.isNotEmpty == true) return profile;
      final cached = service.getCachedProfile(profile.pubkey);
      if (cached?.picture?.isNotEmpty == true) {
        changed = true;
        return profile.copyWith(picture: cached!.picture);
      }
      return profile;
    }).toList();

    if (changed) {
      emit(
        state.copyWith(
          results: enriched,
          profileVersion: state.profileVersion + 1,
        ),
      );
    }
  }

  void _onCleared(UserSearchCleared event, Emitter<UserSearchState> emit) {
    emit(const UserSearchState());
  }

  /// Trigger background profile fetch for results missing pictures.
  void _prefetchMissingProfiles(List<UserProfile> results) {
    final service = _userProfileService;
    if (service == null) return;

    final pubkeys = results
        .where((p) {
          if (p.picture?.isNotEmpty == true) return false;
          return !service.hasProfile(p.pubkey) &&
              !service.shouldSkipProfileFetch(p.pubkey);
        })
        .map((p) => p.pubkey)
        .toList();

    if (pubkeys.isNotEmpty) {
      service.fetchMultipleProfiles(pubkeys);
    }
  }

  @override
  Future<void> close() {
    _userProfileService?.removeListener(_onProfileCacheUpdated);
    return super.close();
  }
}
