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
/// The app-shell provides this cubit once via `ref.read`, but
/// `dmRepositoryProvider` / `followRepositoryProvider` /
/// `contentBlocklistRepositoryProvider` all `ref.watch(nostrServiceProvider)`
/// and so rebuild into fresh instances when Nostr/auth becomes ready or the
/// account switches. A cubit that captured the pre-auth instances would keep
/// counting against an empty `userPubkey` and a stale stream — diverging from
/// the inbox list, which is built later from the live repositories. Call
/// [setRepositories] whenever any of the three provider identities changes so
/// only this cubit's subscription is swapped (no MaterialApp/AppShell
/// remount). Mirrors [NotificationBadgeCubit.setRepository].
///
/// Used by the bottom-nav badge and the inbox segmented toggle.
class DmUnreadCountCubit extends Cubit<int> {
  DmUnreadCountCubit({
    required DmRepository dmRepository,
    required FollowRepository followRepository,
    ContentBlocklistRepository? contentBlocklistRepository,
  }) : super(0) {
    setRepositories(
      dmRepository: dmRepository,
      followRepository: followRepository,
      contentBlocklistRepository: contentBlocklistRepository,
    );
  }

  DmRepository? _dmRepository;
  FollowRepository? _followRepository;
  ContentBlocklistRepository? _blocklistRepository;
  StreamSubscription<int>? _subscription;
  int _subscriptionGeneration = 0;

  /// Re-point the count at fresh repository instances and re-subscribe.
  ///
  /// No-op when all three identities are unchanged, so redundant
  /// provider-listener fires are cheap. The generation guard discards any
  /// late emission from the cancelled subscription so a swap can never
  /// regress the badge to a stale count.
  void setRepositories({
    required DmRepository dmRepository,
    required FollowRepository followRepository,
    ContentBlocklistRepository? contentBlocklistRepository,
  }) {
    if (identical(_dmRepository, dmRepository) &&
        identical(_followRepository, followRepository) &&
        identical(_blocklistRepository, contentBlocklistRepository)) {
      return;
    }

    _dmRepository = dmRepository;
    _followRepository = followRepository;
    _blocklistRepository = contentBlocklistRepository;

    final generation = ++_subscriptionGeneration;
    final oldSubscription = _subscription;
    _subscription = null;
    if (oldSubscription != null) {
      unawaited(oldSubscription.cancel());
    }

    // Recompute whenever the accepted conversations, the potential requests,
    // the following list, or the blocklist change. The blocklist tick value is
    // unused — `filterBlockedConversations` reads live block state; the tick
    // only forces a re-filter on block/unblock/mute. Drift / stream IO errors
    // are expected and NOT Reportable per .claude/rules/error_handling.md; the
    // `addError` tear-off keeps them in the unified log.
    final blocklistTicks = contentBlocklistRepository == null
        ? Stream<Object?>.value(null)
        : contentBlocklistRepository.stateStream
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
              dmRepository.watchAcceptedConversations(),
              dmRepository.watchPotentialRequests(),
              followRepository.followingStream.startWith(const <String>[]),
              blocklistTicks,
              (accepted, potentialRequests, _, _) => _countUnread(
                accepted: accepted,
                potentialRequests: potentialRequests,
              ),
            )
            .listen(
              (count) {
                if (_subscriptionGeneration == generation) emit(count);
              },
              onError: (Object error, StackTrace stackTrace) {
                if (_subscriptionGeneration == generation) {
                  addError(error, stackTrace);
                }
              },
            );
  }

  /// Composes the visible Messages list (accepted ∪ followed-but-unreplied,
  /// blocklist-filtered) and counts the unread ones — the same set the inbox
  /// renders an unread dot for.
  int _countUnread({
    required List<DmConversation> accepted,
    required List<DmConversation> potentialRequests,
  }) {
    final dmRepository = _dmRepository;
    final followRepository = _followRepository;
    if (dmRepository == null || followRepository == null) return 0;

    final userPubkey = dmRepository.userPubkey;
    final split = DmRepository.classifyPotentialRequests(
      potentialRequests,
      userPubkey: userPubkey,
      isFollowing: followRepository.isFollowing,
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
    _subscriptionGeneration += 1;
    await _subscription?.cancel();
    await super.close();
  }
}
