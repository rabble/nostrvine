// ABOUTME: BLoC for displaying a user's following list and handling follow/unfollow
// ABOUTME: Scoped to FollowingScreen - handles loading, refreshing, and operations

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'following_event.dart';
part 'following_state.dart';

// TODO(Oscar): we will split this bloc into MyFollowingBloc and OthersFollowingBloc to separate the logic of current user and seeing others profile. Related task https://github.com/divinevideo/divine-mobile/issues/571
/// BLoC for displaying a user's following list and handling follow/unfollow.
///
/// Scoped to [FollowingScreen]. Supports two modes:
/// - Current user: Uses [FollowRepository] for reactive updates via emit.forEach
/// - Other users: Fetches following list from Nostr relays (read-only)
///
/// For current user, the initial state is set optimistically with cached
/// repository data to prevent UI flash.
class FollowingBloc extends Bloc<FollowingEvent, FollowingState> {
  FollowingBloc({
    required FollowRepository followRepository,
    required NostrClient nostrClient,
    required String targetPubkey,
  }) : _followRepository = followRepository,
       _nostrClient = nostrClient,
       _targetPubkey = targetPubkey,
       super(
         targetPubkey == nostrClient.publicKey
             ? FollowingState(
                 status: FollowingStatus.success,
                 followingPubkeys: followRepository.followingPubkeys,
                 targetPubkey: targetPubkey,
               )
             : FollowingState(targetPubkey: targetPubkey),
       ) {
    on<FollowingListLoadRequested>(_onLoadRequested);
    on<FollowToggleRequested>(_onFollowToggleRequested);
  }

  final FollowRepository _followRepository;
  final NostrClient _nostrClient;
  final String _targetPubkey;

  bool get _isCurrentUser => _targetPubkey == _nostrClient.publicKey;

  /// Handle request to load a following list
  Future<void> _onLoadRequested(
    FollowingListLoadRequested event,
    Emitter<FollowingState> emit,
  ) async {
    try {
      if (_isCurrentUser) {
        await _listenCurrentUserFollowing(emit);
      } else {
        // For other users, we need to fetch from network so show loading
        emit(
          state.copyWith(
            status: FollowingStatus.loading,
            targetPubkey: _targetPubkey,
          ),
        );
        await _loadOtherUserFollowing(emit);
      }
    } catch (e) {
      Log.error(
        'Failed to load following list: $e',
        name: 'FollowingBloc',
        category: LogCategory.system,
      );
      emit(state.copyWith(status: FollowingStatus.failure));
    }
  }

  /// Listen current user's following from FollowRepository (reactive)
  Future<void> _listenCurrentUserFollowing(Emitter<FollowingState> emit) async {
    // Listen to repository stream for reactive updates
    await emit.forEach<List<String>>(
      _followRepository.followingStream,
      onData: (followingPubkeys) => state.copyWith(
        status: FollowingStatus.success,
        followingPubkeys: followingPubkeys,
      ),
      onError: (error, stackTrace) {
        Log.error(
          'Error in following stream: $error',
          name: 'FollowingBloc',
          category: LogCategory.system,
        );
        return state.copyWith(status: FollowingStatus.failure);
      },
    );
  }

  // TODO(Oscar): move the logic to the repository. Task related https://github.com/divinevideo/divine-mobile/issues/571. See also comments on this PR for more refactor https://github.com/divinevideo/divine-mobile/pull/717
  /// Load other user's following from Nostr relays
  Future<void> _loadOtherUserFollowing(Emitter<FollowingState> emit) async {
    // Query user's kind 3 contact list event
    final events = await _nostrClient.queryEvents([
      Filter(
        authors: [_targetPubkey],
        kinds: const [3], // Contact lists
        limit: 1, // Get most recent only
      ),
    ]);

    // Extract followed pubkeys from 'p' tags
    final following = <String>[];
    if (events.isNotEmpty) {
      final event = events.first;
      for (final tag in event.tags) {
        if (tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) {
          final followedPubkey = tag[1];
          if (!following.contains(followedPubkey)) {
            following.add(followedPubkey);
          }
        }
      }
    }

    emit(
      state.copyWith(
        status: FollowingStatus.success,
        followingPubkeys: following,
      ),
    );
  }

  /// Handle follow toggle request.
  /// Delegates to repository which handles the toggle logic internally.
  /// UI updates reactively via the repository's stream.
  Future<void> _onFollowToggleRequested(
    FollowToggleRequested event,
    Emitter<FollowingState> emit,
  ) async {
    try {
      await _followRepository.toggleFollow(event.pubkey);
    } catch (e) {
      // Error already logged in repository
      Log.error(
        'Failed to toggle follow for user: $e',
        name: 'FollowingBloc',
        category: LogCategory.system,
      );
    }
  }
}
