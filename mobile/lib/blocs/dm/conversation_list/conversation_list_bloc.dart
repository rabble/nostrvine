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
import 'package:openvine/constants/search_constants.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:rxdart/rxdart.dart';

part 'conversation_list_event.dart';
part 'conversation_list_state.dart';

class ConversationListBloc
    extends Bloc<ConversationListEvent, ConversationListState> {
  ConversationListBloc({
    required DmRepository dmRepository,
    required FollowRepository followRepository,
    ContentBlocklistRepository? contentBlocklistRepository,
    ProfileRepository? profileRepository,
    ProtectedMinorInboxGate? protectedMinorInboxGate,
    Duration recomputeDebounce = _defaultRecomputeDebounce,
    String? supportRowPubkey,
  }) : _dmRepository = dmRepository,
       _followRepository = followRepository,
       _blocklistRepository = contentBlocklistRepository,
       _profileRepository = profileRepository,
       _protectedMinorInboxGate = protectedMinorInboxGate,
       _recomputeDebounce = recomputeDebounce,
       _supportRowPubkey = supportRowPubkey,
       super(const ConversationListState()) {
    on<ConversationListStarted>(_onStarted, transformer: restartable());
    on<ConversationListLoadMore>(_onLoadMore, transformer: droppable());
    on<ConversationListMarkRead>(_onMarkRead, transformer: droppable());
    on<ConversationListUnreadFilterToggled>(_onUnreadFilterToggled);
    on<ConversationListSearchQueryChanged>(
      _onSearchQueryChanged,
      transformer: debounceRestartable(),
    );
    on<_ConversationListProfileResolutionRequested>(
      _onProfileResolutionRequested,
      transformer: restartable(),
    );
    on<ConversationListNavigateToUser>(
      _onNavigateToUser,
      transformer: droppable(),
    );
    on<ConversationListNavigationConsumed>(_onNavigationConsumed);
    on<ConversationListBlocklistChanged>(_onBlocklistChanged);
    on<ConversationListRestoreRetryRequested>(
      _onRestoreRetryRequested,
      transformer: droppable(),
    );
    on<ConversationListProfileRepositoryChanged>(_onProfileRepositoryChanged);
  }

  final DmRepository _dmRepository;
  final FollowRepository _followRepository;
  final ContentBlocklistRepository? _blocklistRepository;

  /// Swappable: `profileRepositoryProvider` is nullable-gated on Nostr
  /// readiness and hands over the real instance after cold start. Re-pointed
  /// by [ConversationListProfileRepositoryChanged] rather than by recreating
  /// the bloc. Mirrors `NotificationBadgeCubit.setRepository`.
  ProfileRepository? _profileRepository;
  final ProtectedMinorInboxGate? _protectedMinorInboxGate;

  /// Moderation pubkey the pinned support row targets, injected rather than
  /// imported so this bloc stays free of app-layer config (#6283).
  final String? _supportRowPubkey;

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

    switch (state.status) {
      case ConversationListStatus.initial:
        emit(
          state.copyWith(
            status: ConversationListStatus.loading,
            currentLimit: ConversationListState.pageSize,
          ),
        );
      case ConversationListStatus.error:
        // Retry from InboxErrorState. Without this transition the tap produced
        // no state change at all: a repeat failure re-emits an Equatable-equal
        // error state, which `emit` suppresses, so the screen looked identical
        // before and after — and a slow-but-successful retry left the error
        // screen up for the whole in-flight window. `currentLimit` is kept: it
        // is a render window, so resetting it would discard the position the
        // user had already scrolled to.
        emit(state.copyWith(status: ConversationListStatus.loading));
      case ConversationListStatus.loading:
      case ConversationListStatus.loaded:
        // Re-entry from _onBlocklistChanged must not flash a spinner over an
        // already-loaded list or reset the window.
        break;
    }

    // Stream 1: accepted conversations (complete set, user has sent).
    // Stream 2: potential requests (unpaginated, user has NOT sent).
    // Stream 3: following list changes (triggers re-classification).
    // Stream 4: history-recovery progress (drives the restore indicator).
    // Combining ensures requests are never truncated by pagination
    // and follow-list changes are handled automatically.
    //
    // Stream 1 is deliberately UNPAGINATED. The unread chip and the search box
    // filter client-side, so a limited window would make them answer about the
    // loaded page rather than the inbox: with an unread chat ranked below the
    // window the list said "You're all caught up" while the Messages badge —
    // which counts the full accepted set — showed unread, and search reported
    // "No matches" for conversations the user could not scroll to. Pagination
    // is now a render window applied in [_computeVisible], not a fetch bound.
    // This is the same query `DmUnreadCountCubit` already runs app-shell-wide.
    await emit.forEach(
      Rx.combineLatest6(
        _dmRepository.watchAcceptedConversations(),
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

        final inboxConversations = DmRepository.mergeAndSort(
          data.accepted,
          split.followed,
        );

        final blocklistedInbox =
            _blocklistRepository?.filterBlockedConversations(
              inboxConversations,
              userPubkey: userPubkey,
            ) ??
            inboxConversations;
        // Filters the FULL request set, not the recovery-held-back one, so the
        // pin below is extracted from — and inherits the filters of — every
        // request regardless of the drain. The hold-back is applied after.
        final blocklistedRequests =
            _blocklistRepository?.filterBlockedConversations(
              split.requests,
              userPubkey: userPubkey,
            ) ??
            split.requests;

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

        // Lift the moderation thread out of the list into the pinned row, so
        // the inbox never renders it twice (#6283). Runs after both filters so
        // the pin inherits them rather than bypassing them.
        final pin = _extractPinnedSupport(
          userPubkey: userPubkey,
          inbox: visibleInbox,
          requests: visibleRequests,
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
        //
        // The pin is deliberately extracted ABOVE this line. It is a fixed
        // identity in a fixed position, not something the user has to triage
        // into a bucket, so it cannot produce the flash the hold-back exists
        // to prevent — withholding it would only blank its unread dot for the
        // duration of the drain, and the badge counts it either way (#4976).
        final recoveryComplete = _dmRepository.isHistoryRecoveryComplete;
        final requestConversations = recoveryComplete
            ? pin.requests
            : const <DmConversation>[];

        // A conversation can stream in while a name search is active whose
        // counterparty was not resolved when the search fired; it would fall
        // back to the generated name and drop out of the results until the
        // next keystroke. Re-run resolution so a just-arrived match surfaces on
        // its own. Scoped to genuinely NEW rows: the full set legitimately
        // carries counterparties the chunked resolver has not reached yet, and
        // re-firing for those would loop on every recompute.
        if (state.searchQuery.length >= minSearchQueryLength) {
          final known = state.conversations.map((c) => c.id).toSet();
          final hasNewUnresolved = pin.inbox.any(
            (c) =>
                !known.contains(c.id) &&
                !state.profileNames.containsKey(
                  _otherParticipant(c, userPubkey),
                ),
          );
          if (hasNewUnresolved) {
            add(const _ConversationListProfileResolutionRequested());
          }
        }

        return state.copyWith(
          status: ConversationListStatus.loaded,
          conversations: pin.inbox,
          // Only true when the gate is actually costing the user something —
          // a closed gate with nothing to hold back needs no banner. Reads the
          // post-filter, post-pin set rather than the raw `split.requests`
          // #6431 emitted: that reflected main's ordering, where the hold-back
          // ran before both filters, so a filtered list simply did not exist
          // while the gate was shut. Here it does, and a request the blocklist,
          // the #176 gate, or the pin itself already removed is not something
          // the gate is costing the user — least of all the moderation thread,
          // which is on screen as the pin the whole time.
          requestsWithheld: !recoveryComplete && pin.requests.isNotEmpty,
          visibleConversations: _computeVisible(
            pin.inbox,
            unreadOnly: state.unreadOnly,
            query: state.searchQuery,
            profileNames: state.profileNames,
            userPubkey: userPubkey,
            limit: state.currentLimit,
          ),
          requestConversations: requestConversations,
          potentialRequests: data.potentialRequests,
          hasMore: pin.inbox.length > state.currentLimit,
          isRestoringHistory: data.isRestoring,
          pinnedSupport: pin.pinned,
          clearPinnedSupport: pin.pinned == null,
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

  void _onLoadMore(
    ConversationListLoadMore event,
    Emitter<ConversationListState> emit,
  ) {
    if (!state.hasMore || state.status != ConversationListStatus.loaded) return;

    // The complete set is already loaded, so a page is a render window and this
    // is a pure re-slice — no stream restart, and therefore no spinner and no
    // repeat of the backfill/decrypt-replay side effects `_onStarted` triggers.
    final limit = state.currentLimit + ConversationListState.pageSize;
    emit(
      state.copyWith(
        currentLimit: limit,
        visibleConversations: _computeVisible(
          state.conversations,
          unreadOnly: state.unreadOnly,
          query: state.searchQuery,
          profileNames: state.profileNames,
          userPubkey: _dmRepository.userPubkey,
          limit: limit,
        ),
        hasMore: state.conversations.length > limit,
      ),
    );
  }

  void _onUnreadFilterToggled(
    ConversationListUnreadFilterToggled event,
    Emitter<ConversationListState> emit,
  ) {
    final unreadOnly = !state.unreadOnly;
    emit(
      state.copyWith(
        unreadOnly: unreadOnly,
        visibleConversations: _computeVisible(
          state.conversations,
          unreadOnly: unreadOnly,
          query: state.searchQuery,
          profileNames: state.profileNames,
          userPubkey: _dmRepository.userPubkey,
          limit: state.currentLimit,
        ),
      ),
    );
  }

  Future<void> _onSearchQueryChanged(
    ConversationListSearchQueryChanged event,
    Emitter<ConversationListState> emit,
  ) async {
    final rawQuery = event.query.trim();
    final query = rawQuery.length < minSearchQueryLength ? '' : rawQuery;
    final userPubkey = _dmRepository.userPubkey;

    // Emit first on what needs no lookup — message previews, names already
    // cached, and the deterministic fallback name — so the query lands
    // immediately even though the source is now the complete conversation set.
    emit(
      state.copyWith(
        searchQuery: query,
        visibleConversations: _computeVisible(
          state.conversations,
          unreadOnly: state.unreadOnly,
          query: query,
          profileNames: state.profileNames,
          userPubkey: userPubkey,
          limit: state.currentLimit,
        ),
      ),
    );

    // Capture the repository once: a mid-loop swap from
    // ConversationListProfileRepositoryChanged must not tear the sequence.
    await _resolveMissingProfileNames(
      emit,
      query: query,
      userPubkey: userPubkey,
    );
  }

  Future<void> _onProfileResolutionRequested(
    _ConversationListProfileResolutionRequested event,
    Emitter<ConversationListState> emit,
  ) async {
    final query = state.searchQuery;
    if (query.length < minSearchQueryLength) return;
    await _resolveMissingProfileNames(
      emit,
      query: query,
      userPubkey: _dmRepository.userPubkey,
    );
  }

  Future<void> _resolveMissingProfileNames(
    Emitter<ConversationListState> emit, {
    required String query,
    required String userPubkey,
  }) async {
    final profileRepository = _profileRepository;
    if (query.isEmpty || profileRepository == null) return;

    var profileNames = state.profileNames;
    final unresolved = state.conversations
        .map((c) => _otherParticipant(c, userPubkey))
        .where((pk) => !profileNames.containsKey(pk))
        .toSet()
        .toList();

    // Resolve in bounded chunks, most-recent first (state.conversations is
    // recency-sorted), re-emitting after each so results refine progressively.
    for (var i = 0; i < unresolved.length; i += searchProfileResolveChunkSize) {
      if (emit.isDone) return;
      final chunk = unresolved
          .skip(i)
          .take(searchProfileResolveChunkSize)
          .toList();
      var fetched = const <String, UserProfile>{};
      try {
        fetched = await profileRepository.fetchBatchProfiles(pubkeys: chunk);
      } catch (error, stackTrace) {
        // Network/cache failure is expected offline — match on the
        // generated fallback names instead. Not Reportable.
        addError(error, stackTrace);
      }
      profileNames = {
        ...profileNames,
        for (final pubkey in chunk)
          pubkey:
              fetched[pubkey]?.bestDisplayName ??
              UserProfile.defaultDisplayNameFor(pubkey),
      };
      if (emit.isDone) return;
      emit(
        state.copyWith(
          profileNames: profileNames,
          visibleConversations: _computeVisible(
            state.conversations,
            unreadOnly: state.unreadOnly,
            query: query,
            profileNames: profileNames,
            userPubkey: userPubkey,
            limit: state.currentLimit,
          ),
        ),
      );
    }
  }

  static String _otherParticipant(DmConversation conversation, String self) {
    return conversation.participantPubkeys.firstWhere(
      (pk) => pk != self,
      orElse: () => conversation.participantPubkeys.first,
    );
  }

  /// A synthetic pin carries no timestamp, so it needs a `createdAt` that is
  /// stable across recomputes — a clock read would make every debounce tick
  /// produce an unequal state and re-emit forever. The value is never shown:
  /// the pin renders no timestamp and is not sorted with the list.
  static const _pinnedSupportEpoch = 0;

  /// Extract the pinned Divine Moderation row, lifting the thread it adopts out
  /// of the list it would otherwise render in (#6283).
  ///
  /// Only the thread on the CURRENT moderation key is lifted. A thread on a
  /// key the account has rotated away from stays put and renders as an ordinary
  /// row, so its enforcement history keeps an in-app entry point until #6416
  /// gives it an archived read-only presentation.
  ///
  /// Called with lists that have ALREADY passed the blocklist filter and the
  /// protected-minor gate, so an existing moderation thread that those filters
  /// removed simply is not found here. The synthetic fallback is pushed back
  /// through both filters for the same reason: without that, a user who blocked
  /// the moderation account — or a restricted minor whose approval was revoked
  /// — would get a row that `ConversationPage`'s route guard bounces straight
  /// back to the inbox.
  ({
    PinnedSupport? pinned,
    List<DmConversation> inbox,
    List<DmConversation> requests,
  })
  _extractPinnedSupport({
    required String userPubkey,
    required List<DmConversation> inbox,
    required List<DmConversation> requests,
  }) {
    final supportPubkey = _supportRowPubkey;
    final split = DmRepository.extractPinnedSupport(
      userPubkey: userPubkey,
      supportPubkey: supportPubkey,
      inbox: inbox,
      requests: requests,
    );

    final adopted = split.pinned;
    if (adopted != null) {
      return (
        pinned: PinnedSupport(conversation: adopted, isPersisted: true),
        inbox: split.inbox,
        requests: split.requests,
      );
    }

    // Null means no pin is possible at all — no identity to key on, or the
    // signed-in user IS the moderation account. Nothing to synthesize against.
    final supportConversationId = split.supportConversationId;
    if (supportConversationId == null || supportPubkey == null) {
      return (pinned: null, inbox: split.inbox, requests: split.requests);
    }

    final synthetic = DmConversation(
      id: supportConversationId,
      participantPubkeys: [userPubkey, supportPubkey],
      isGroup: false,
      createdAt: _pinnedSupportEpoch,
    );

    final allowed =
        _blocklistRepository?.filterBlockedConversations([
          synthetic,
        ], userPubkey: userPubkey) ??
        [synthetic];
    final visible =
        _protectedMinorInboxGate?.filter(allowed, userPubkey: userPubkey) ??
        allowed;

    return (
      pinned: visible.isEmpty
          ? null
          : PinnedSupport(conversation: visible.first, isPersisted: false),
      inbox: split.inbox,
      requests: split.requests,
    );
  }

  /// Filtered view of [conversations], windowed to [limit] only when no filter
  /// is active.
  ///
  /// [conversations] is the COMPLETE accepted-union-followed set, so a filter
  /// result is always complete — "You're all caught up" and "No matches" can no
  /// longer be statements about just the loaded page.
  static List<DmConversation> _computeVisible(
    List<DmConversation> conversations, {
    required bool unreadOnly,
    required String query,
    required Map<String, String> profileNames,
    required String userPubkey,
    required int limit,
  }) {
    if (!unreadOnly && query.isEmpty) {
      return conversations.length > limit
          ? conversations.sublist(0, limit)
          : conversations;
    }
    return _applyFilters(
      conversations,
      unreadOnly: unreadOnly,
      query: query,
      profileNames: profileNames,
      userPubkey: userPubkey,
    );
  }

  static List<DmConversation> _applyFilters(
    List<DmConversation> conversations, {
    required bool unreadOnly,
    required String query,
    required Map<String, String> profileNames,
    required String userPubkey,
  }) {
    var result = conversations;
    if (unreadOnly) result = result.where((c) => !c.isRead).toList();
    if (query.isEmpty) return result;
    final normalized = query.toLowerCase();
    return result.where((c) {
      final other = _otherParticipant(c, userPubkey);
      final name =
          (profileNames[other] ?? UserProfile.defaultDisplayNameFor(other))
              .toLowerCase();
      final preview = c.lastMessageContent?.toLowerCase() ?? '';
      return name.contains(normalized) || preview.contains(normalized);
    }).toList();
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

  /// Swap in a freshly built [ProfileRepository] without recreating the bloc.
  ///
  /// A `ValueKey` on the owning `BlocProvider` would re-inflate every provider
  /// below it *and* the whole `InboxView` subtree — a `nested` key replaces the
  /// entire downstream chain, not just its own provider — losing the tab
  /// selection, scroll offset and search text. Swapping the dependency in place
  /// refreshes only what actually changed.
  void _onProfileRepositoryChanged(
    ConversationListProfileRepositoryChanged event,
    Emitter<ConversationListState> emit,
  ) {
    if (identical(_profileRepository, event.profileRepository)) return;
    _profileRepository = event.profileRepository;
    if (state.searchQuery.isEmpty) return;
    // Any names cached while no repository was available are deterministic
    // fallbacks, not real profiles. Drop them so the active query re-resolves.
    emit(state.copyWith(profileNames: const {}));
    add(ConversationListSearchQueryChanged(state.searchQuery));
  }

  /// Re-trigger the watched streams so blocked users are filtered out.
  void _onBlocklistChanged(
    ConversationListBlocklistChanged event,
    Emitter<ConversationListState> emit,
  ) {
    add(const ConversationListStarted());
  }

  void _onRestoreRetryRequested(
    ConversationListRestoreRetryRequested event,
    Emitter<ConversationListState> emit,
  ) {
    // Same idiom as _onBlocklistChanged: re-entering _onStarted re-fires both
    // recovery passes (idempotent, shared in-flight) and restarts the stream,
    // so the gate is re-read and `requestsWithheld` recomputed. Going through
    // the stream rather than awaiting the drain matters — the drain returns
    // early without ever touching the recovery stream when it is uninitialized
    // or already complete, so a listener-only retry could leave the banner up
    // with nothing to clear it. The status switch in _onStarted keeps a loaded
    // list from flashing a spinner.
    add(const ConversationListStarted());
  }

  @override
  Future<void> close() {
    // The gift-wrap subscription is owned by `dmRepositoryProvider` for the
    // whole authenticated session — do NOT stop it here. See #2931.
    return super.close();
  }
}
