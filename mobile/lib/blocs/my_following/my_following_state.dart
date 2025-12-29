// ABOUTME: State class for MyFollowingBloc
// ABOUTME: Represents all possible states of the current user's following list

part of 'my_following_bloc.dart';

/// Enum representing the status of the following list loading
enum MyFollowingStatus {
  /// Initial state, no data loaded yet
  initial,

  /// Data loaded successfully
  success,

  /// An error occurred while loading data
  failure,
}

/// State class for MyFollowingBloc
final class MyFollowingState extends Equatable {
  const MyFollowingState({
    this.status = MyFollowingStatus.initial,
    this.followingPubkeys = const [],
  });

  /// The current status of the following list
  final MyFollowingStatus status;

  /// List of pubkeys the current user is following
  final List<String> followingPubkeys;

  /// Check if the current user is following a specific pubkey
  bool isFollowing(String pubkey) => followingPubkeys.contains(pubkey);

  /// Create a copy with updated values
  MyFollowingState copyWith({
    MyFollowingStatus? status,
    List<String>? followingPubkeys,
  }) {
    return MyFollowingState(
      status: status ?? this.status,
      followingPubkeys: followingPubkeys ?? this.followingPubkeys,
    );
  }

  @override
  List<Object?> get props => [status, followingPubkeys];
}
