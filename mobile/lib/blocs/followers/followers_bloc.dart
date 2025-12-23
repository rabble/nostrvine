// ABOUTME: BLoC for displaying a user's followers list
// ABOUTME: Fetches Kind 3 events that mention the target user in 'p' tags

import 'dart:async';

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
  StreamSubscription<Event>? _nostrSubscription;

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
    // Cancel any existing subscription
    await _nostrSubscription?.cancel();

    final followers = <String>[];
    final completer = Completer<void>();

    // Subscribe to kind 3 events that mention this pubkey in p tags
    final eventStream = _nostrClient.subscribe([
      Filter(
        kinds: const [3], // Contact lists
        p: [pubkey], // Events that mention this pubkey
      ),
    ]);

    // Apply timeout
    final timeoutStream = eventStream.timeout(
      const Duration(seconds: 5),
      onTimeout: (sink) {
        if (!completer.isCompleted) {
          completer.complete();
        }
        sink.close();
      },
    );

    _nostrSubscription = timeoutStream.listen(
      (event) {
        // Each author who has this pubkey in their contact list is a follower
        if (!followers.contains(event.pubkey)) {
          followers.add(event.pubkey);

          // Emit updated state with new follower
          emit(
            state.copyWith(
              status: FollowersStatus.success,
              followersPubkeys: List.from(followers),
            ),
          );
        }
      },
      onError: (Object error) {
        Log.error(
          'Error fetching followers list: $error',
          name: 'FollowersBloc',
          category: LogCategory.relay,
        );
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );

    await completer.future;

    // If no followers were found, ensure we're in success state with empty list
    if (followers.isEmpty) {
      emit(
        state.copyWith(status: FollowersStatus.success, followersPubkeys: []),
      );
    }
  }

  /// Handle follow toggle request for a follower.
  /// Uses the FollowRepository to follow/unfollow the user.
  Future<void> _onToggleFollowRequested(
    FollowerToggleFollowRequested event,
    Emitter<FollowersState> emit,
  ) async {
    final isCurrentlyFollowing = _followRepository.isFollowing(event.pubkey);

    try {
      if (isCurrentlyFollowing) {
        await _followRepository.unfollow(event.pubkey);
        Log.info(
          'Successfully unfollowed user: ${event.pubkey}',
          name: 'FollowersBloc',
          category: LogCategory.system,
        );
      } else {
        await _followRepository.follow(event.pubkey);
        Log.info(
          'Successfully followed user: ${event.pubkey}',
          name: 'FollowersBloc',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error(
        'Failed to ${isCurrentlyFollowing ? 'unfollow' : 'follow'} user: $e',
        name: 'FollowersBloc',
        category: LogCategory.system,
      );
    }
  }

  /// Check if the current user is following a specific pubkey
  bool isFollowing(String pubkey) => _followRepository.isFollowing(pubkey);

  @override
  Future<void> close() {
    _nostrSubscription?.cancel();
    return super.close();
  }
}
