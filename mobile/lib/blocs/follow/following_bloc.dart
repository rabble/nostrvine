// ABOUTME: BLoC for displaying a user's following list
// ABOUTME: Scoped to FollowingScreen - handles loading and refreshing the list

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

/// BLoC for displaying a user's following list.
///
/// Scoped to [FollowingScreen]. Supports two modes:
/// - Current user: Uses [FollowRepository] for reactive updates via emit.forEach
/// - Other users: Fetches following list from Nostr relays (read-only)
class FollowingBloc extends Bloc<FollowingEvent, FollowingState> {
  FollowingBloc({
    required FollowRepository followRepository,
    required NostrClient nostrClient,
    required AuthService authService,
  })  : _followRepository = followRepository,
        _nostrClient = nostrClient,
        _authService = authService,
        super(const FollowingState()) {
    on<FollowingListLoadRequested>(_onLoadRequested);
    on<FollowingListRefreshRequested>(_onRefreshRequested);
  }

  final FollowRepository _followRepository;
  final NostrClient _nostrClient;
  final AuthService _authService;
  StreamSubscription<Event>? _nostrSubscription;

  bool _isCurrentUser(String pubkey) =>
      pubkey == _authService.currentPublicKeyHex;

  /// Handle request to load a following list
  Future<void> _onLoadRequested(
    FollowingListLoadRequested event,
    Emitter<FollowingState> emit,
  ) async {
    emit(state.copyWith(
      status: FollowingStatus.loading,
      targetPubkey: event.pubkey,
    ));

    try {
      if (_isCurrentUser(event.pubkey)) {
        await _loadCurrentUserFollowing(emit);
      } else {
        await _loadOtherUserFollowing(event.pubkey, emit);
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

  /// Load current user's following from FollowRepository (reactive)
  /// Uses emit.forEach to listen to the repository stream
  Future<void> _loadCurrentUserFollowing(Emitter<FollowingState> emit) async {
    // Emit current state immediately
    emit(state.copyWith(
      status: FollowingStatus.success,
      followingPubkeys: _followRepository.followingPubkeys,
    ));

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
  Future<void> _loadOtherUserFollowing(
    String pubkey,
    Emitter<FollowingState> emit,
  ) async {
    // Cancel any existing subscription
    await _nostrSubscription?.cancel();

    final completer = Completer<List<String>>();

    // Subscribe to the user's kind 3 contact list events
    final eventStream = _nostrClient.subscribe([
      Filter(
        authors: [pubkey],
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
    emit(state.copyWith(
      status: FollowingStatus.success,
      followingPubkeys: following,
    ));
  }

  /// Handle refresh request
  Future<void> _onRefreshRequested(
    FollowingListRefreshRequested event,
    Emitter<FollowingState> emit,
  ) async {
    add(FollowingListLoadRequested(event.pubkey));
  }

  @override
  Future<void> close() {
    _nostrSubscription?.cancel();
    return super.close();
  }
}
