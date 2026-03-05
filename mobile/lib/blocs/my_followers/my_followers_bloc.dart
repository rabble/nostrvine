// ABOUTME: BLoC for displaying current user's followers list
// ABOUTME: Fetches Kind 3 events that mention current user in 'p' tags

import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/utils/unified_logger.dart';

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
    required ContentBlocklistService contentBlocklistService,
  }) : _followRepository = followRepository,
       _blocklistService = contentBlocklistService,
       super(const MyFollowersState()) {
    on<MyFollowersListLoadRequested>(_onLoadRequested);
    on<MyFollowersBlocklistChanged>(_onBlocklistChanged);
  }

  final FollowRepository _followRepository;
  final ContentBlocklistService _blocklistService;

  /// Raw unfiltered follower pubkeys for re-filtering on blocklist changes.
  List<String> _rawFollowersPubkeys = [];

  /// Filter pubkeys by removing blocked and follow-severed users.
  List<String> _filterPubkeys(List<String> pubkeys) => pubkeys
      .where(
        (pk) =>
            !_blocklistService.isBlocked(pk) &&
            !_blocklistService.isFollowSevered(pk),
      )
      .toList();

  /// Handle request to load current user's followers list
  Future<void> _onLoadRequested(
    MyFollowersListLoadRequested event,
    Emitter<MyFollowersState> emit,
  ) async {
    emit(
      state.copyWith(status: MyFollowersStatus.loading, followersPubkeys: []),
    );

    try {
      // Fetch the follower list and accurate count in parallel.
      // The list is limited by relay result caps, so the count
      // (from COUNT queries) is more accurate for display.
      final results = await Future.wait([
        _followRepository.getMyFollowers(),
        _followRepository.getMyFollowerCount(),
      ]);
      final followers = results[0] as List<String>;
      final countFromService = results[1] as int;
      final followerCount = max(followers.length, countFromService);

      _rawFollowersPubkeys = followers;
      final filtered = _filterPubkeys(followers);

      emit(
        state.copyWith(
          status: MyFollowersStatus.success,
          followersPubkeys: filtered,
          followerCount: followerCount,
        ),
      );
    } catch (e) {
      Log.error(
        'Failed to load followers list: $e',
        name: 'MyFollowersBloc',
        category: LogCategory.system,
      );
      emit(state.copyWith(status: MyFollowersStatus.failure));
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
