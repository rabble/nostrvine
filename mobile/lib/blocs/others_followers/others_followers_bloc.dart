// ABOUTME: BLoC for displaying another user's followers list
// ABOUTME: Fetches Kind 3 events that mention target user in 'p' tags

import 'dart:math';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:unified_logger/unified_logger.dart';

part 'others_followers_event.dart';
part 'others_followers_state.dart';

/// BLoC for displaying another user's followers list.
///
/// Fetches Kind 3 (contact list) events that mention the target user
/// in their 'p' tags - these are users who follow the target.
///
/// Filters out blocked users before emitting state.
/// Uses [FollowRepository.watchOthersFollowersCached] for
/// stale-while-revalidate: cached pubkeys are served immediately while fresh
/// data loads from relays.
class OthersFollowersBloc
    extends Bloc<OthersFollowersEvent, OthersFollowersState> {
  OthersFollowersBloc({
    required FollowRepository followRepository,
    required ContentBlocklistRepository contentBlocklistRepository,
    required String currentUserPubkey,
  }) : _followRepository = followRepository,
       _blocklistRepository = contentBlocklistRepository,
       _currentUserPubkey = currentUserPubkey,
       super(const OthersFollowersState()) {
    on<OthersFollowersListLoadRequested>(
      _onLoadRequested,
      transformer: restartable(),
    );
    on<OthersFollowersIncrementRequested>(_onIncrementRequested);
    on<OthersFollowersDecrementRequested>(_onDecrementRequested);
    on<OthersFollowersBlocklistChanged>(_onBlocklistChanged);
  }

  final FollowRepository _followRepository;
  final ContentBlocklistRepository _blocklistRepository;
  final String _currentUserPubkey;

  /// Raw unfiltered follower pubkeys for re-filtering on blocklist changes.
  List<String> _rawFollowersPubkeys = [];
  bool _isFollowingTarget = false;

  /// Filter pubkeys by removing blocked users.
  List<String> _filterPubkeys(List<String> pubkeys) => pubkeys
      .where(
        (pk) =>
            !_blocklistRepository.isBlocked(pk) &&
            !(_shouldHideCurrentUser() && pk == _currentUserPubkey),
      )
      .toList();

  bool _shouldHideCurrentUser() => !_isFollowingTarget;

  /// Handle request to load another user's followers list.
  ///
  /// Delegates to [FollowRepository.watchOthersFollowersCached] for
  /// stale-while-revalidate: cached pubkeys are served immediately
  /// ([isRefreshing] = true) while the live fetch runs.
  Future<void> _onLoadRequested(
    OthersFollowersListLoadRequested event,
    Emitter<OthersFollowersState> emit,
  ) async {
    if (state.status != .success || state.targetPubkey != event.targetPubkey) {
      emit(
        state.copyWith(
          status: .loading,
          targetPubkey: event.targetPubkey,
          followersPubkeys: state.targetPubkey == event.targetPubkey
              ? state.followersPubkeys
              : const [],
          followerCount: state.targetPubkey == event.targetPubkey
              ? state.followerCount
              : 0,
        ),
      );
    }

    try {
      await emit.forEach<CacheResult<FollowersSnapshot>>(
        _followRepository.watchOthersFollowersCached(
          event.targetPubkey,
          forceRefresh: event.forceRefresh,
        ),
        onData: (result) {
          _isFollowingTarget = _followRepository.isFollowing(
            event.targetPubkey,
          );
          _rawFollowersPubkeys = result.data.pubkeys;
          return state.copyWith(
            status: .success,
            targetPubkey: event.targetPubkey,
            followersPubkeys: _filterPubkeys(result.data.pubkeys),
            followerCount: max(result.data.pubkeys.length, result.data.count),
            isRefreshing: result.isStale,
          );
        },
        onError: (error, stackTrace) {
          Log.error(
            'Failed to load followers list for ${event.targetPubkey}: $error',
            name: 'OthersFollowersBloc',
            category: LogCategory.system,
          );
          addError(error, stackTrace);
          return state.copyWith(
            status: .failure,
            isRefreshing: false,
          );
        },
      );
    } catch (e, stackTrace) {
      Log.error(
        'Unexpected error loading followers list for ${event.targetPubkey}: $e',
        name: 'OthersFollowersBloc',
        category: LogCategory.system,
      );
      addError(e, stackTrace);
      if (state.status != OthersFollowersStatus.success) {
        emit(
          state.copyWith(
            status: .failure,
            isRefreshing: false,
          ),
        );
      }
    }
  }

  /// Optimistically add a follower to the list
  void _onIncrementRequested(
    OthersFollowersIncrementRequested event,
    Emitter<OthersFollowersState> emit,
  ) {
    if (_rawFollowersPubkeys.isEmpty && state.followersPubkeys.isNotEmpty) {
      _rawFollowersPubkeys = [...state.followersPubkeys];
    }

    // Only increment if not already in the list
    if (!_rawFollowersPubkeys.contains(event.followerPubkey)) {
      _rawFollowersPubkeys = [..._rawFollowersPubkeys, event.followerPubkey];
      emit(
        state.copyWith(
          followersPubkeys: _filterPubkeys(_rawFollowersPubkeys),
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
    if (_rawFollowersPubkeys.isEmpty && state.followersPubkeys.isNotEmpty) {
      _rawFollowersPubkeys = [...state.followersPubkeys];
    }

    // Only decrement if in the list
    if (_rawFollowersPubkeys.contains(event.followerPubkey)) {
      _rawFollowersPubkeys = _rawFollowersPubkeys
          .where((pubkey) => pubkey != event.followerPubkey)
          .toList();
      emit(
        state.copyWith(
          followersPubkeys: _filterPubkeys(_rawFollowersPubkeys),
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

  /// Re-filter followers when blocklist changes.
  void _onBlocklistChanged(
    OthersFollowersBlocklistChanged event,
    Emitter<OthersFollowersState> emit,
  ) {
    if (state.status != OthersFollowersStatus.success) return;

    emit(
      state.copyWith(followersPubkeys: _filterPubkeys(_rawFollowersPubkeys)),
    );
  }
}
