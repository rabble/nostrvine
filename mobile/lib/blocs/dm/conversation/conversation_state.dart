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

/// Per-bubble delivery status, derived from the durable `outgoing_dms`
/// queue row (when present) merged with the persisted `direct_messages`
/// row (when present).
///
/// Bubbles flow through this enum: [pending] → [delivered] on full
/// success, [pending] → [deliveredSelfFailed] on a partial delivery,
/// [pending] → [failed] on a recipient-side publish failure. Persisted
/// rows with no queue row remaining are always [delivered].
enum DmDeliveryStatus {
  /// Neither wrap has landed yet. Clock indicator.
  pending,

  /// Both wraps landed, or the row is persisted with no queue row
  /// remaining (the repository deletes the queue row in the same
  /// transaction that inserts the persisted message).
  delivered,

  /// Recipient gift wrap landed, self-addressed gift wrap did not.
  /// The recipient sees the message; the sender's other devices will
  /// not on relay-only restore. Warning indicator.
  deliveredSelfFailed,

  /// Recipient gift wrap failed. The retry service will replay; the
  /// user can also tap to retry. Error indicator.
  failed,
}

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
    this.pendingOutgoing = const <OutgoingDm>[],
  });

  final ConversationStatus status;

  /// Persisted messages emitted by `DmRepository.watchMessages` — the
  /// reactive projection of `direct_messages` rows for this conversation.
  /// Replaced wholesale on every watch tick.
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

  /// Durable in-flight queue rows for this conversation, projected from
  /// `DmRepository.watchOutgoing`. Replaces the in-memory
  /// `pendingOptimistic` slice from #4193 — the queue row IS the
  /// optimistic now, durable across app kill, and the repository
  /// enqueues it before any signer round-trip so the first watch tick
  /// fires within microseconds of dispatch.
  ///
  /// A row leaves this list when:
  /// - both wraps land → the repository deletes the queue row in the
  ///   same transaction that inserts the persisted `direct_messages`
  ///   row; the next [pendingOutgoing] tick drops it and the next
  ///   [messages] tick carries the persisted row in its place;
  /// - the retry policy gives up after exhausting retries (terminal
  ///   failure) — surfaced via [failed] status; the queue row stays
  ///   until the user explicitly cancels.
  final List<OutgoingDm> pendingOutgoing;

  /// Lookup of queue rows by rumor id for O(1) status resolution.
  Map<String, OutgoingDm> get _outgoingByRumorId => {
    for (final row in pendingOutgoing) row.id: row,
  };

  /// Delivery status for the bubble with rumor id [id]. A persisted row
  /// with no queue row remaining is always [DmDeliveryStatus.delivered]
  /// (the repository transactionally couples queue-row deletion with
  /// persisted-row insertion).
  DmDeliveryStatus statusFor(String id) {
    final q = _outgoingByRumorId[id];
    if (q == null) return DmDeliveryStatus.delivered;
    if (q.recipientWrapStatus == OutgoingWrapStatus.failed) {
      return DmDeliveryStatus.failed;
    }
    if (q.recipientWrapStatus == OutgoingWrapStatus.pending) {
      return DmDeliveryStatus.pending;
    }
    // recipient sent; self-wrap drives the rest of the truth table.
    if (q.selfWrapStatus == OutgoingWrapStatus.failed) {
      return DmDeliveryStatus.deliveredSelfFailed;
    }
    return DmDeliveryStatus.delivered;
  }

  /// Merged user-visible message list: in-flight queue rows projected
  /// as [DmMessage] bubbles on top of persisted ones from [messages],
  /// sorted newest first.
  ///
  /// Returns [messages] unchanged when [pendingOutgoing] is empty (the
  /// hot path — every conversation that isn't actively mid-send).
  /// Defends against the brief tick window where a queue row and its
  /// matching persisted row appear together by letting the persisted
  /// row win on rumor-id collision.
  List<DmMessage> get displayedMessages {
    if (pendingOutgoing.isEmpty) return messages;
    final persistedIds = messages.map((m) => m.id).toSet();
    final pendingBubbles = pendingOutgoing
        .where((q) => !persistedIds.contains(q.id))
        .map(_outgoingToBubble);
    final merged = <DmMessage>[...pendingBubbles, ...messages]
      ..sort((a, b) {
        final byTime = b.createdAt.compareTo(a.createdAt);
        if (byTime != 0) return byTime;
        // Stable tiebreak when two rows share `createdAt` (second
        // resolution collides on rapid sends): lex-sort by id so the
        // pending row and the persisted row land deterministically next
        // to each other.
        return a.id.compareTo(b.id);
      });
    return List.unmodifiable(merged);
  }

  ConversationState copyWith({
    ConversationStatus? status,
    List<DmMessage>? messages,
    SendStatus? sendStatus,
    FailedSend? lastFailedSend,
    PartialSend? lastPartialSend,
    List<OutgoingDm>? pendingOutgoing,
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
      pendingOutgoing: pendingOutgoing ?? this.pendingOutgoing,
    );
  }

  @override
  List<Object?> get props => [
    status,
    messages,
    sendStatus,
    lastFailedSend,
    lastPartialSend,
    pendingOutgoing,
  ];
}

DmMessage _outgoingToBubble(OutgoingDm row) {
  return DmMessage(
    id: row.id,
    conversationId: row.conversationId,
    senderPubkey: row.ownerPubkey,
    content: row.content,
    createdAt: row.createdAt,
    giftWrapId: row.id,
  );
}
