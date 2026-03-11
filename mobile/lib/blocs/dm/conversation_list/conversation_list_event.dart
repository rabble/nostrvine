// ABOUTME: Events for ConversationListBloc.

part of 'conversation_list_bloc.dart';

sealed class ConversationListEvent extends Equatable {
  const ConversationListEvent();

  @override
  List<Object?> get props => [];
}

/// Start watching conversations from the database.
class ConversationListStarted extends ConversationListEvent {
  const ConversationListStarted();
}

/// Mark a conversation as read.
class ConversationListMarkRead extends ConversationListEvent {
  const ConversationListMarkRead(this.conversationId);

  final String conversationId;

  @override
  List<Object?> get props => [conversationId];
}
