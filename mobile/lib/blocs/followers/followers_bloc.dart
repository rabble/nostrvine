// ABOUTME: BLoC for displaying a user's followers list
// ABOUTME: Fetches Kind 3 events that mention the target user in 'p' tags

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'followers_event.dart';
part 'followers_state.dart';

// TODO(Oscar): we will split this bloc into MyFollowersBloc and OthersFollowersBloc to separate the logic of current user and seeing others profile. Related task https://github.com/divinevideo/divine-mobile/issues/571
/// BLoC for displaying a user's followers list.
///
/// Fetches Kind 3 (contact list) events that mention the target user
/// in their 'p' tags - these are users who follow the target.
class FollowersBloc extends Bloc<FollowersEvent, FollowersState> {
  FollowersBloc({
    required FollowRepository followRepository,
    required NostrClient nostrClient,
  }) : _followRepository = followRepository,
       _nostrClient = nostrClient,
       super(const FollowersState()) {
    on<FollowersListLoadRequested>(_onLoadRequested);
    on<FollowerToggleFollowRequested>(_onToggleFollowRequested);
  }

  final FollowRepository _followRepository;
  final NostrClient _nostrClient;

  /// Handle request to load a followers list
  Future<void> _onLoadRequested(
    FollowersListLoadRequested event,
    Emitter<FollowersState> emit,
  ) async {
    emit(
      state.copyWith(
        status: FollowersStatus.loading,
        targetPubkey: event.pubkey,
        followersPubkeys: [], // Clear previous list
      ),
    );

    try {
      await _loadFollowers(event.pubkey, emit);
    } catch (e) {
      Log.error(
        'Failed to load followers list: $e',
        name: 'FollowersBloc',
        category: LogCategory.system,
      );
      emit(state.copyWith(status: FollowersStatus.failure));
    }
  }

  // TODO(Oscar): move the logic to the repository. Task related https://github.com/divinevideo/divine-mobile/issues/571. See also comments on this PR for more refactor https://github.com/divinevideo/divine-mobile/pull/717
  /// Load followers from Nostr relays
  Future<void> _loadFollowers(
    String pubkey,
    Emitter<FollowersState> emit,
  ) async {
    // Query kind 3 events that mention this pubkey in p tags
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

    emit(
      state.copyWith(
        status: FollowersStatus.success,
        followersPubkeys: followers,
      ),
    );
  }

  /// Handle follow toggle request for a follower.
  /// Delegates to repository which handles the toggle logic internally.
  Future<void> _onToggleFollowRequested(
    FollowerToggleFollowRequested event,
    Emitter<FollowersState> emit,
  ) async {
    try {
      await _followRepository.toggleFollow(event.pubkey);
    } catch (e) {
      Log.error(
        'Failed to toggle follow for user: $e',
        name: 'FollowersBloc',
        category: LogCategory.system,
      );
    }
  }
}
