// ABOUTME: BLoC for displaying current user's followers list
// ABOUTME: Fetches Kind 3 events that mention current user in 'p' tags

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:unified_logger/unified_logger.dart';

part 'my_followers_event.dart';
part 'my_followers_state.dart';

/// BLoC for displaying the current user's followers list.
///
/// Fetches Kind 3 (contact list) events that mention the current user
/// in their 'p' tags - these are users who follow the current user.
///
/// Filters out blocked and follow-severed users before emitting state.
class MyFollowersBloc extends Bloc<MyFollowersEvent, MyFollowersState> {
  MyFollowersBloc({
    required FollowRepository followRepository,
    required ContentBlocklistRepository contentBlocklistRepository,
  }) : _followRepository = followRepository,
       _blocklistRepository = contentBlocklistRepository,
       super(const MyFollowersState()) {
    on<MyFollowersListLoadRequested>(_onLoadRequested);
    on<MyFollowersBlocklistChanged>(_onBlocklistChanged);
  }

  final FollowRepository _followRepository;
  final ContentBlocklistRepository _blocklistRepository;

  /// Raw unfiltered follower pubkeys for re-filtering on blocklist changes.
  List<String> _rawFollowersPubkeys = [];

  /// Filter pubkeys by removing blocked and follow-severed users.
  List<String> _filterPubkeys(List<String> pubkeys) => pubkeys
      .where(
        (pk) =>
            !_blocklistRepository.isBlocked(pk) &&
            !_blocklistRepository.isFollowSevered(pk),
      )
      .toList();

  /// Handle request to load current user's followers list.
  ///
  /// Listens to [FollowRepository.watchMyFollowers] which progressively
  /// yields cached data (instant) then fresh data from relays.
  Future<void> _onLoadRequested(
    MyFollowersListLoadRequested event,
    Emitter<MyFollowersState> emit,
  ) async {
    if (state.status != MyFollowersStatus.success) {
      emit(
        state.copyWith(status: MyFollowersStatus.loading, followersPubkeys: []),
      );
    }

    try {
      await emit.forEach<({List<String> pubkeys, int count})>(
        _followRepository.watchMyFollowers(),
        onData: (result) {
          _rawFollowersPubkeys = result.pubkeys;
          return state.copyWith(
            status: MyFollowersStatus.success,
            followersPubkeys: _filterPubkeys(result.pubkeys),
            followerCount: result.count,
          );
        },
      );
    } catch (e) {
      Log.error(
        'Failed to load followers list: $e',
        name: 'MyFollowersBloc',
        category: LogCategory.system,
      );
      if (state.status != MyFollowersStatus.success) {
        emit(state.copyWith(status: MyFollowersStatus.failure));
      }
    }
  }

  /// Re-filter followers when blocklist changes.
  void _onBlocklistChanged(
    MyFollowersBlocklistChanged event,
    Emitter<MyFollowersState> emit,
  ) {
    if (state.status != MyFollowersStatus.success) return;

    emit(
      state.copyWith(followersPubkeys: _filterPubkeys(_rawFollowersPubkeys)),
    );
  }
}
