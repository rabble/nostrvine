// ABOUTME: State for ConversationListBloc.

part of 'conversation_list_bloc.dart';

enum ConversationListStatus { initial, loading, loaded, error }

class ConversationListState extends Equatable {
  const ConversationListState({
    this.status = ConversationListStatus.initial,
    this.conversations = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  final ConversationListStatus status;
  final List<DmConversation> conversations;

  /// Whether more conversations may exist beyond the current page.
  final bool hasMore;

  /// Whether a load-more operation is currently in progress.
  final bool isLoadingMore;

  ConversationListState copyWith({
    ConversationListStatus? status,
    List<DmConversation>? conversations,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return ConversationListState(
      status: status ?? this.status,
      conversations: conversations ?? this.conversations,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [status, conversations, hasMore, isLoadingMore];
}
