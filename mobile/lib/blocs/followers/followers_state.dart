// ABOUTME: State class for the FollowersBloc
// ABOUTME: Represents all possible states of the followers list display

part of 'followers_bloc.dart';

/// Enum representing the status of the followers list loading
enum FollowersStatus {
  /// Initial state, no data loaded yet
  initial,

  /// Currently loading data
  loading,

  /// Data loaded successfully
  success,

  /// An error occurred while loading data
  failure,
}

/// State class for the FollowersBloc
final class FollowersState extends Equatable {
  const FollowersState({
    this.status = FollowersStatus.initial,
    this.followersPubkeys = const [],
    this.targetPubkey,
  });

  /// The current status of the followers list
  final FollowersStatus status;

  /// List of pubkeys who follow the target user
  final List<String> followersPubkeys;

  /// The pubkey whose followers list is being viewed
  final String? targetPubkey;

  /// Create a copy with updated values
  FollowersState copyWith({
    FollowersStatus? status,
    List<String>? followersPubkeys,
    String? targetPubkey,
  }) {
    return FollowersState(
      status: status ?? this.status,
      followersPubkeys: followersPubkeys ?? this.followersPubkeys,
      targetPubkey: targetPubkey ?? this.targetPubkey,
    );
  }

  @override
  List<Object?> get props => [status, followersPubkeys, targetPubkey];
}
