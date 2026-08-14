part of 'inline_reel_reply_cubit.dart';

/// Lifecycle of a single reel-reply submit round-trip.
enum InlineReelReplyStatus {
  /// No send in flight; the bar can accept a new reply.
  initial,

  /// A send is awaiting its outcome.
  sending,

  /// The most recent reply send succeeded.
  success,

  /// The most recent reply send failed (queued for retry).
  failure,
}

/// State for [InlineReelReplyCubit] — the lifecycle status plus the durable
/// rows a failed send left parked. The composed text lives in the View's
/// [TextEditingController].
class InlineReelReplyState extends Equatable {
  /// Construct a state.
  const InlineReelReplyState({
    this.status = InlineReelReplyStatus.initial,
    this.queuedRumorIds = const [],
  });

  /// Current send lifecycle status.
  final InlineReelReplyStatus status;

  /// The `outgoing_dms` rows the last failed send left parked — one per
  /// recipient that came back carrying a `NIP17SendResult.queuedRumorId`.
  ///
  /// [InlineReelReplyCubit.retry] re-drives exactly these rows. Empty when
  /// there is nothing to re-drive: a policy-blocked send returns before the
  /// enqueue, and an unwired queue DAO never creates a row at all. Retrying
  /// on an empty list falls back to a fresh send, which is safe precisely
  /// because no row exists that could deliver a second copy.
  final List<String> queuedRumorIds;

  /// Copy with an updated [status] and/or [queuedRumorIds].
  InlineReelReplyState copyWith({
    InlineReelReplyStatus? status,
    List<String>? queuedRumorIds,
  }) => InlineReelReplyState(
    status: status ?? this.status,
    queuedRumorIds: queuedRumorIds ?? this.queuedRumorIds,
  );

  @override
  List<Object?> get props => [status, queuedRumorIds];
}
