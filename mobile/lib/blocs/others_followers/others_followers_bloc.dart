// ABOUTME: BLoC for displaying another user's followers list
// ABOUTME: Fetches Kind 3 events that mention target user in 'p' tags

import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'others_followers_event.dart';
part 'others_followers_state.dart';

/// BLoC for displaying another user's followers list.
///
/// Fetches Kind 3 (contact list) events that mention the target user
/// in their 'p' tags - these are users who follow the target.
///
/// Filters out blocked users before emitting state.
class OthersFollowersBloc
    extends Bloc<OthersFollowersEvent, OthersFollowersState> {
  OthersFollowersBloc({
    required FollowRepository followRepository,
    required ContentBlocklistService contentBlocklistService,
    required String currentUserPubkey,
  }) : _followRepository = followRepository,
       _blocklistService = contentBlocklistService,
       _currentUserPubkey = currentUserPubkey,
       super(const OthersFollowersState()) {
    on<OthersFollowersListLoadRequested>(_onLoadRequested);
    on<OthersFollowersIncrementRequested>(_onIncrementRequested);
    on<OthersFollowersDecrementRequested>(_onDecrementRequested);
    on<OthersFollowersBlocklistChanged>(_onBlocklistChanged);
  }

  final FollowRepository _followRepository;
  final ContentBlocklistService _blocklistService;
  final String _currentUserPubkey;

  /// Raw unfiltered follower pubkeys for re-filtering on blocklist changes.
  List<String> _rawFollowersPubkeys = [];
  bool _isFollowingTarget = false;

  /// Filter pubkeys by removing blocked users.
  List<String> _filterPubkeys(List<String> pubkeys) => pubkeys
      .where(
        (pk) =>
            !_blocklistService.isBlocked(pk) &&
            !(_shouldHideCurrentUser() && pk == _currentUserPubkey),
      )
      .toList();

  bool _shouldHideCurrentUser() => !_isFollowingTarget;

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

      _isFollowingTarget = _followRepository.isFollowing(event.targetPubkey);
      _rawFollowersPubkeys = followers;
      final filtered = _filterPubkeys(followers);

      emit(
        state.copyWith(
          status: OthersFollowersStatus.success,
          followersPubkeys: filtered,
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
      state.copyWith(
        followersPubkeys: _filterPubkeys(_rawFollowersPubkeys),
      ),
    );
  }
}
