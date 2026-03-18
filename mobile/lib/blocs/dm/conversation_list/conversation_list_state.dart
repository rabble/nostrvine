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
    this.requestConversations = const [],
    this.potentialRequests = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
    this.currentLimit = ConversationListState.pageSize,
    this.navigationTarget,
  });

  /// Number of conversations loaded per page.
  static const pageSize = 20;

  final ConversationListStatus status;

  /// Conversations shown in the Messages tab (accepted + followed contacts).
  final List<DmConversation> conversations;

  /// Conversations shown in the Requests tab (non-followed, never replied).
  final List<DmConversation> requestConversations;

  /// Raw potential requests from DB (`currentUserHasSent == false`).
  ///
  /// Stored so that follow-list changes can re-split without a DB query.
  final List<DmConversation> potentialRequests;

  /// Whether more accepted conversations may exist beyond the current page.
  final bool hasMore;

  /// Whether a load-more operation is currently in progress.
  final bool isLoadingMore;

  /// Current watch limit — grows as the user loads more pages.
  final int currentLimit;

  /// Set when the user requests navigation to a specific conversation.
  /// Consumed and cleared by the UI after navigating.
  final ConversationNavigationTarget? navigationTarget;

  /// Number of unread message requests.
  int get requestUnreadCount =>
      requestConversations.where((c) => !c.isRead).length;

  ConversationListState copyWith({
    ConversationListStatus? status,
    List<DmConversation>? conversations,
    List<DmConversation>? requestConversations,
    List<DmConversation>? potentialRequests,
    bool? hasMore,
    bool? isLoadingMore,
    int? currentLimit,
    ConversationNavigationTarget? navigationTarget,
    bool clearNavigationTarget = false,
  }) {
    return ConversationListState(
      status: status ?? this.status,
      conversations: conversations ?? this.conversations,
      requestConversations: requestConversations ?? this.requestConversations,
      potentialRequests: potentialRequests ?? this.potentialRequests,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      currentLimit: currentLimit ?? this.currentLimit,
      navigationTarget: clearNavigationTarget
          ? null
          : navigationTarget ?? this.navigationTarget,
    );
  }

  @override
  List<Object?> get props => [
    status,
    conversations,
    requestConversations,
    potentialRequests,
    hasMore,
    isLoadingMore,
    currentLimit,
    navigationTarget,
  ];
}
