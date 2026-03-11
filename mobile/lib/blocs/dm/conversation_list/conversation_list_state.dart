// ABOUTME: State for ConversationListBloc.

part of 'conversation_list_bloc.dart';

enum ConversationListStatus { initial, loading, loaded, error }

class ConversationListState extends Equatable {
  const ConversationListState({
    this.status = ConversationListStatus.initial,
    this.conversations = const [],
  });

  final ConversationListStatus status;
  final List<DmConversation> conversations;

  ConversationListState copyWith({
    ConversationListStatus? status,
    List<DmConversation>? conversations,
  }) {
    return ConversationListState(
      status: status ?? this.status,
      conversations: conversations ?? this.conversations,
    );
  }

  @override
  List<Object?> get props => [status, conversations];
}
