// ABOUTME: BLoC for managing current user's following list with reactive updates
// ABOUTME: Delegates stale-while-revalidate to FollowRepository

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:unified_logger/unified_logger.dart';

part 'my_following_event.dart';
part 'my_following_state.dart';

/// BLoC for managing the current user's following list.
///
/// Uses [FollowRepository.watchMyFollowingCached] for stale-while-revalidate:
/// cached pubkeys are served immediately ([isRefreshing] = true) while the
/// live stream catches up.
///
/// Filters out blocked users before emitting state.
class MyFollowingBloc extends Bloc<MyFollowingEvent, MyFollowingState> {
  MyFollowingBloc({
    required FollowRepository followRepository,
    required ContentBlocklistRepository contentBlocklistRepository,
  }) : _followRepository = followRepository,
       _blocklistRepository = contentBlocklistRepository,
       super(const MyFollowingState()) {
    on<MyFollowingListLoadRequested>(_onLoadRequested);
    on<MyFollowingToggleRequested>(
      _onToggleRequested,
      transformer: droppable(),
    );
    on<MyFollowingBlocklistChanged>(_onBlocklistChanged);
  }

  final FollowRepository _followRepository;
  final ContentBlocklistRepository _blocklistRepository;

  /// Filter pubkeys by removing blocked users.
  List<String> _filterPubkeys(List<String> pubkeys) =>
      pubkeys.where((pk) => !_blocklistRepository.isBlocked(pk)).toList();

  /// Listen to repository's cached stream for stale-while-revalidate.
  Future<void> _onLoadRequested(
    MyFollowingListLoadRequested event,
    Emitter<MyFollowingState> emit,
  ) async {
    try {
      await emit.forEach<CacheResult<FollowingSnapshot>>(
        _followRepository.watchMyFollowingCached(),
        onData: (result) {
          return state.copyWith(
            status: MyFollowingStatus.success,
            rawFollowingPubkeys: result.data.pubkeys,
            followingPubkeys: _filterPubkeys(result.data.pubkeys),
            isRefreshing: result.isStale,
          );
        },
        onError: (error, stackTrace) {
          Log.error(
            'Error in following stream: $error',
            name: 'MyFollowingBloc',
            category: LogCategory.system,
          );
          addError(error, stackTrace);
          return state.copyWith(
            status: MyFollowingStatus.failure,
            isRefreshing: false,
          );
        },
      );
    } catch (e, stackTrace) {
      Log.error(
        'Failed to listen to following stream: $e',
        name: 'MyFollowingBloc',
        category: LogCategory.system,
      );
      addError(e, stackTrace);
      emit(
        state.copyWith(status: MyFollowingStatus.failure, isRefreshing: false),
      );
    }
  }

  /// Handle follow toggle request.
  ///
  /// Delegates to repository which handles the toggle logic internally,
  /// then re-dispatches [MyFollowingListLoadRequested] so the cache layer
  /// and UI re-observe the new follow set. The previous implementation
  /// relied on a [BehaviorSubject] replay flowing through
  /// `CacheSync.watchStream`, which mis-tagged stale in-memory snapshots
  /// as live; [FollowRepository.watchMyFollowingCached] is now one-shot,
  /// so explicit re-load here owns the post-toggle refresh.
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
      add(const MyFollowingListLoadRequested());
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
        followingPubkeys: _filterPubkeys(state.rawFollowingPubkeys),
      ),
    );
  }
}
