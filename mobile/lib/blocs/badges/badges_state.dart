part of 'badges_cubit.dart';

/// Dashboard loading status.
enum BadgesStatus {
  /// No badge data has been requested yet.
  initial,

  /// Badge data is loading.
  loading,

  /// Badge data loaded successfully.
  loaded,

  /// Badge data could not be loaded.
  error,
}

/// Current mutation status for badge actions.
enum BadgeActionStatus {
  /// No mutation is running.
  idle,

  /// An accept action is publishing.
  accepting,

  /// A remove action is publishing.
  removing,

  /// A local hide action is saving.
  hiding,

  /// The last mutation completed.
  completed,

  /// The last mutation failed.
  error,
}

/// State for the [BadgesCubit].
class BadgesState extends Equatable {
  /// Creates badge dashboard state.
  const BadgesState({
    this.status = BadgesStatus.initial,
    this.actionStatus = BadgeActionStatus.idle,
    this.awarded = const [],
    this.issued = const [],
  });

  /// Current dashboard loading status.
  final BadgesStatus status;

  /// Current accept, remove, or hide action status.
  final BadgeActionStatus actionStatus;

  /// Badge awards addressed to the current user.
  final List<BadgeAwardViewData> awarded;

  /// Badge awards issued by the current user.
  final List<IssuedBadgeViewData> issued;

  /// Returns a copy with selected fields replaced.
  BadgesState copyWith({
    BadgesStatus? status,
    BadgeActionStatus? actionStatus,
    List<BadgeAwardViewData>? awarded,
    List<IssuedBadgeViewData>? issued,
  }) {
    return BadgesState(
      status: status ?? this.status,
      actionStatus: actionStatus ?? this.actionStatus,
      awarded: awarded ?? this.awarded,
      issued: issued ?? this.issued,
    );
  }

  @override
  List<Object?> get props => [
    status,
    actionStatus,
    awarded,
    issued,
  ];
}
