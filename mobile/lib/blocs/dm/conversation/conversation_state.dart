// ABOUTME: State for ConversationBloc.

part of 'conversation_bloc.dart';

enum ConversationStatus { initial, loading, loaded, error }

enum SendStatus { idle, sending, sent, failed }

/// Snapshot of the most recent send attempt that did not reach the relay.
///
/// Carried in [ConversationState] so the UI can offer a retry action without
/// re-collecting the input from the user. Cleared on the next send attempt
/// (success or failure path both replace it).
class FailedSend extends Equatable {
  const FailedSend({required this.content, required this.recipientPubkeys});

  /// Plaintext content the user attempted to send.
  final String content;

  /// Recipient pubkeys for the failed attempt (1 for 1:1, ≥2 for groups).
  final List<String> recipientPubkeys;

  @override
  List<Object?> get props => [content, recipientPubkeys];
}

class ConversationState extends Equatable {
  const ConversationState({
    this.status = ConversationStatus.initial,
    this.messages = const [],
    this.sendStatus = SendStatus.idle,
    this.lastFailedSend,
  });

  final ConversationStatus status;
  final List<DmMessage> messages;
  final SendStatus sendStatus;

  /// The last send attempt that failed and has not yet been retried.
  ///
  /// `null` when the most recent transition was a successful send, when no
  /// send has been attempted, or once the user has retried.
  final FailedSend? lastFailedSend;

  ConversationState copyWith({
    ConversationStatus? status,
    List<DmMessage>? messages,
    SendStatus? sendStatus,
    FailedSend? lastFailedSend,
    bool clearLastFailedSend = false,
  }) {
    return ConversationState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      sendStatus: sendStatus ?? this.sendStatus,
      lastFailedSend: clearLastFailedSend
          ? null
          : (lastFailedSend ?? this.lastFailedSend),
    );
  }

  @override
  List<Object?> get props => [status, messages, sendStatus, lastFailedSend];
}
