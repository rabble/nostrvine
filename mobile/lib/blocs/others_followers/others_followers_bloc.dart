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
    on<OthersFollowersToggleFollowRequested>(_onToggleFollowRequested);
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

  /// Handle follow toggle request for a follower.
  /// Delegates to repository which handles the toggle logic internally.
  Future<void> _onToggleFollowRequested(
    OthersFollowersToggleFollowRequested event,
    Emitter<OthersFollowersState> emit,
  ) async {
    try {
      await _followRepository.toggleFollow(event.pubkey);
    } catch (e) {
      Log.error(
        'Failed to toggle follow for user: $e',
        name: 'OthersFollowersBloc',
        category: LogCategory.system,
      );
    }
  }
}
