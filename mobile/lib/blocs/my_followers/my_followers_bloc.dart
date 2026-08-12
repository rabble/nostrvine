// ABOUTME: BLoC for displaying current user's followers list
// ABOUTME: Fetches Kind 3 events that mention current user in 'p' tags

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:openvine/blocs/followers/follower_visibility.dart';
import 'package:unified_logger/unified_logger.dart';

part 'my_followers_event.dart';
part 'my_followers_state.dart';

/// BLoC for displaying the current user's followers list.
///
/// Fetches Kind 3 (contact list) events that mention the current user
/// in their 'p' tags - these are users who follow the current user.
///
/// Filters out blocked and follow-severed users before emitting state.
/// Uses [FollowRepository.watchMyFollowersCached] for stale-while-revalidate:
/// cached pubkeys are served immediately while fresh data loads from relays.
class MyFollowersBloc extends Bloc<MyFollowersEvent, MyFollowersState> {
  MyFollowersBloc({
    required FollowRepository followRepository,
    required ContentBlocklistRepository contentBlocklistRepository,
  }) : _followRepository = followRepository,
       _blocklistRepository = contentBlocklistRepository,
       super(const MyFollowersState()) {
    on<MyFollowersListLoadRequested>(_onLoadRequested);
    on<MyFollowersBlocklistChanged>(_onBlocklistChanged);
    on<MyFollowersSortOrderChanged>(_onSortOrderChanged);
  }

  final FollowRepository _followRepository;
  final ContentBlocklistRepository _blocklistRepository;

  /// The rows to show: [rawPubkeys] arranged for [sortOrder], then filtered.
  ///
  /// Ordering runs first because filtering preserves relative order, so the
  /// blocklist can never disturb the sort.
  List<String> _visiblePubkeys({
    required List<String> rawPubkeys,
    required int datedCount,
    required FollowSortOrder sortOrder,
  }) => filterMyFollowerPubkeys(
    pubkeys: sortOrder.fromNewestFirst(
      rawPubkeys,
      datedCount: datedCount,
    ),
    blocklistRepository: _blocklistRepository,
  );

  /// Handle request to load current user's followers list.
  ///
  /// Delegates to [FollowRepository.watchMyFollowersCached] for
  /// stale-while-revalidate: cached data is emitted first (if present and
  /// not expired), then the relay stream updates the list and refreshes the
  /// cache.
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
      await emit.forEach<CacheResult<FollowersSnapshot>>(
        _followRepository.watchMyFollowersCached(),
        onData: (result) {
          final visiblePubkeys = _visiblePubkeys(
            rawPubkeys: result.data.pubkeys,
            datedCount: result.data.datedCount,
            sortOrder: state.sortOrder,
          );
          return state.copyWith(
            status: MyFollowersStatus.success,
            rawFollowersPubkeys: result.data.pubkeys,
            rawDatedCount: result.data.datedCount,
            followersPubkeys: visiblePubkeys,
            authoritativeFollowerCount: result.data.count,
            isRefreshing: result.isStale,
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
    final visiblePubkeys = _visiblePubkeys(
      rawPubkeys: state.rawFollowersPubkeys,
      datedCount: state.rawDatedCount,
      sortOrder: state.sortOrder,
    );
    // followerCount derives from the unchanged authoritative count, so
    // re-filtering alone updates it.
    emit(
      state.copyWith(
        followersPubkeys: visiblePubkeys,
      ),
    );
  }

  /// Re-order the loaded followers without refetching them.
  void _onSortOrderChanged(
    MyFollowersSortOrderChanged event,
    Emitter<MyFollowersState> emit,
  ) {
    if (event.sortOrder == state.sortOrder) return;

    final visiblePubkeys = _visiblePubkeys(
      rawPubkeys: state.rawFollowersPubkeys,
      datedCount: state.rawDatedCount,
      sortOrder: event.sortOrder,
    );

    // The sort is remembered even before the first load resolves, so the
    // pending list arrives in the order the user already asked for.
    emit(
      state.copyWith(
        sortOrder: event.sortOrder,
        followersPubkeys: visiblePubkeys,
      ),
    );
  }
}
