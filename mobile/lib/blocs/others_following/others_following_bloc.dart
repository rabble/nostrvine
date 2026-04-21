// ABOUTME: BLoC for displaying another user's following list (read-only)
// ABOUTME: Fetches Kind 3 contact list from Nostr relays for the target user
// TODO(Oscar): Move Nostr query logic to repository - https://github.com/divinevideo/divine-mobile/issues/571

import 'package:content_blocklist_service/content_blocklist_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:unified_logger/unified_logger.dart';

part 'others_following_event.dart';
part 'others_following_state.dart';

/// BLoC for displaying another user's following list.
///
/// Fetches Kind 3 (contact list) events from Nostr relays for the target user.
/// This is a read-only view - no follow/unfollow operations.
///
/// Filters out blocked users and hides the current user from the target's
/// following list when the current user has blocked the target.
class OthersFollowingBloc
    extends Bloc<OthersFollowingEvent, OthersFollowingState> {
  OthersFollowingBloc({
    required NostrClient nostrClient,
    required ContentBlocklistService contentBlocklistService,
    this.currentUserPubkey,
  }) : _nostrClient = nostrClient,
       _blocklistService = contentBlocklistService,
       super(const OthersFollowingState()) {
    on<OthersFollowingListLoadRequested>(_onLoadRequested);
    on<OthersFollowingBlocklistChanged>(_onBlocklistChanged);
  }

  final NostrClient _nostrClient;
  final ContentBlocklistService _blocklistService;

  /// The current user's pubkey, used to hide ourselves from the target's
  /// following list when we have blocked the target.
  final String? currentUserPubkey;

  /// Raw unfiltered following pubkeys for re-filtering on blocklist changes.
  List<String> _rawFollowingPubkeys = [];

  /// Filter pubkeys by removing blocked users and hiding current user
  /// from the target's following list when we've blocked the target.
  List<String> _filterPubkeys(List<String> pubkeys) {
    final targetPubkey = state.targetPubkey;
    final hideCurrentUser =
        targetPubkey != null &&
        (_blocklistService.isBlocked(targetPubkey) ||
            _blocklistService.isFollowSevered(targetPubkey));

    return pubkeys
        .where(
          (pk) =>
              !_blocklistService.isBlocked(pk) &&
              !(hideCurrentUser && pk == currentUserPubkey),
        )
        .toList();
  }

  /// Handle request to load another user's following list
  Future<void> _onLoadRequested(
    OthersFollowingListLoadRequested event,
    Emitter<OthersFollowingState> emit,
  ) async {
    emit(
      state.copyWith(
        status: OthersFollowingStatus.loading,
        targetPubkey: event.targetPubkey,
        followingPubkeys: state.targetPubkey == event.targetPubkey
            ? state.followingPubkeys
            : const [],
      ),
    );

    try {
      final following = await _fetchFollowingFromNostr(event.targetPubkey);
      _rawFollowingPubkeys = following;
      final filtered = _filterPubkeys(following);

      emit(
        state.copyWith(
          status: OthersFollowingStatus.success,
          followingPubkeys: filtered,
        ),
      );
    } catch (e) {
      Log.error(
        'Failed to load following list for ${event.targetPubkey}: $e',
        name: 'OthersFollowingBloc',
        category: LogCategory.system,
      );
      emit(state.copyWith(status: OthersFollowingStatus.failure));
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
        followingPubkeys: _filterPubkeys(_rawFollowingPubkeys),
      ),
    );
  }

  /// Fetch following list from Nostr relays
  Future<List<String>> _fetchFollowingFromNostr(String targetPubkey) async {
    final events = await _nostrClient.queryEvents([
      Filter(
        authors: [targetPubkey],
        kinds: const [3], // Contact lists
        limit: 1, // Get most recent only
      ),
    ]);

    final following = <String>[];
    if (events.isNotEmpty) {
      final event = events.first;
      for (final tag in event.tags) {
        if (tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) {
          final followedPubkey = tag[1];
          if (!following.contains(followedPubkey)) {
            following.add(followedPubkey);
          }
        }
      }
    }

    return following;
  }
}
