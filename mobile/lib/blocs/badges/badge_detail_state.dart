part of 'badge_detail_cubit.dart';

/// Loading status of the badge detail page.
enum BadgeDetailStatus {
  /// Nothing has been requested yet.
  initial,

  /// The badge is loading.
  loading,

  /// The badge loaded.
  loaded,

  /// The badge could not be loaded.
  failure,
}

/// Status of the mutation running on the badge detail page.
enum BadgeDetailActionStatus {
  /// No mutation is running.
  idle,

  /// An award is publishing.
  awarding,

  /// The viewer's award is being pinned to their profile.
  accepting,

  /// The viewer's award is being removed from their profile.
  removing,

  /// An award is being taken back from one recipient.
  revoking,

  /// A deletion request is publishing.
  deleting,

  /// Badge claimants are being blocked.
  blockingClaimants,

  /// The badge was deleted; the detail page has nothing left to show.
  deleted,

  /// The last mutation completed.
  completed,

  /// One recipient's award was taken back.
  ///
  /// Its own outcome rather than [completed] because the detail screen has
  /// something to say about it — the row simply vanishing is no feedback to
  /// a screen reader — while awarding, accepting and removing all show their
  /// own result on screen.
  revoked,

  /// The last mutation failed.
  failure,

  /// A relay refused a deletion request outright.
  ///
  /// Covers both deleting a badge and revoking one award, which are the same
  /// `kind:5` request. Kept apart from [failure] because a refusal is usually
  /// transient: the relay authorizes a deletion only against event ids it has
  /// already indexed, so deleting seconds after publishing is refused while
  /// the identical request succeeds a moment later.
  deleteRejected,
}

/// State for the [BadgeDetailCubit].
class BadgeDetailState extends Equatable {
  /// Creates badge detail state.
  const BadgeDetailState({
    required this.coordinate,
    this.status = BadgeDetailStatus.initial,
    this.actionStatus = BadgeDetailActionStatus.idle,
    this.detail,
  });

  /// Address of the badge being shown.
  final BadgeCoordinate coordinate;

  /// Current loading status.
  final BadgeDetailStatus status;

  /// Current mutation status.
  final BadgeDetailActionStatus actionStatus;

  /// The loaded badge, once available.
  final BadgeDetailData? detail;

  /// Whether a mutation is in flight.
  bool get isBusy =>
      actionStatus == BadgeDetailActionStatus.awarding ||
      actionStatus == BadgeDetailActionStatus.accepting ||
      actionStatus == BadgeDetailActionStatus.removing ||
      actionStatus == BadgeDetailActionStatus.revoking ||
      actionStatus == BadgeDetailActionStatus.deleting ||
      actionStatus == BadgeDetailActionStatus.blockingClaimants;

  /// Whether [actionStatus] is a finished outcome a reload should clear.
  ///
  /// [isBusy] gates the action buttons and [BadgeDetailActionStatus.deleted]
  /// pops the route, so a reload must leave both alone.
  bool get hasSettledAction =>
      actionStatus == BadgeDetailActionStatus.completed ||
      actionStatus == BadgeDetailActionStatus.revoked ||
      actionStatus == BadgeDetailActionStatus.failure ||
      actionStatus == BadgeDetailActionStatus.deleteRejected;

  /// Whether the badge loaded but no definition event was found for it.
  bool get isMissing =>
      status == BadgeDetailStatus.loaded && detail?.definition == null;

  /// Returns a copy with selected fields replaced.
  BadgeDetailState copyWith({
    BadgeDetailStatus? status,
    BadgeDetailActionStatus? actionStatus,
    BadgeDetailData? detail,
  }) {
    return BadgeDetailState(
      coordinate: coordinate,
      status: status ?? this.status,
      actionStatus: actionStatus ?? this.actionStatus,
      detail: detail ?? this.detail,
    );
  }

  @override
  List<Object?> get props => [coordinate, status, actionStatus, detail];
}
