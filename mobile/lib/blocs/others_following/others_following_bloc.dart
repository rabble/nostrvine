// ABOUTME: BLoC for displaying another user's following list (read-only)
// ABOUTME: Fetches Kind 3 contact list from Nostr relays for the target user
// TODO(Oscar): Move Nostr query logic to repository - https://github.com/divinevideo/divine-mobile/issues/571

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'others_following_event.dart';
part 'others_following_state.dart';

/// BLoC for displaying another user's following list.
///
/// Fetches Kind 3 (contact list) events from Nostr relays for the target user.
/// This is a read-only view - no follow/unfollow operations.
class OthersFollowingBloc
    extends Bloc<OthersFollowingEvent, OthersFollowingState> {
  OthersFollowingBloc({required NostrClient nostrClient})
    : _nostrClient = nostrClient,
      super(const OthersFollowingState()) {
    on<OthersFollowingListLoadRequested>(_onLoadRequested);
  }

  final NostrClient _nostrClient;

  /// Handle request to load another user's following list
  Future<void> _onLoadRequested(
    OthersFollowingListLoadRequested event,
    Emitter<OthersFollowingState> emit,
  ) async {
    emit(
      state.copyWith(
        status: OthersFollowingStatus.loading,
        targetPubkey: event.targetPubkey,
        followingPubkeys: [],
      ),
    );

    try {
      final following = await _fetchFollowingFromNostr(event.targetPubkey);
      emit(
        state.copyWith(
          status: OthersFollowingStatus.success,
          followingPubkeys: following,
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
