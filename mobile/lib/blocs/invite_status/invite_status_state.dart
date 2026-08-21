part of 'invite_status_cubit.dart';

/// Status of the invite status data load.
enum InviteStatusLoadingStatus {
  initial,
  waitingForAuth,
  loading,
  loaded,
  error,
}

/// State for the invite status cubit.
class InviteStatusState extends Equatable {
  const InviteStatusState({
    this.status = InviteStatusLoadingStatus.initial,
    this.inviteStatus,
    this.accountId,
    this.isSignerReady = false,
  });

  /// The current loading status.
  final InviteStatusLoadingStatus status;

  /// The invite status from the server, if loaded.
  final InviteStatus? inviteStatus;

  /// Hex public key whose invite data this state belongs to.
  final String? accountId;

  /// Whether the active account can sign an invite request now.
  final bool isSignerReady;

  /// Whether there are unclaimed invite codes.
  bool get hasUnclaimedCodes => inviteStatus?.hasUnclaimedCodes ?? false;

  /// The number of unclaimed invite codes.
  int get unclaimedCount => inviteStatus?.unclaimedCodes.length ?? 0;

  /// Whether the user has remaining invite capacity.
  bool get hasAvailableInvites => availableInviteCount > 0;

  /// Number of invites the user still has to share.
  ///
  /// Not what they can still *generate* — see [InviteStatus.mintableCount] for
  /// that. The settings badge and notifications banner want this one: someone
  /// who has minted every code still has all of them to hand out.
  int get availableInviteCount => inviteStatus?.remaining ?? 0;

  /// Returns a copy with the given fields replaced.
  InviteStatusState copyWith({
    InviteStatusLoadingStatus? status,
    InviteStatus? inviteStatus,
    String? accountId,
    bool? isSignerReady,
  }) {
    return InviteStatusState(
      status: status ?? this.status,
      inviteStatus: inviteStatus ?? this.inviteStatus,
      accountId: accountId ?? this.accountId,
      isSignerReady: isSignerReady ?? this.isSignerReady,
    );
  }

  @override
  List<Object?> get props => [status, inviteStatus, accountId, isSignerReady];
}
