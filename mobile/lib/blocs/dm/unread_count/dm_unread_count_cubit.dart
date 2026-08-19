// ABOUTME: Cubit that exposes the unread "Messages" conversation count.
// ABOUTME: Mirrors the Messages list composition (accepted union followed,
// ABOUTME: blocklist-filtered) so the badge matches the visible unread dots.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/dm/conversation_list/protected_minor_inbox_gate.dart';
import 'package:rxdart/rxdart.dart';

/// Cubit that tracks the number of unread DM conversations shown in the
/// Messages tab.
///
/// The badge must equal the unread conversations the Messages list actually
/// renders. That list is **follow-aware**: it shows accepted conversations
/// (the user has replied) PLUS unreplied conversations where every non-self
/// participant is followed, and it hides blocklisted peers. Counting only
/// `currentUserHasSent == true` (the previous behaviour) undercounted unread
/// chats from followed-but-unreplied peers. See #4976.
///
/// Parity with the list is structural: this reuses the same static
/// [DmRepository.classifyPotentialRequests] / [DmRepository.mergeAndSort] /
/// [DmRepository.extractPinnedSupport] helpers and
/// [ContentBlocklistRepository.filterBlockedConversations] that
/// [ConversationListBloc] uses, so the count cannot drift from the list. It
/// intentionally does NOT replicate one list-only concern:
///
/// * **Pagination** — the list renders one page; the badge counts the full
///   accepted set (unpaginated) so it reflects total unread, not the page.
///
/// The pinned support row (#6283) IS counted, because the inbox renders it
/// with an unread dot. That pulls one conversation out of the requests bucket
/// and into this count — an inbound-only moderation thread (the team wrote
/// first) is no longer a Requests entry, it is the pin. The recovery hold-back
/// (#5304) does not apply to it for the same reason it does not in the bloc:
/// the pin is never routed into a bucket, so it cannot flash between two.
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
class DmUnreadCountCubit extends Cubit<int> with CloseGuardedEmit<int> {
  DmUnreadCountCubit({
    required DmRepository dmRepository,
    required FollowRepository followRepository,
    ContentBlocklistRepository? contentBlocklistRepository,
    ProtectedMinorInboxGate? protectedMinorInboxGate,
    Duration recomputeDebounce = _defaultRecomputeDebounce,
    String? supportRowPubkey,
  }) : _protectedMinorInboxGate = protectedMinorInboxGate,
       _recomputeDebounce = recomputeDebounce,
       _supportRowPubkey = supportRowPubkey,
       super(0) {
    setRepositories(
      dmRepository: dmRepository,
      followRepository: followRepository,
      contentBlocklistRepository: contentBlocklistRepository,
    );
  }

  /// Window over which bursty conversation writes are coalesced into a single
  /// recompute. This cubit is always mounted (app-shell scope) and re-runs the
  /// full follow-aware, blocklist-filtered list composition on every
  /// conversations-table write; a relay delivery, the mark-read fan-out, or the
  /// post-reinstall history drain can fire dozens of writes in a burst.
  /// Collapsing each burst into one classify+sort+filter pass removes redundant
  /// main-isolate CPU. The count is not latency-critical, so the small delay is
  /// invisible and the coalesced result is identical. Overridable in tests.
  static const _defaultRecomputeDebounce = Duration(milliseconds: 200);

  /// Same inbound filter the list uses (#176). Stable across repository swaps
  /// (it depends on the session-scoped officials service, not the auth-rebuilt
  /// repositories), so it's held once here rather than passed to
  /// [setRepositories]. Null when the user is unrestricted / not wired.
  final ProtectedMinorInboxGate? _protectedMinorInboxGate;
  final Duration _recomputeDebounce;

  /// Moderation pubkey the inbox pins (#6283). Injected exactly as
  /// `ConversationListBloc` takes it, and for the same reason: the badge must
  /// partition the list the same way the list does, or it counts a row the
  /// inbox does not render and misses one it does.
  final String? _supportRowPubkey;
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

    // Protected-minor verdict changes (#176): a receive-time revalidation that
    // flips a counterparty's approval must re-count so the badge drops the now
    // hidden conversation, just as the list does. Value unused (re-count only).
    final minorVerdictTicks =
        (_protectedMinorInboxGate?.changes ?? const Stream<void>.empty())
            .map<Object?>((_) => null)
            .startWith(null);

    // The combiner stays cheap — it only packages the inputs into a record so
    // the debounce sees one value per source tick. The expensive recompute
    // (`_countUnread`: classify + mergeAndSort + filter) runs AFTER the debounce
    // in `map`, so a burst of writes triggers a single pass, not one per write.
    // Following/blocklist ticks carry no value into the record — they only need
    // to trigger a recompute, and `_countUnread` reads the live follow/block
    // state, so the debounced `map` picks up their latest values.
    _subscription =
        Rx.combineLatest6<
              List<DmConversation>,
              List<DmConversation>,
              List<String>,
              Object?,
              String,
              Object?,
              (List<DmConversation>, List<DmConversation>, String)
            >(
              dmRepository.watchAcceptedConversations(),
              dmRepository.watchPotentialRequests(),
              followRepository.followingStream.startWith(const <String>[]),
              blocklistTicks,
              // Identity stream (#5374): the DAO streams emit cached rows before
              // setCredentials populates the pubkey at cold start; without it
              // _countUnread classifies with the empty pubkey and undercounts
              // followed-but-unreplied 1:1s. Re-fires once the identity lands.
              dmRepository.userPubkeyStream.startWith(dmRepository.userPubkey),
              minorVerdictTicks,
              (accepted, potentialRequests, _, _, userPubkey, _) => (
                accepted,
                potentialRequests,
                userPubkey,
              ),
            )
            .debounceTime(_recomputeDebounce)
            .map(
              (inputs) => _countUnread(
                accepted: inputs.$1,
                potentialRequests: inputs.$2,
                userPubkey: inputs.$3,
              ),
            )
            .listen(
              (count) {
                if (_subscriptionGeneration == generation) emitIfOpen(count);
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
    required String userPubkey,
  }) {
    final dmRepository = _dmRepository;
    final followRepository = _followRepository;
    if (dmRepository == null || followRepository == null) return 0;

    // Until credentials are set the pubkey is empty and self cannot be filtered
    // from a conversation's participants — classifying now drops every followed
    // 1:1 from the count. Keep the current count; the identity stream re-fires
    // this once the real pubkey arrives. See #5374.
    if (userPubkey.isEmpty) return state;

    final split = DmRepository.classifyPotentialRequests(
      potentialRequests,
      userPubkey: userPubkey,
      isFollowing: followRepository.isFollowing,
    );
    final merged = DmRepository.mergeAndSort(accepted, split.followed);

    // Partition the pinned support row out exactly as the inbox does (#6283),
    // then count it back in. Adding `adopted` back is the whole point: a
    // current-key moderation thread must be counted even when it arrived as a
    // request, because the inbox renders it as the pin, unread dot and all —
    // and counting `pin.inbox` alone would silently drop it. A retired-key
    // thread needs nothing special; the partition leaves it in `pin.inbox`,
    // which is where the list renders it too. The bloc's synthetic stand-in is
    // deliberately NOT reproduced here: it is always read, so it can only ever
    // add zero and one more gate pass.
    final pin = DmRepository.extractPinnedSupport(
      userPubkey: userPubkey,
      supportPubkey: _supportRowPubkey,
      inbox: merged,
      requests: split.requests,
    );
    final adopted = pin.pinned;
    final inbox = adopted == null ? pin.inbox : [...pin.inbox, adopted];

    final blocklisted =
        _blocklistRepository?.filterBlockedConversations(
          inbox,
          userPubkey: userPubkey,
        ) ??
        inbox;
    // Protected-minor filter (#176): the badge must apply the SAME predicate as
    // the list, or it leaks the existence + count of hidden contact attempts.
    // Filtering the union in one pass rather than the pin separately keeps this
    // to a single gate call — `filter` can kick a receive-time revalidation, so
    // each extra call site is another revalidation trigger.
    final visible =
        _protectedMinorInboxGate?.filter(blocklisted, userPubkey: userPubkey) ??
        blocklisted;
    return visible.where((c) => !c.isRead).length;
  }

  @override
  Future<void> close() async {
    _subscriptionGeneration += 1;
    await _subscription?.cancel();
    await super.close();
  }
}
