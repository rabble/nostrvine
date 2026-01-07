// ABOUTME: BLoC for displaying another user's followers list
// ABOUTME: Fetches Kind 3 events that mention target user in 'p' tags

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'others_followers_event.dart';
part 'others_followers_state.dart';

/// BLoC for displaying another user's followers list.
///
/// Fetches Kind 3 (contact list) events that mention the target user
/// in their 'p' tags - these are users who follow the target.
class OthersFollowersBloc
    extends Bloc<OthersFollowersEvent, OthersFollowersState> {
  OthersFollowersBloc({required FollowRepository followRepository})
    : _followRepository = followRepository,
      super(const OthersFollowersState()) {
    on<OthersFollowersListLoadRequested>(_onLoadRequested);
    on<OthersFollowersIncrementRequested>(_onIncrementRequested);
    on<OthersFollowersDecrementRequested>(_onDecrementRequested);
  }

  final FollowRepository _followRepository;

  /// Handle request to load another user's followers list
  Future<void> _onLoadRequested(
    OthersFollowersListLoadRequested event,
    Emitter<OthersFollowersState> emit,
  ) async {
    emit(
      state.copyWith(
        status: OthersFollowersStatus.loading,
        targetPubkey: event.targetPubkey,
        followersPubkeys: [],
      ),
    );

    try {
      final followers = await _followRepository.getFollowers(
        event.targetPubkey,
      );
      emit(
        state.copyWith(
          status: OthersFollowersStatus.success,
          followersPubkeys: followers,
        ),
      );
    } catch (e) {
      Log.error(
        'Failed to load followers list for ${event.targetPubkey}: $e',
        name: 'OthersFollowersBloc',
        category: LogCategory.system,
      );
      emit(state.copyWith(status: OthersFollowersStatus.failure));
    }
  }

  /// Optimistically add a follower to the list
  void _onIncrementRequested(
    OthersFollowersIncrementRequested event,
    Emitter<OthersFollowersState> emit,
  ) {
    // Only increment if not already in the list
    if (!state.followersPubkeys.contains(event.followerPubkey)) {
      emit(
        state.copyWith(
          followersPubkeys: [...state.followersPubkeys, event.followerPubkey],
        ),
      );
      Log.debug(
        'Optimistically added follower: ${event.followerPubkey}',
        name: 'OthersFollowersBloc',
        category: LogCategory.system,
      );
    }
  }

  /// Optimistically remove a follower from the list
  void _onDecrementRequested(
    OthersFollowersDecrementRequested event,
    Emitter<OthersFollowersState> emit,
  ) {
    // Only decrement if in the list
    if (state.followersPubkeys.contains(event.followerPubkey)) {
      emit(
        state.copyWith(
          followersPubkeys: state.followersPubkeys
              .where((pubkey) => pubkey != event.followerPubkey)
              .toList(),
        ),
      );
      Log.debug(
        'Optimistically removed follower: ${event.followerPubkey}',
        name: 'OthersFollowersBloc',
        category: LogCategory.system,
      );
    }
  }
}
