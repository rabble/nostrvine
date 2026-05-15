part of 'inline_comment_composer_cubit.dart';

/// Lifecycle of a single submit-and-confirm round-trip for the inline
/// comment composer bar.
enum InlineCommentComposerStatus {
  /// No publish is in flight; the bar can accept a new submission.
  idle,

  /// A publish call is awaiting a relay response.
  submitting,

  /// The most recent publish succeeded; the bar should show its success
  /// affordance and then call [InlineCommentComposerCubit.acknowledge].
  submitted,

  /// The most recent publish failed; the bar should show its failure
  /// affordance and then call [InlineCommentComposerCubit.acknowledge].
  failure,
}

/// State for [InlineCommentComposerCubit].
///
/// Holds nothing but the lifecycle status. The composed text lives in the
/// widget's [TextEditingController] (a transient UI concern), and the
/// active video is supplied per-call to [InlineCommentComposerCubit.submit]
/// so the cubit never holds a stale [VideoEvent] reference across
/// page-changes in the fullscreen feed.
class InlineCommentComposerState extends Equatable {
  const InlineCommentComposerState({
    this.status = InlineCommentComposerStatus.idle,
  });

  final InlineCommentComposerStatus status;

  InlineCommentComposerState copyWith({InlineCommentComposerStatus? status}) {
    return InlineCommentComposerState(status: status ?? this.status);
  }

  @override
  List<Object?> get props => [status];
}
