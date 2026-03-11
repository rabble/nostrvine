// ABOUTME: Events for ConversationBloc.

part of 'conversation_bloc.dart';

sealed class ConversationEvent extends Equatable {
  const ConversationEvent();

  @override
  List<Object?> get props => [];
}

/// Start watching messages in this conversation.
class ConversationStarted extends ConversationEvent {
  const ConversationStarted();
}

/// Send a message to the conversation recipients.
class ConversationMessageSent extends ConversationEvent {
  const ConversationMessageSent({
    required this.recipientPubkeys,
    required this.content,
  });

  final List<String> recipientPubkeys;
  final String content;

  @override
  List<Object?> get props => [recipientPubkeys, content];
}
