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
    this.hasMore = true,
    this.isLoadingMore = false,
    this.currentLimit = ConversationListState.pageSize,
    this.navigationTarget,
  });

  /// Number of conversations loaded per page.
  static const pageSize = 20;

  final ConversationListStatus status;
  final List<DmConversation> conversations;

  /// Whether more conversations may exist beyond the current page.
  final bool hasMore;

  /// Whether a load-more operation is currently in progress.
  final bool isLoadingMore;

  /// Current watch limit — grows as the user loads more pages.
  final int currentLimit;

  /// Set when the user requests navigation to a specific conversation.
  /// Consumed and cleared by the UI after navigating.
  final ConversationNavigationTarget? navigationTarget;

  ConversationListState copyWith({
    ConversationListStatus? status,
    List<DmConversation>? conversations,
    bool? hasMore,
    bool? isLoadingMore,
    int? currentLimit,
    ConversationNavigationTarget? navigationTarget,
    bool clearNavigationTarget = false,
  }) {
    return ConversationListState(
      status: status ?? this.status,
      conversations: conversations ?? this.conversations,
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
    hasMore,
    isLoadingMore,
    currentLimit,
    navigationTarget,
  ];
}
