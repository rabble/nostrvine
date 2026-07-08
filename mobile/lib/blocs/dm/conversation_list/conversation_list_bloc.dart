// ABOUTME: BLoC for the conversation list (Messages tab).
// ABOUTME: Manages loading conversations with pagination, handling real-time
// ABOUTME: updates, marking conversations as read, and splitting conversations
// ABOUTME: into normal inbox vs message requests based on follow state.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation_list/protected_minor_inbox_gate.dart';
import 'package:rxdart/rxdart.dart';

part 'conversation_list_event.dart';
part 'conversation_list_state.dart';

class ConversationListBloc
    extends Bloc<ConversationListEvent, ConversationListState> {
  ConversationListBloc({
    required DmRepository dmRepository,
    required FollowRepository followRepository,
    ContentBlocklistRepository? contentBlocklistRepository,
    ProtectedMinorInboxGate? protectedMinorInboxGate,
    Duration recomputeDebounce = _defaultRecomputeDebounce,
  }) : _dmRepository = dmRepository,
       _followRepository = followRepository,
       _blocklistRepository = contentBlocklistRepository,
       _protectedMinorInboxGate = protectedMinorInboxGate,
       _recomputeDebounce = recomputeDebounce,
       super(const ConversationListState()) {
    on<ConversationListStarted>(_onStarted, transformer: restartable());
    on<ConversationListLoadMore>(_onLoadMore, transformer: droppable());
    on<ConversationListMarkRead>(_onMarkRead, transformer: droppable());
    on<ConversationListNavigateToUser>(
      _onNavigateToUser,
      transformer: droppable(),
    );
    on<ConversationListNavigationConsumed>(_onNavigationConsumed);
    on<ConversationListBlocklistChanged>(_onBlocklistChanged);
  }

  final DmRepository _dmRepository;
  final FollowRepository _followRepository;
  final ContentBlocklistRepository? _blocklistRepository;
  final ProtectedMinorInboxGate? _protectedMinorInboxGate;

  /// Window over which bursty conversation writes are coalesced before the
  /// list is re-composed. The combined stream re-runs `classifyPotentialRequests`
  /// + `mergeAndSort` + two `filterBlockedConversations` passes in `onData` on
  /// every conversations-table write; relay deliveries, the mark-read fan-out,
  /// and the post-reinstall drain fire those in bursts. Debouncing collapses a
  /// burst into a single recompute. The list is not latency-critical, so the
  /// small delay is invisible and the settled result is identical. Overridable
  /// in tests.
  static const _defaultRecomputeDebounce = Duration(milliseconds: 200);

  final Duration _recomputeDebounce;

  Future<void> _onStarted(
    ConversationListStarted event,
    Emitter<ConversationListState> emit,
  ) async {
    // The gift-wrap subscription is started by `dmRepositoryProvider` for
    // the whole authenticated session — this BLoC just consumes the
    // already-running stream via the DAO. See #2931.

    // Recover the full DM history once per install. After a reinstall the
    // live subscription's first-open window (limit:50) only persists the
    // most-recent conversations; this idempotent, one-time, background
    // drain backfills the rest so the list is complete. Triggered here (on
    // inbox open) because relay discovery has reliably finished by the time
    // the user navigates to Messages — fetching against the full relay
    // pool, not the divine-only pool present at cold start. See #4953.
    unawaited(_dmRepository.backfillHistoryIfNeeded());

    // Replay any gift wraps that failed decryption on a previous pass (e.g.
    // a transient Keycast RPC failure during the drain burst) so a flaky
    // remote signer never permanently loses a conversation. See #5202.
    unawaited(_dmRepository.retryPendingDecryptions());

    // Only show the loading spinner and reset limit on first load.
    if (state.status == ConversationListStatus.initial) {
      emit(
        state.copyWith(
          status: ConversationListStatus.loading,
          currentLimit: ConversationListState.pageSize,
        ),
      );
    }

    // Stream 1: accepted conversations (paginated, user has sent).
    // Stream 2: potential requests (unpaginated, user has NOT sent).
    // Stream 3: following list changes (triggers re-classification).
    // Stream 4: history-recovery progress (drives the restore indicator).
    // Combining ensures requests are never truncated by pagination
    // and follow-list changes are handled automatically.
    await emit.forEach(
      Rx.combineLatest6(
        _dmRepository.watchAcceptedConversations(limit: state.currentLimit),
        _dmRepository.watchPotentialRequests(),
        _followRepository.followingStream.startWith(const []),
        _dmRepository.historyRecoveryStream.startWith(
          _dmRepository.isRecoveringHistory,
        ),
        // Stream 5: the user's pubkey. The DAO streams emit cached rows before
        // `setCredentials` populates it at cold start, so classifying with the
        // empty pre-auth pubkey would misroute every 1:1. This re-fires the
        // handler once the real identity arrives. See #5374.
        _dmRepository.userPubkeyStream.startWith(_dmRepository.userPubkey),
        // Stream 6: protected-minor verdict changes (#176). A receive-time
        // revalidation that flips a counterparty's approval fires here so the
        // list re-filters and a just-revoked official drops, even though no
        // conversation row changed. Pass-through (never emits) when unrestricted.
        (_protectedMinorInboxGate?.changes ?? const Stream<void>.empty())
            .startWith(null),
        (accepted, potentialRequests, _, isRestoring, userPubkey, _) => (
          accepted: accepted,
          potentialRequests: potentialRequests,
          isRestoring: isRestoring,
          userPubkey: userPubkey,
        ),
      ).debounceTime(_recomputeDebounce),
      onData: (data) {
        // Until credentials are set, the pubkey is empty and self cannot be
        // filtered out of a conversation's participants — classifying now would
        // make every 1:1 look like a group and land in Message requests. Hold
        // the current (loading) state; stream 5 re-fires this once the real
        // identity is available. See #5374.
        final userPubkey = data.userPubkey;
        if (userPubkey.isEmpty) return state;

        final split = DmRepository.classifyPotentialRequests(
          data.potentialRequests,
          userPubkey: userPubkey,
          isFollowing: _followRepository.isFollowing,
        );

        // While the one-time history-recovery drain is still running
        // (post-reinstall window), HOLD BACK the conversations that would
        // classify as requests. Until the drain re-ingests the user's own
        // message for a chat, a previously-accepted conversation is
        // indistinguishable from a genuine request — both have
        // currentUserHasSent=false and an unfollowed peer. Showing them as
        // requests is the original #5304 bug; showing them in the inbox makes
        // real requests flash there and then jump to the Requests tab once
        // recovery completes. So during recovery we surface only the
        // unambiguous chats (accepted + followed), backed by the restore
        // indicator, and let the ambiguous ones settle into their correct
        // bucket as soon as recovery completes. See #5304.
        final recoveryComplete = _dmRepository.isHistoryRecoveryComplete;
        final inboxConversations = DmRepository.mergeAndSort(
          data.accepted,
          split.followed,
        );
        final requests = recoveryComplete
            ? split.requests
            : const <DmConversation>[];

        final blocklistedInbox =
            _blocklistRepository?.filterBlockedConversations(
              inboxConversations,
              userPubkey: userPubkey,
            ) ??
            inboxConversations;
        final blocklistedRequests =
            _blocklistRepository?.filterBlockedConversations(
              requests,
              userPubkey: userPubkey,
            ) ??
            requests;

        // Protected-minor inbound filter (#176): hide conversations whose
        // counterparty (all non-self participants) is not an approved official
        // recipient. Pass-through for a non-restricted user. Applied after the
        // blocklist filter so both hidden sets compose.
        final visibleInbox =
            _protectedMinorInboxGate?.filter(
              blocklistedInbox,
              userPubkey: userPubkey,
            ) ??
            blocklistedInbox;
        final visibleRequests =
            _protectedMinorInboxGate?.filter(
              blocklistedRequests,
              userPubkey: userPubkey,
            ) ??
            blocklistedRequests;

        return state.copyWith(
          status: ConversationListStatus.loaded,
          conversations: visibleInbox,
          requestConversations: visibleRequests,
          potentialRequests: data.potentialRequests,
          hasMore: data.accepted.length == state.currentLimit,
          isLoadingMore: false,
          isRestoringHistory: data.isRestoring,
        );
      },
      onError: (error, stackTrace) {
        // Drift / follow-stream IO failures are expected. Per
        // .claude/rules/error_handling.md they are NOT Reportable.
        addError(error, stackTrace);
        return state.copyWith(status: ConversationListStatus.error);
      },
    );
  }

  Future<void> _onLoadMore(
    ConversationListLoadMore event,
    Emitter<ConversationListState> emit,
  ) async {
    if (!state.hasMore ||
        state.isLoadingMore ||
        state.status != ConversationListStatus.loaded) {
      return;
    }

    emit(
      state.copyWith(
        isLoadingMore: true,
        currentLimit: state.currentLimit + ConversationListState.pageSize,
      ),
    );

    // Re-trigger the watched stream with the larger limit.
    // restartable() on ConversationListStarted cancels the previous watch.
    add(const ConversationListStarted());
  }

  Future<void> _onMarkRead(
    ConversationListMarkRead event,
    Emitter<ConversationListState> emit,
  ) async {
    await _dmRepository.markConversationAsRead(event.conversationId);
  }

  void _onNavigateToUser(
    ConversationListNavigateToUser event,
    Emitter<ConversationListState> emit,
  ) {
    final currentPubkey = _dmRepository.userPubkey;
    if (currentPubkey.isEmpty) return;

    final conversationId = DmRepository.computeConversationId([
      currentPubkey,
      event.participantPubkey,
    ]);
    emit(
      state.copyWith(
        navigationTarget: ConversationNavigationTarget(
          conversationId: conversationId,
          participantPubkeys: [event.participantPubkey],
        ),
      ),
    );
  }

  void _onNavigationConsumed(
    ConversationListNavigationConsumed event,
    Emitter<ConversationListState> emit,
  ) {
    emit(state.copyWith(clearNavigationTarget: true));
  }

  /// Re-trigger the watched streams so blocked users are filtered out.
  void _onBlocklistChanged(
    ConversationListBlocklistChanged event,
    Emitter<ConversationListState> emit,
  ) {
    add(const ConversationListStarted());
  }

  @override
  Future<void> close() {
    // The gift-wrap subscription is owned by `dmRepositoryProvider` for the
    // whole authenticated session — do NOT stop it here. See #2931.
    return super.close();
  }
}
