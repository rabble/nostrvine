// ABOUTME: State class for MyFollowingBloc
// ABOUTME: Represents all possible states of the current user's following list

part of 'my_following_bloc.dart';

/// Enum representing the status of the following list loading.
enum MyFollowingStatus {
  /// Initial state, no data loaded yet.
  initial,

  /// Data loaded successfully (may be from cache while refreshing).
  success,

  /// Follow toggle failed (list data remains available).
  toggleFailure,

  /// An error occurred while loading data.
  failure,
}

/// State class for MyFollowingBloc.
final class MyFollowingState extends Equatable {
  const MyFollowingState({
    this.status = MyFollowingStatus.initial,
    this.followingPubkeys = const [],
    this.isRefreshing = false,
  });

  /// The current status of the following list.
  final MyFollowingStatus status;

  /// List of pubkeys the current user is following.
  final List<String> followingPubkeys;

  /// True while stale cache data is shown and a fresh fetch is in progress.
  final bool isRefreshing;

  /// Check if the current user is following a specific pubkey.
  bool isFollowing(String pubkey) => followingPubkeys.contains(pubkey);

  /// Create a copy with updated values.
  MyFollowingState copyWith({
    MyFollowingStatus? status,
    List<String>? followingPubkeys,
    bool? isRefreshing,
  }) {
    return MyFollowingState(
      status: status ?? this.status,
      followingPubkeys: followingPubkeys ?? this.followingPubkeys,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [status, followingPubkeys, isRefreshing];
}
