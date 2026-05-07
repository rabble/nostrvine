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

/// Re-publish only the sender self-addressed gift wraps for rumors
/// whose recipient publish landed but whose self-wrap did not.
///
/// Dispatched by the retry action on the `sentPartial` SnackBar. The
/// repository's [recoverSelfWrap] never republishes the recipient
/// wrap, so recipients are not re-delivered to. Carries the affected
/// [rumorIds] explicitly rather than reading them from state — the
/// handler stays decoupled from state shape and tests can act on the
/// event payload alone.
class ConversationSelfWrapRecoveryRequested extends ConversationEvent {
  const ConversationSelfWrapRecoveryRequested({required this.rumorIds});

  /// Rumor ids to re-publish self-wraps for. Sourced from
  /// [PartialSend.rumorIds] in the originating sentPartial state.
  final List<String> rumorIds;

  @override
  List<Object?> get props => [rumorIds];
}
