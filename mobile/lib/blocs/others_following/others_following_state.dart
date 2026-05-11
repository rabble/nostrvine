// ABOUTME: State class for OthersFollowingBloc
// ABOUTME: Represents all possible states of another user's following list

part of 'others_following_bloc.dart';

/// Enum representing the status of the following list loading.
enum OthersFollowingStatus {
  /// Initial state, no data loaded yet.
  initial,

  /// Data loaded successfully (may be from cache while refreshing).
  success,

  /// An error occurred while loading data.
  failure,
}

/// State class for OthersFollowingBloc.
final class OthersFollowingState extends Equatable {
  const OthersFollowingState({
    this.status = OthersFollowingStatus.initial,
    this.followingPubkeys = const [],
    this.rawFollowingPubkeys = const [],
    this.targetPubkey,
    this.isRefreshing = false,
  });

  /// The current status of the following list.
  final OthersFollowingStatus status;

  /// List of pubkeys the target user is following (blocklist-filtered).
  final List<String> followingPubkeys;

  /// Unfiltered following pubkeys as received from the repository.
  ///
  /// Stored in state so blocklist re-filtering can replay the full list
  /// without waiting for a new network event.
  final List<String> rawFollowingPubkeys;

  /// The pubkey whose following list is being viewed (for retry).
  final String? targetPubkey;

  /// True while stale cache data is shown and a fresh fetch is in progress.
  final bool isRefreshing;

  /// Create a copy with updated values.
  OthersFollowingState copyWith({
    OthersFollowingStatus? status,
    List<String>? followingPubkeys,
    List<String>? rawFollowingPubkeys,
    String? targetPubkey,
    bool? isRefreshing,
  }) {
    return OthersFollowingState(
      status: status ?? this.status,
      followingPubkeys: followingPubkeys ?? this.followingPubkeys,
      rawFollowingPubkeys: rawFollowingPubkeys ?? this.rawFollowingPubkeys,
      targetPubkey: targetPubkey ?? this.targetPubkey,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [
    status,
    followingPubkeys,
    rawFollowingPubkeys,
    targetPubkey,
    isRefreshing,
  ];
}
