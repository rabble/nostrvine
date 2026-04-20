// ABOUTME: State for ConversationBloc.

part of 'conversation_bloc.dart';

enum ConversationStatus { initial, loading, loaded, error }

/// Legacy aggregate send status — kept so the send bar can disable its
/// button while ANY send is in flight. Per-message status lives in
/// [ConversationState.sendStatusByMessageId].
enum SendStatus { idle, sending, sent, failed }

/// Per-message lifecycle. Drives the clock / alert icon on each
/// bubble and gates the Retry action.
enum MessageSendStatus { sending, sent, failed }

class ConversationState extends Equatable {
  const ConversationState({
    this.status = ConversationStatus.initial,
    this.messages = const [],
    this.sendStatus = SendStatus.idle,
    this.sendStatusByMessageId = const {},
    this.feedbackByMessageId = const {},
  });

  final ConversationStatus status;
  final List<DmMessage> messages;

  /// Aggregate status for the most recent send — drives the send bar
  /// spinner only. Per-message status is the source of truth for the
  /// message bubbles.
  final SendStatus sendStatus;

  /// Per-message lifecycle keyed by the (optimistic) rumor event ID /
  /// pending ID used in [messages]. Absence implies "confirmed-via-
  /// stream", which is how non-local messages surface — they simply
  /// don't carry a status icon.
  final Map<String, MessageSendStatus> sendStatusByMessageId;

  /// Per-message publish feedback for failed sends. Keyed identically
  /// to [sendStatusByMessageId]. Absent for successful or pending
  /// messages. Never holds error strings on its own (those live inside
  /// [PublishUserFeedback.firstRejectionReason]).
  final Map<String, PublishUserFeedback> feedbackByMessageId;

  ConversationState copyWith({
    ConversationStatus? status,
    List<DmMessage>? messages,
    SendStatus? sendStatus,
    Map<String, MessageSendStatus>? sendStatusByMessageId,
    Map<String, PublishUserFeedback>? feedbackByMessageId,
  }) {
    return ConversationState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      sendStatus: sendStatus ?? this.sendStatus,
      sendStatusByMessageId:
          sendStatusByMessageId ?? this.sendStatusByMessageId,
      feedbackByMessageId: feedbackByMessageId ?? this.feedbackByMessageId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    messages,
    sendStatus,
    sendStatusByMessageId,
    feedbackByMessageId,
  ];
}
