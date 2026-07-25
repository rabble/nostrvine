// ABOUTME: State for ConversationListBloc.

part of 'conversation_list_bloc.dart';

enum ConversationListStatus { initial, loading, loaded, error }

/// Navigation target emitted when the user requests to open a conversation.
///
/// Consumed and cleared by the UI after navigating.
class ConversationNavigationTarget extends Equatable {
  const ConversationNavigationTarget({
    required this.conversationId,
    required this.participantPubkeys,
  });

  final String conversationId;
  final List<String> participantPubkeys;

  @override
  List<Object?> get props => [conversationId, participantPubkeys];
}

class ConversationListState extends Equatable {
  const ConversationListState({
    this.status = ConversationListStatus.initial,
    this.conversations = const [],
    this.visibleConversations = const [],
    this.unreadOnly = false,
    this.searchQuery = '',
    this.profileNames = const {},
    this.requestConversations = const [],
    this.potentialRequests = const [],
    this.hasMore = true,
    this.isRestoringHistory = false,
    this.requestsWithheld = false,
    this.currentLimit = ConversationListState.pageSize,
    this.navigationTarget,
    this.pinnedConversation,
  });

  /// Number of conversations loaded per page.
  static const pageSize = 20;

  final ConversationListStatus status;

  /// The COMPLETE set of conversations for the Messages tab (accepted +
  /// followed contacts), unpaginated.
  ///
  /// Holding the full set is what lets the unread chip and search answer about
  /// the whole inbox instead of the loaded page.
  final List<DmConversation> conversations;

  /// The rendered slice of [conversations]: filtered when a filter is active,
  /// otherwise windowed to [currentLimit].
  ///
  /// A filter result is never windowed — it is already complete, so it can be
  /// shorter than a page without meaning "there might be more".
  ///
  /// Stored (not derived via a getter) so `context.select` sees a stable
  /// list identity across unrelated state emits.
  final List<DmConversation> visibleConversations;

  /// Whether the Messages list is filtered to unread conversations only.
  final bool unreadOnly;

  /// Trimmed inbox search query; empty when search is inactive.
  final String searchQuery;

  /// Resolved display names by counterparty pubkey, used for search
  /// matching. Grows lazily the first time a query needs a name.
  final Map<String, String> profileNames;

  /// Conversations shown in the Requests tab (non-followed, never replied).
  final List<DmConversation> requestConversations;

  /// Raw potential requests from DB (`currentUserHasSent == false`).
  ///
  /// Stored so that follow-list changes can re-split without a DB query.
  final List<DmConversation> potentialRequests;

  /// Whether [conversations] holds more rows than the current render window.
  ///
  /// Exact, not a heuristic: the full set is loaded, so this is a comparison
  /// against [currentLimit] rather than a guess from a truncated page.
  final bool hasMore;

  /// Whether a one-time DM history recovery (reinstall backfill / failed-
  /// decrypt replay) is actively running. Drives the restore progress
  /// indicator at the top of the Messages list. See #5202.
  final bool isRestoringHistory;

  /// Whether the #5304 recovery gate is currently hiding conversations that
  /// would otherwise appear as message requests.
  ///
  /// Distinct from [isRestoringHistory] on purpose. That flag tracks whether a
  /// drain is *actively running* (`_activeRecoveryOps > 0`), but the gate reads
  /// the *persisted* `historyDrainComplete`, which only ever flips on a clean
  /// exhaustion. A drain that stops at the page cap, hits an exception, or
  /// finds no connected relay clears the running flag while leaving the gate
  /// shut — so the progress bar vanished while requests stayed hidden, with no
  /// banner, no badge and no spinner to show anything was missing. Drives the
  /// restore-paused banner, which offers the retry that reopens the gate.
  final bool requestsWithheld;

  /// Size of the render window over [conversations] — grows as the user pages.
  ///
  /// Not a fetch bound: the conversations are already loaded in full, so
  /// growing this is a pure re-slice with no query and no spinner.
  final int currentLimit;

  /// Set when the user requests navigation to a specific conversation.
  /// Consumed and cleared by the UI after navigating.
  final ConversationNavigationTarget? navigationTarget;

  /// The pinned Divine Moderation support conversation, or null when the
  /// support row should not render (#6283).
  ///
  /// Composed inside the same pipeline that applies the blocklist filter and
  /// the protected-minor inbound gate, so a user who blocked the moderation
  /// account — or a restricted minor whose approval was revoked — gets null
  /// rather than a row that the conversation route guard would bounce.
  ///
  /// When a real moderation thread exists this holds *that* conversation
  /// (carrying its unread state and last message) and it is removed from
  /// [conversations] so the inbox never shows it twice. Otherwise it is a
  /// synthetic, non-persisted conversation with no unread state.
  final DmConversation? pinnedConversation;

  /// Number of unread message requests.
  int get requestUnreadCount =>
      requestConversations.where((c) => !c.isRead).length;

  /// Whether a client-side filter (unread chip or search) is narrowing the
  /// visible list.
  ///
  /// Load-more is suspended while this is true: a filtered result is computed
  /// over the full conversation set and is therefore already complete, so
  /// growing the render window could only append unfiltered rows — and a short
  /// filtered list can never scroll far enough to trigger it anyway.
  bool get isFiltering => unreadOnly || searchQuery.isNotEmpty;

  ConversationListState copyWith({
    ConversationListStatus? status,
    List<DmConversation>? conversations,
    List<DmConversation>? visibleConversations,
    bool? unreadOnly,
    String? searchQuery,
    Map<String, String>? profileNames,
    List<DmConversation>? requestConversations,
    List<DmConversation>? potentialRequests,
    bool? hasMore,
    bool? isRestoringHistory,
    bool? requestsWithheld,
    int? currentLimit,
    ConversationNavigationTarget? navigationTarget,
    bool clearNavigationTarget = false,
    DmConversation? pinnedConversation,
    bool clearPinnedConversation = false,
  }) {
    return ConversationListState(
      status: status ?? this.status,
      conversations: conversations ?? this.conversations,
      visibleConversations: visibleConversations ?? this.visibleConversations,
      unreadOnly: unreadOnly ?? this.unreadOnly,
      searchQuery: searchQuery ?? this.searchQuery,
      profileNames: profileNames ?? this.profileNames,
      requestConversations: requestConversations ?? this.requestConversations,
      potentialRequests: potentialRequests ?? this.potentialRequests,
      hasMore: hasMore ?? this.hasMore,
      isRestoringHistory: isRestoringHistory ?? this.isRestoringHistory,
      requestsWithheld: requestsWithheld ?? this.requestsWithheld,
      currentLimit: currentLimit ?? this.currentLimit,
      navigationTarget: clearNavigationTarget
          ? null
          : navigationTarget ?? this.navigationTarget,
      pinnedConversation: clearPinnedConversation
          ? null
          : pinnedConversation ?? this.pinnedConversation,
    );
  }

  @override
  List<Object?> get props => [
    status,
    conversations,
    visibleConversations,
    unreadOnly,
    searchQuery,
    profileNames,
    requestConversations,
    potentialRequests,
    hasMore,
    isRestoringHistory,
    requestsWithheld,
    currentLimit,
    navigationTarget,
    pinnedConversation,
  ];
}
