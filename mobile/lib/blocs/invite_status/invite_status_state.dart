part of 'invite_status_cubit.dart';

/// Status of the invite status data load.
enum InviteStatusLoadingStatus { initial, loading, loaded, error }

/// State for the invite status cubit.
class InviteStatusState extends Equatable {
  const InviteStatusState({
    this.status = InviteStatusLoadingStatus.initial,
    this.inviteStatus,
  });

  /// The current loading status.
  final InviteStatusLoadingStatus status;

  /// The invite status from the server, if loaded.
  final InviteStatus? inviteStatus;

  /// Whether there are unclaimed invite codes.
  bool get hasUnclaimedCodes => inviteStatus?.hasUnclaimedCodes ?? false;

  /// The number of unclaimed invite codes.
  int get unclaimedCount => inviteStatus?.unclaimedCodes.length ?? 0;

  /// Whether the user has remaining invite capacity.
  bool get hasAvailableInvites => availableInviteCount > 0;

  /// Number of invites the user can still generate.
  int get availableInviteCount => inviteStatus?.remaining ?? 0;

  /// Returns a copy with the given fields replaced.
  InviteStatusState copyWith({
    InviteStatusLoadingStatus? status,
    InviteStatus? inviteStatus,
  }) {
    return InviteStatusState(
      status: status ?? this.status,
      inviteStatus: inviteStatus ?? this.inviteStatus,
    );
  }

  @override
  List<Object?> get props => [status, inviteStatus];
}
