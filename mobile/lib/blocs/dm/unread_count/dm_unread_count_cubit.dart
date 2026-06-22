// ABOUTME: Cubit that exposes the unread "Messages" conversation count.
// ABOUTME: Mirrors the Messages list composition (accepted union followed,
// ABOUTME: blocklist-filtered) so the badge matches the visible unread dots.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:rxdart/rxdart.dart';

/// Cubit that tracks the number of unread DM conversations shown in the
/// Messages tab.
///
/// The badge must equal the unread conversations the Messages list actually
/// renders. That list is **follow-aware**: it shows accepted conversations
/// (the user has replied) PLUS 1:1 conversations from followed peers the user
/// has not replied to yet, and it hides blocklisted peers. Counting only
/// `currentUserHasSent == true` (the previous behaviour) undercounted unread
/// chats from followed-but-unreplied peers. See #4976.
///
/// Parity with the list is structural: this reuses the same static
/// [DmRepository.classifyPotentialRequests] / [DmRepository.mergeAndSort]
/// helpers and [ContentBlocklistRepository.filterBlockedConversations] that
/// [ConversationListBloc] uses, so the count cannot drift from the list. It
/// intentionally does NOT replicate two list-only concerns:
///
/// * **Pagination** — the list renders one page; the badge counts the full
///   accepted set (unpaginated) so it reflects total unread, not the page.
/// * **Recovery hold-back (#5304)** — that only delays the *requests* bucket,
///   which never feeds this count.
///
/// Used by the bottom-nav badge and the inbox segmented toggle.
class DmUnreadCountCubit extends Cubit<int> {
  DmUnreadCountCubit({
    required DmRepository dmRepository,
    required FollowRepository followRepository,
    ContentBlocklistRepository? contentBlocklistRepository,
  }) : _dmRepository = dmRepository,
       _followRepository = followRepository,
       _blocklistRepository = contentBlocklistRepository,
       super(0) {
    // Recompute the count whenever the accepted conversations, the potential
    // requests, the following list, or the blocklist change. The blocklist tick
    // value is unused — `filterBlockedConversations` reads live block state; the
    // tick only forces a re-filter on block/unblock/mute. Drift / stream IO
    // errors are expected and NOT Reportable per .claude/rules/error_handling.md;
    // the `addError` tear-off keeps them in the unified log.
    final blocklistTicks = _blocklistRepository == null
        ? Stream<Object?>.value(null)
        : _blocklistRepository.stateStream
              .map<Object?>((_) => null)
              .startWith(null);

    _subscription =
        Rx.combineLatest4<
              List<DmConversation>,
              List<DmConversation>,
              List<String>,
              Object?,
              int
            >(
              _dmRepository.watchAcceptedConversations(),
              _dmRepository.watchPotentialRequests(),
              _followRepository.followingStream.startWith(const <String>[]),
              blocklistTicks,
              (accepted, potentialRequests, _, _) => _countUnread(
                accepted: accepted,
                potentialRequests: potentialRequests,
              ),
            )
            .listen(emit, onError: addError);
  }

  final DmRepository _dmRepository;
  final FollowRepository _followRepository;
  final ContentBlocklistRepository? _blocklistRepository;
  StreamSubscription<int>? _subscription;

  /// Composes the visible Messages list (accepted ∪ followed-but-unreplied,
  /// blocklist-filtered) and counts the unread ones — the same set the inbox
  /// renders an unread dot for.
  int _countUnread({
    required List<DmConversation> accepted,
    required List<DmConversation> potentialRequests,
  }) {
    final userPubkey = _dmRepository.userPubkey;
    final split = DmRepository.classifyPotentialRequests(
      potentialRequests,
      userPubkey: userPubkey,
      isFollowing: _followRepository.isFollowing,
    );
    final inbox = DmRepository.mergeAndSort(accepted, split.followed);
    final visible =
        _blocklistRepository?.filterBlockedConversations(
          inbox,
          userPubkey: userPubkey,
        ) ??
        inbox;
    return visible.where((c) => !c.isRead).length;
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
