// ABOUTME: BLoC for displaying a user's following list and handling follow/unfollow
// ABOUTME: Scoped to FollowingScreen - handles loading, refreshing, and operations

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'following_event.dart';
part 'following_state.dart';

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
    required AuthService authService,
    required String targetPubkey,
  }) : _followRepository = followRepository,
       _nostrClient = nostrClient,
       _authService = authService,
       _targetPubkey = targetPubkey,
       super(
         targetPubkey == authService.currentPublicKeyHex
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
  final AuthService _authService;
  final String _targetPubkey;
  StreamSubscription<Event>? _nostrSubscription;

  bool get _isCurrentUser => _targetPubkey == _authService.currentPublicKeyHex;

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

  /// Load other user's following from Nostr relays
  Future<void> _loadOtherUserFollowing(Emitter<FollowingState> emit) async {
    // Cancel any existing subscription
    await _nostrSubscription?.cancel();

    final completer = Completer<List<String>>();

    // Subscribe to the user's kind 3 contact list events
    final eventStream = _nostrClient.subscribe([
      Filter(
        authors: [_targetPubkey],
        kinds: const [3], // Contact lists
        limit: 1, // Get most recent only
      ),
    ]);

    // Apply timeout
    final timeoutStream = eventStream.timeout(
      const Duration(seconds: 5),
      onTimeout: (sink) {
        if (!completer.isCompleted) {
          completer.complete([]);
        }
        sink.close();
      },
    );

    _nostrSubscription = timeoutStream.listen(
      (event) {
        // Extract followed pubkeys from 'p' tags
        final following = <String>[];
        for (final tag in event.tags) {
          if (tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) {
            final followedPubkey = tag[1];
            if (!following.contains(followedPubkey)) {
              following.add(followedPubkey);
            }
          }
        }

        if (!completer.isCompleted) {
          completer.complete(following);
        }
      },
      onError: (Object error) {
        Log.error(
          'Error fetching following list: $error',
          name: 'FollowingBloc',
          category: LogCategory.relay,
        );
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete([]);
        }
      },
    );

    final following = await completer.future;
    emit(
      state.copyWith(
        status: FollowingStatus.success,
        followingPubkeys: following,
      ),
    );
  }

  /// Handle follow toggle request.
  /// Determines whether to follow or unfollow based on current state. UI will consume the stream for inmediate update.
  Future<void> _onFollowToggleRequested(
    FollowToggleRequested event,
    Emitter<FollowingState> emit,
  ) async {
    final isCurrentlyFollowing = _followRepository.isFollowing(event.pubkey);

    try {
      if (isCurrentlyFollowing) {
        await _followRepository.unfollow(event.pubkey);
        Log.info(
          'Successfully unfollowed user: ${event.pubkey}',
          name: 'FollowingBloc',
          category: LogCategory.system,
        );
      } else {
        await _followRepository.follow(event.pubkey);
        Log.info(
          'Successfully followed user: ${event.pubkey}',
          name: 'FollowingBloc',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error(
        'Failed to ${isCurrentlyFollowing ? 'unfollow' : 'follow'} user: $e',
        name: 'FollowingBloc',
        category: LogCategory.system,
      );
    }
  }

  @override
  Future<void> close() {
    _nostrSubscription?.cancel();
    return super.close();
  }
}
