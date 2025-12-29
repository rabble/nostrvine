// ABOUTME: State class for the FollowingBloc
// ABOUTME: Represents all possible states of the following list display

part of 'following_bloc.dart';

/// Enum representing the status of the following list loading
enum FollowingStatus {
  /// Initial state, no data loaded yet
  initial,

  /// Currently loading data
  loading,

  /// Data loaded successfully
  success,

  /// An error occurred while loading data
  failure,
}

/// State class for the FollowingBloc
final class FollowingState extends Equatable {
  const FollowingState({
    this.status = FollowingStatus.initial,
    this.followingPubkeys = const [],
    this.targetPubkey,
  });

  /// The current status of the following list
  final FollowingStatus status;

  /// List of pubkeys the user is following
  final List<String> followingPubkeys;

  /// The pubkey whose following list is being viewed
  final String? targetPubkey;

  /// Check if the current user is following a specific pubkey
  bool isFollowing(String pubkey) => followingPubkeys.contains(pubkey);

  /// Create a copy with updated values
  FollowingState copyWith({
    FollowingStatus? status,
    List<String>? followingPubkeys,
    String? targetPubkey,
  }) {
    return FollowingState(
      status: status ?? this.status,
      followingPubkeys: followingPubkeys ?? this.followingPubkeys,
      targetPubkey: targetPubkey ?? this.targetPubkey,
    );
  }

  @override
  List<Object?> get props => [status, followingPubkeys, targetPubkey];
}
