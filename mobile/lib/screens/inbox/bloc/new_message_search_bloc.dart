// ABOUTME: BLoC for the new message recipient search sheet.
// ABOUTME: Loads followed contacts and merges them with network search results.

import 'dart:developer' as developer;

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/search_constants.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:stream_transform/stream_transform.dart';

part 'new_message_search_event.dart';
part 'new_message_search_state.dart';

/// Event transformer that debounces and restarts on new events.
EventTransformer<E> _debounceRestartable<E>() {
  return (events, mapper) {
    return restartable<E>().call(
      events.debounce(searchDebounceDuration),
      mapper,
    );
  };
}

/// BLoC for the new message sheet that loads followed contacts and searches
/// for users to start a DM conversation.
class NewMessageSearchBloc
    extends Bloc<NewMessageSearchEvent, NewMessageSearchState> {
  NewMessageSearchBloc({
    required ProfileRepository profileRepository,
    required FollowRepository followRepository,
  }) : _profileRepository = profileRepository,
       _followRepository = followRepository,
       super(const NewMessageSearchState()) {
    on<NewMessageSearchStarted>(_onStarted);
    on<NewMessageSearchQueryChanged>(
      _onQueryChanged,
      transformer: _debounceRestartable(),
    );
    on<NewMessageSearchCleared>(_onCleared);
  }

  final ProfileRepository _profileRepository;
  final FollowRepository _followRepository;

  Future<void> _onStarted(
    NewMessageSearchStarted event,
    Emitter<NewMessageSearchState> emit,
  ) async {
    final pubkeys = _followRepository.followingPubkeys;
    final futures = pubkeys.map(
      (pk) => _profileRepository.getCachedProfile(pubkey: pk),
    );
    final results = await Future.wait(futures);
    final profiles = results.whereType<UserProfile>().toList()
      ..sort(
        (a, b) => a.bestDisplayName.toLowerCase().compareTo(
          b.bestDisplayName.toLowerCase(),
        ),
      );

    emit(
      state.copyWith(
        status: NewMessageSearchStatus.idle,
        contacts: profiles,
      ),
    );
  }

  Future<void> _onQueryChanged(
    NewMessageSearchQueryChanged event,
    Emitter<NewMessageSearchState> emit,
  ) async {
    final query = event.query.trim();

    if (query.isEmpty || query.length < minSearchQueryLength) {
      emit(
        state.copyWith(
          status: NewMessageSearchStatus.idle,
          query: '',
          results: const [],
        ),
      );
      return;
    }

    // Filter contacts locally for immediate display
    final filtered = _filterContacts(state.contacts, query);

    emit(
      state.copyWith(
        status: NewMessageSearchStatus.searching,
        query: query,
        results: filtered,
      ),
    );

    try {
      final networkResults = await _profileRepository.searchUsers(
        query: query,
        limit: 50,
        sortBy: 'followers',
      );

      developer.log(
        'Query "$query": ${networkResults.length} network results',
        name: 'NewMessageSearchBloc',
      );

      final merged = _mergeWithLocal(networkResults, filtered);

      emit(
        state.copyWith(
          status: NewMessageSearchStatus.searchSuccess,
          results: merged,
        ),
      );
    } on Exception {
      // On failure, keep the filtered local contacts visible
      emit(state.copyWith(status: NewMessageSearchStatus.searchFailure));
    }
  }

  void _onCleared(
    NewMessageSearchCleared event,
    Emitter<NewMessageSearchState> emit,
  ) {
    emit(
      state.copyWith(
        status: NewMessageSearchStatus.idle,
        query: '',
        results: const [],
      ),
    );
  }

  /// Filters contacts by display name or NIP-05.
  static List<UserProfile> _filterContacts(
    List<UserProfile> contacts,
    String query,
  ) {
    final lower = query.toLowerCase();
    return contacts.where((profile) {
      final name = profile.bestDisplayName.toLowerCase();
      final nip05 = (profile.nip05 ?? '').toLowerCase();
      return name.contains(lower) || nip05.contains(lower);
    }).toList();
  }

  /// Merges network results with local contacts, deduplicating by pubkey.
  /// Network results take precedence; local contacts fill gaps.
  static List<UserProfile> _mergeWithLocal(
    List<UserProfile> networkResults,
    List<UserProfile> localContacts,
  ) {
    if (localContacts.isEmpty) return networkResults;
    if (networkResults.isEmpty) return localContacts;

    final merged = <String, UserProfile>{};
    for (final profile in networkResults) {
      merged[profile.pubkey] = profile;
    }
    for (final profile in localContacts) {
      merged.putIfAbsent(profile.pubkey, () => profile);
    }
    return merged.values.toList();
  }
}
