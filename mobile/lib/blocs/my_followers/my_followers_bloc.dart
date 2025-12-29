// ABOUTME: BLoC for displaying current user's followers list
// ABOUTME: Fetches Kind 3 events that mention current user in 'p' tags
// TODO(Oscar): Move Nostr query logic to repository - https://github.com/divinevideo/divine-mobile/issues/571

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'my_followers_event.dart';
part 'my_followers_state.dart';

/// BLoC for displaying the current user's followers list.
///
/// Fetches Kind 3 (contact list) events that mention the current user
/// in their 'p' tags - these are users who follow the current user.
class MyFollowersBloc extends Bloc<MyFollowersEvent, MyFollowersState> {
  MyFollowersBloc({
    required NostrClient nostrClient,
    required FollowRepository followRepository,
  }) : _nostrClient = nostrClient,
       _followRepository = followRepository,
       super(const MyFollowersState()) {
    on<MyFollowersListLoadRequested>(_onLoadRequested);
    on<MyFollowersToggleFollowRequested>(_onToggleFollowRequested);
  }

  final NostrClient _nostrClient;
  final FollowRepository _followRepository;

  /// Handle request to load current user's followers list
  Future<void> _onLoadRequested(
    MyFollowersListLoadRequested event,
    Emitter<MyFollowersState> emit,
  ) async {
    emit(
      state.copyWith(status: MyFollowersStatus.loading, followersPubkeys: []),
    );

    try {
      final currentUserPubkey = _nostrClient.publicKey;
      final followers = await _fetchFollowersFromNostr(currentUserPubkey);
      emit(
        state.copyWith(
          status: MyFollowersStatus.success,
          followersPubkeys: followers,
        ),
      );
    } catch (e) {
      Log.error(
        'Failed to load followers list: $e',
        name: 'MyFollowersBloc',
        category: LogCategory.system,
      );
      emit(state.copyWith(status: MyFollowersStatus.failure));
    }
  }

  /// Fetch followers from Nostr relays
  Future<List<String>> _fetchFollowersFromNostr(String pubkey) async {
    final events = await _nostrClient.queryEvents([
      Filter(
        kinds: const [3], // Contact lists
        p: [pubkey], // Events that mention this pubkey
      ),
    ]);

    // Extract unique follower pubkeys (authors of events that follow target)
    final followers = <String>[];
    for (final event in events) {
      if (!followers.contains(event.pubkey)) {
        followers.add(event.pubkey);
      }
    }

    return followers;
  }

  /// Handle follow toggle request for a follower (follow back).
  /// Delegates to repository which handles the toggle logic internally.
  Future<void> _onToggleFollowRequested(
    MyFollowersToggleFollowRequested event,
    Emitter<MyFollowersState> emit,
  ) async {
    try {
      await _followRepository.toggleFollow(event.pubkey);
    } catch (e) {
      Log.error(
        'Failed to toggle follow for user: $e',
        name: 'MyFollowersBloc',
        category: LogCategory.system,
      );
    }
  }
}
