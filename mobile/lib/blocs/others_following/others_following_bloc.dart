// ABOUTME: BLoC for displaying another user's following list (read-only)
// ABOUTME: Delegates stale-while-revalidate to FollowRepository

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:unified_logger/unified_logger.dart';

part 'others_following_event.dart';
part 'others_following_state.dart';

/// BLoC for displaying another user's following list.
///
/// Delegates fetching to [FollowRepository.watchOthersFollowingCached] which
/// uses stale-while-revalidate: cached pubkeys are served immediately
/// ([isRefreshing] = true) while a fresh fetch runs.
///
/// Filters out blocked users and hides the current user from the target's
/// following list when the current user has blocked the target.
class OthersFollowingBloc
    extends Bloc<OthersFollowingEvent, OthersFollowingState> {
  OthersFollowingBloc({
    required FollowRepository followRepository,
    required ContentBlocklistRepository contentBlocklistRepository,
    this.currentUserPubkey,
  }) : _followRepository = followRepository,
       _blocklistRepository = contentBlocklistRepository,
       super(const OthersFollowingState()) {
    on<OthersFollowingListLoadRequested>(
      _onLoadRequested,
      transformer: restartable(),
    );
    on<OthersFollowingBlocklistChanged>(_onBlocklistChanged);
  }

  final FollowRepository _followRepository;
  final ContentBlocklistRepository _blocklistRepository;

  /// The current user's pubkey, used to hide ourselves from the target's
  /// following list when we have blocked the target.
  final String? currentUserPubkey;

  /// Filter pubkeys by removing blocked users and hiding current user
  /// from the target's following list when we've blocked the target.
  List<String> _filterPubkeys(List<String> pubkeys) {
    final targetPubkey = state.targetPubkey;
    final hideCurrentUser =
        targetPubkey != null &&
        (_blocklistRepository.isBlocked(targetPubkey) ||
            _blocklistRepository.isFollowSevered(targetPubkey));

    return pubkeys
        .where(
          (pk) =>
              !_blocklistRepository.isBlocked(pk) &&
              !(hideCurrentUser && pk == currentUserPubkey),
        )
        .toList();
  }

  /// Handle request to load another user's following list.
  ///
  /// Delegates to [FollowRepository.watchOthersFollowingCached] for
  /// stale-while-revalidate: cached pubkeys are served immediately
  /// ([isRefreshing] = true) while the live fetch runs.
  Future<void> _onLoadRequested(
    OthersFollowingListLoadRequested event,
    Emitter<OthersFollowingState> emit,
  ) async {
    if (state.status != OthersFollowingStatus.success ||
        state.targetPubkey != event.targetPubkey) {
      emit(
        state.copyWith(
          targetPubkey: event.targetPubkey,
          followingPubkeys: state.targetPubkey == event.targetPubkey
              ? state.followingPubkeys
              : const [],
        ),
      );
    }

    try {
      await emit.forEach<CacheResult<FollowingSnapshot>>(
        _followRepository.watchOthersFollowingCached(
          event.targetPubkey,
          forceRefresh: event.forceRefresh,
        ),
        onData: (result) {
          return state.copyWith(
            status: OthersFollowingStatus.success,
            rawFollowingPubkeys: result.data.pubkeys,
            followingPubkeys: _filterPubkeys(result.data.pubkeys),
            isRefreshing: result.isStale,
          );
        },
        onError: (error, stackTrace) {
          Log.error(
            'Failed to load following list for ${event.targetPubkey}: $error',
            name: 'OthersFollowingBloc',
            category: LogCategory.system,
          );
          addError(error, stackTrace);
          if (state.status == OthersFollowingStatus.success) {
            return state.copyWith(isRefreshing: false);
          }
          return state.copyWith(
            status: OthersFollowingStatus.failure,
            isRefreshing: false,
          );
        },
      );
    } catch (e, stackTrace) {
      Log.error(
        'Unexpected error loading following list for ${event.targetPubkey}: $e',
        name: 'OthersFollowingBloc',
        category: LogCategory.system,
      );
      addError(e, stackTrace);
      if (state.status == OthersFollowingStatus.success) {
        emit(state.copyWith(isRefreshing: false));
        return;
      }
      emit(
        state.copyWith(
          status: OthersFollowingStatus.failure,
          isRefreshing: false,
        ),
      );
    }
  }

  /// Re-filter following when blocklist changes.
  void _onBlocklistChanged(
    OthersFollowingBlocklistChanged event,
    Emitter<OthersFollowingState> emit,
  ) {
    if (state.status != OthersFollowingStatus.success) return;

    emit(
      state.copyWith(
        followingPubkeys: _filterPubkeys(state.rawFollowingPubkeys),
      ),
    );
  }
}
