// ABOUTME: BLoC for managing current user's following list with reactive updates
// ABOUTME: Combines CacheSync bootstrap with live FollowRepository reactivity

import 'dart:async';

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
       super(
         MyFollowingState(
           status: followRepository.followingPubkeys.isEmpty
               ? MyFollowingStatus.initial
               : MyFollowingStatus.success,
           rawFollowingPubkeys: followRepository.followingPubkeys,
           followingPubkeys: followRepository.followingPubkeys
               .where((pk) => !contentBlocklistRepository.isBlocked(pk))
               .toList(),
         ),
       ) {
    on<MyFollowingListLoadRequested>(
      _onLoadRequested,
      transformer: restartable(),
    );
    on<MyFollowingToggleRequested>(
      _onToggleRequested,
      transformer: droppable(),
    );
    on<MyFollowingBlocklistChanged>(_onBlocklistChanged);
    on<_MyFollowingRepositoryUpdated>(_onRepositoryUpdated);
  }

  final FollowRepository _followRepository;
  final ContentBlocklistRepository _blocklistRepository;
  StreamSubscription<List<String>>? _followingSubscription;

  /// Filter pubkeys by removing blocked users.
  List<String> _filterPubkeys(List<String> pubkeys) =>
      pubkeys.where((pk) => !_blocklistRepository.isBlocked(pk)).toList();

  /// Listen to repository's cached stream for stale-while-revalidate.
  Future<void> _onLoadRequested(
    MyFollowingListLoadRequested event,
    Emitter<MyFollowingState> emit,
  ) async {
    _ensureFollowingSubscription();
    try {
      await emit.forEach<CacheResult<FollowingSnapshot>>(
        _followRepository.watchMyFollowingCached(),
        onData: (result) {
          // Once the user has toggled locally, the repository's in-memory list
          // is the authority. The mount-time load can still be in flight when
          // the user taps Follow; its revalidation read resolves with the
          // relay-lagged pre-toggle snapshot and would otherwise revert the
          // button (#5144). Defer to the repository instead of the stale
          // emission; let the emission only drive the refreshing indicator.
          final pubkeys = state.hasLocalFollowEdit
              ? _followRepository.followingPubkeys
              : result.data.pubkeys;
          return state.copyWith(
            status: MyFollowingStatus.success,
            rawFollowingPubkeys: pubkeys,
            followingPubkeys: _filterPubkeys(pubkeys),
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
          if (_hasVisibleData) {
            return state.copyWith(isRefreshing: false);
          }
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
      if (_hasVisibleData) {
        emit(state.copyWith(isRefreshing: false));
        return;
      }
      emit(
        state.copyWith(status: MyFollowingStatus.failure, isRefreshing: false),
      );
    }
  }

  /// Handle follow toggle request.
  ///
  /// Delegates to the repository, which updates the in-memory follow set and
  /// emits on [FollowRepository.followingStream]. That stream drives
  /// [_onRepositoryUpdated] — the single source of post-toggle reactivity — so
  /// the button reflects the new state immediately and optimistically.
  ///
  /// We deliberately do NOT re-dispatch [MyFollowingListLoadRequested] here.
  /// That re-load re-read [FollowRepository.watchMyFollowingCached], whose
  /// stale-while-revalidate cache served a pre-toggle disk snapshot first and
  /// reverted the button (#5144). The repository invalidates that cache on
  /// mutation, so the next load (on the next mount) is fresh.
  ///
  /// On success we set [MyFollowingState.hasLocalFollowEdit] so that an
  /// already-in-flight mount-time load (its revalidation read can still
  /// resolve with the relay-lagged pre-toggle list) defers to the repository
  /// instead of reverting the button — see [_onLoadRequested].
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
      if (!state.hasLocalFollowEdit) {
        emit(state.copyWith(hasLocalFollowEdit: true));
      }
    } catch (e) {
      Log.error(
        'Failed to toggle follow for user: $e',
        name: 'MyFollowingBloc',
        category: LogCategory.system,
      );
      emit(state.copyWith(status: MyFollowingStatus.toggleFailure));
    }
  }

  void _onRepositoryUpdated(
    _MyFollowingRepositoryUpdated event,
    Emitter<MyFollowingState> emit,
  ) {
    if (state.status == MyFollowingStatus.initial && event.pubkeys.isEmpty) {
      return;
    }
    if (_samePubkeys(state.rawFollowingPubkeys, event.pubkeys) &&
        state.status == MyFollowingStatus.success &&
        !state.isRefreshing) {
      return;
    }

    emit(
      state.copyWith(
        status: MyFollowingStatus.success,
        rawFollowingPubkeys: event.pubkeys,
        followingPubkeys: _filterPubkeys(event.pubkeys),
        isRefreshing: false,
      ),
    );
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

  bool get _hasVisibleData =>
      state.status == MyFollowingStatus.toggleFailure ||
      state.isRefreshing ||
      state.rawFollowingPubkeys.isNotEmpty;

  void _ensureFollowingSubscription() {
    _followingSubscription ??= _followRepository.followingStream.listen(
      (pubkeys) => add(_MyFollowingRepositoryUpdated(pubkeys)),
    );
  }

  bool _samePubkeys(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Future<void> close() async {
    await _followingSubscription?.cancel();
    return super.close();
  }
}
