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

/// Delete a sent message for everyone via NIP-09 kind 5.
class ConversationMessageDeleted extends ConversationEvent {
  const ConversationMessageDeleted({required this.rumorId});

  final String rumorId;

  @override
  List<Object?> get props => [rumorId];
}

/// Retry a previously-failed optimistic message.
///
/// The pending id identifies the in-state optimistic row to resend;
/// the bloc removes the failed entry, emits a fresh `sending` state,
/// and re-invokes sendMessage.
class ConversationMessageRetried extends ConversationEvent {
  const ConversationMessageRetried({
    required this.pendingId,
    required this.recipientPubkeys,
    required this.content,
  });

  final String pendingId;
  final List<String> recipientPubkeys;
  final String content;

  @override
  List<Object?> get props => [pendingId, recipientPubkeys, content];
}
