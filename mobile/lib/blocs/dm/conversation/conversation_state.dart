// ABOUTME: State for ConversationBloc.

part of 'conversation_bloc.dart';

enum ConversationStatus { initial, loading, loaded, error }

/// Outcome of the most recent send attempt.
///
/// [sentPartial] indicates the recipient received the message but the
/// sender's self-addressed NIP-17 gift wrap did not reach relays, so the
/// sender's other devices will not see this message on relay-only restore.
/// Distinct from [sent] (full success) and [failed] (recipient never got it).
enum SendStatus { idle, sending, sent, sentPartial, failed }

/// Snapshot of the most recent send attempt that did not reach the relay.
///
/// Carried in [ConversationState] so the UI can offer a full-resend retry
/// action without re-collecting the input from the user. Cleared on the
/// next send attempt (success or failure path both replace it).
///
/// Distinct from [PartialSend], which carries the rumor ids needed for a
/// self-wrap-only recovery on a [SendStatus.sentPartial] outcome — that
/// path must NOT republish to recipients, and so cannot use [content] +
/// [recipientPubkeys].
class FailedSend extends Equatable {
  const FailedSend({required this.content, required this.recipientPubkeys});

  /// Plaintext content the user attempted to send.
  final String content;

  /// Recipient pubkeys for the failed attempt (1 for 1:1, ≥2 for groups).
  final List<String> recipientPubkeys;

  @override
  List<Object?> get props => [content, recipientPubkeys];
}

/// Snapshot of the rumor ids whose recipient publish landed but whose
/// self-addressed gift wrap did not, on the most recent send attempt.
///
/// Drives the self-wrap-only recovery path: tapping Retry on the
/// `sentPartial` SnackBar dispatches [ConversationSelfWrapRecoveryRequested]
/// with [rumorIds], so only the missing self-wraps are republished and
/// recipients are never re-delivered to. Lives separately from
/// [FailedSend] because the data the recovery needs (rumor ids) is not
/// the data a full resend needs (content + recipientPubkeys).
class PartialSend extends Equatable {
  const PartialSend({required this.rumorIds});

  /// Rumor event ids whose self-wrap publish did not land. One id for a
  /// 1:1 partial; one or more ids for a group partial (only the
  /// per-recipient sends with `selfWrapPublished == false`).
  final List<String> rumorIds;

  @override
  List<Object?> get props => [rumorIds];
}

class ConversationState extends Equatable {
  const ConversationState({
    this.status = ConversationStatus.initial,
    this.messages = const [],
    this.sendStatus = SendStatus.idle,
    this.lastFailedSend,
    this.lastPartialSend,
  });

  final ConversationStatus status;
  final List<DmMessage> messages;
  final SendStatus sendStatus;

  /// The last send attempt that failed (recipient never received it) and
  /// has not yet been retried.
  ///
  /// `null` when the most recent transition was a successful send, when no
  /// send has been attempted, or once the user has retried.
  final FailedSend? lastFailedSend;

  /// The last send attempt that delivered to recipients but failed to
  /// publish the sender self-addressed gift wrap, paired with the rumor
  /// ids the recovery path must replay.
  ///
  /// `null` outside a [SendStatus.sentPartial] state. The retry SnackBar
  /// reads this to dispatch [ConversationSelfWrapRecoveryRequested]
  /// instead of a full [ConversationMessageSent], so recipients are
  /// never re-delivered to.
  final PartialSend? lastPartialSend;

  ConversationState copyWith({
    ConversationStatus? status,
    List<DmMessage>? messages,
    SendStatus? sendStatus,
    FailedSend? lastFailedSend,
    PartialSend? lastPartialSend,
    bool clearLastFailedSend = false,
    bool clearLastPartialSend = false,
  }) {
    return ConversationState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      sendStatus: sendStatus ?? this.sendStatus,
      lastFailedSend: clearLastFailedSend
          ? null
          : (lastFailedSend ?? this.lastFailedSend),
      lastPartialSend: clearLastPartialSend
          ? null
          : (lastPartialSend ?? this.lastPartialSend),
    );
  }

  @override
  List<Object?> get props => [
    status,
    messages,
    sendStatus,
    lastFailedSend,
    lastPartialSend,
  ];
}
