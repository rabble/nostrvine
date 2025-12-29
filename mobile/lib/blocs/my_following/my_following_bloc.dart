// ABOUTME: BLoC for managing current user's following list with reactive updates
// ABOUTME: Listens to FollowRepository stream for real-time following changes

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'my_following_event.dart';
part 'my_following_state.dart';

/// BLoC for managing the current user's following list.
///
/// Uses [FollowRepository] for reactive updates via emit.forEach.
/// Initial state is set optimistically with cached repository data
/// to prevent UI flash.
class MyFollowingBloc extends Bloc<MyFollowingEvent, MyFollowingState> {
  MyFollowingBloc({required FollowRepository followRepository})
    : _followRepository = followRepository,
      super(
        MyFollowingState(
          status: MyFollowingStatus.success,
          followingPubkeys: followRepository.followingPubkeys,
        ),
      ) {
    on<MyFollowingListLoadRequested>(_onLoadRequested);
    on<MyFollowingToggleRequested>(_onToggleRequested);
  }

  final FollowRepository _followRepository;

  /// Listen to repository stream for reactive updates
  Future<void> _onLoadRequested(
    MyFollowingListLoadRequested event,
    Emitter<MyFollowingState> emit,
  ) async {
    try {
      await emit.forEach<List<String>>(
        _followRepository.followingStream,
        onData: (followingPubkeys) => state.copyWith(
          status: MyFollowingStatus.success,
          followingPubkeys: followingPubkeys,
        ),
        onError: (error, stackTrace) {
          Log.error(
            'Error in following stream: $error',
            name: 'MyFollowingBloc',
            category: LogCategory.system,
          );
          return state.copyWith(status: MyFollowingStatus.failure);
        },
      );
    } catch (e) {
      Log.error(
        'Failed to listen to following stream: $e',
        name: 'MyFollowingBloc',
        category: LogCategory.system,
      );
      emit(state.copyWith(status: MyFollowingStatus.failure));
    }
  }

  /// Handle follow toggle request.
  /// Delegates to repository which handles the toggle logic internally.
  /// UI updates reactively via the repository's stream.
  Future<void> _onToggleRequested(
    MyFollowingToggleRequested event,
    Emitter<MyFollowingState> emit,
  ) async {
    try {
      await _followRepository.toggleFollow(event.pubkey);
    } catch (e) {
      Log.error(
        'Failed to toggle follow for user: $e',
        name: 'MyFollowingBloc',
        category: LogCategory.system,
      );
    }
  }
}
