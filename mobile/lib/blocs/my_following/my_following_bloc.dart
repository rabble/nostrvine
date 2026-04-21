// ABOUTME: BLoC for managing current user's following list with reactive updates
// ABOUTME: Listens to FollowRepository stream for real-time following changes

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:content_blocklist_service/content_blocklist_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:unified_logger/unified_logger.dart';

part 'my_following_event.dart';
part 'my_following_state.dart';

/// BLoC for managing the current user's following list.
///
/// Uses [FollowRepository] for reactive updates via emit.forEach.
/// Initial state is set optimistically with cached repository data
/// to prevent UI flash.
///
/// Filters out blocked users before emitting state.
class MyFollowingBloc extends Bloc<MyFollowingEvent, MyFollowingState> {
  MyFollowingBloc({
    required FollowRepository followRepository,
    required ContentBlocklistService contentBlocklistService,
  }) : _followRepository = followRepository,
       _blocklistService = contentBlocklistService,
       super(
         MyFollowingState(
           status: MyFollowingStatus.success,
           followingPubkeys: followRepository.followingPubkeys
               .where(
                 (pk) => !contentBlocklistService.isBlocked(pk),
               )
               .toList(),
         ),
       ) {
    on<MyFollowingListLoadRequested>(_onLoadRequested);
    on<MyFollowingToggleRequested>(
      _onToggleRequested,
      transformer: droppable(),
    );
    on<MyFollowingBlocklistChanged>(_onBlocklistChanged);
  }

  final FollowRepository _followRepository;
  final ContentBlocklistService _blocklistService;

  /// Raw unfiltered following pubkeys for re-filtering on blocklist changes.
  List<String> _rawFollowingPubkeys = [];

  /// Filter pubkeys by removing blocked users.
  List<String> _filterPubkeys(List<String> pubkeys) =>
      pubkeys.where((pk) => !_blocklistService.isBlocked(pk)).toList();

  /// Listen to repository stream for reactive updates
  Future<void> _onLoadRequested(
    MyFollowingListLoadRequested event,
    Emitter<MyFollowingState> emit,
  ) async {
    try {
      await emit.forEach<List<String>>(
        _followRepository.followingStream,
        onData: (followingPubkeys) {
          _rawFollowingPubkeys = followingPubkeys;
          return state.copyWith(
            status: MyFollowingStatus.success,
            followingPubkeys: _filterPubkeys(followingPubkeys),
          );
        },
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
  ///
  /// Uses [droppable] transformer to prevent concurrent toggles from
  /// racing each other (e.g. rapid taps toggling follow/unfollow/follow).
  Future<void> _onToggleRequested(
    MyFollowingToggleRequested event,
    Emitter<MyFollowingState> emit,
  ) async {
    // Clear previous toggle error state before retrying.
    if (state.status == MyFollowingStatus.toggleFailure) {
      emit(state.copyWith(status: MyFollowingStatus.success));
    }

    try {
      await _followRepository.toggleFollow(event.pubkey);
    } catch (e) {
      Log.error(
        'Failed to toggle follow for user: $e',
        name: 'MyFollowingBloc',
        category: LogCategory.system,
      );
      emit(state.copyWith(status: MyFollowingStatus.toggleFailure));
    }
  }

  /// Re-filter following when blocklist changes.
  void _onBlocklistChanged(
    MyFollowingBlocklistChanged event,
    Emitter<MyFollowingState> emit,
  ) {
    if (state.status != MyFollowingStatus.success) return;

    emit(
      state.copyWith(
        followingPubkeys: _filterPubkeys(_rawFollowingPubkeys),
      ),
    );
  }
}
