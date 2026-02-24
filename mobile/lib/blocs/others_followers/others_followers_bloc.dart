// ABOUTME: BLoC for displaying another user's followers list
// ABOUTME: Fetches Kind 3 events that mention target user in 'p' tags

import 'dart:math';

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
    // Skip fetch if data is fresh and for the same target (unless force refresh)
    if (!event.forceRefresh &&
        state.status == OthersFollowersStatus.success &&
        state.targetPubkey == event.targetPubkey &&
        !state.isStale) {
      Log.debug(
        'Followers list is fresh (${state.lastFetchedAt}), skipping fetch',
        name: 'OthersFollowersBloc',
        category: LogCategory.system,
      );
      return;
    }

    emit(
      state.copyWith(
        status: OthersFollowersStatus.loading,
        targetPubkey: event.targetPubkey,
        followersPubkeys: [],
      ),
    );

    try {
      // Fetch the follower list and accurate count in parallel.
      // The list is limited by relay result caps, so the count
      // (from COUNT queries) is more accurate for display.
      final results = await Future.wait([
        _followRepository.getFollowers(event.targetPubkey),
        _followRepository.getFollowerCount(event.targetPubkey),
      ]);
      final followers = results[0] as List<String>;
      final countFromService = results[1] as int;
      final followerCount = max(followers.length, countFromService);

      emit(
        state.copyWith(
          status: OthersFollowersStatus.success,
          followersPubkeys: followers,
          followerCount: followerCount,
          lastFetchedAt: DateTime.now(),
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
          followerCount: state.followerCount + 1,
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
          followerCount: max(0, state.followerCount - 1),
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
