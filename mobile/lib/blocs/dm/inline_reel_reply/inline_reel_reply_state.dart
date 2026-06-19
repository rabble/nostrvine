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

/// State for [InlineReelReplyCubit] — just the lifecycle status. The composed
/// text lives in the View's [TextEditingController].
class InlineReelReplyState extends Equatable {
  /// Construct a state.
  const InlineReelReplyState({this.status = InlineReelReplyStatus.initial});

  /// Current send lifecycle status.
  final InlineReelReplyStatus status;

  /// Copy with an updated [status].
  InlineReelReplyState copyWith({InlineReelReplyStatus? status}) =>
      InlineReelReplyState(status: status ?? this.status);

  @override
  List<Object?> get props => [status];
}
