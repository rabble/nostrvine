// ABOUTME: State class for OthersFollowingBloc
// ABOUTME: Represents all possible states of another user's following list

part of 'others_following_bloc.dart';

/// Enum representing the status of the following list loading
enum OthersFollowingStatus {
  /// Initial state, no data loaded yet
  initial,

  /// Currently loading data from Nostr
  loading,

  /// Data loaded successfully
  success,

  /// An error occurred while loading data
  failure,
}

/// State class for OthersFollowingBloc
final class OthersFollowingState extends Equatable {
  const OthersFollowingState({
    this.status = OthersFollowingStatus.initial,
    this.followingPubkeys = const [],
    this.targetPubkey,
  });

  /// The current status of the following list
  final OthersFollowingStatus status;

  /// List of pubkeys the target user is following
  final List<String> followingPubkeys;

  /// The pubkey whose following list is being viewed (for retry)
  final String? targetPubkey;

  /// Create a copy with updated values
  OthersFollowingState copyWith({
    OthersFollowingStatus? status,
    List<String>? followingPubkeys,
    String? targetPubkey,
  }) {
    return OthersFollowingState(
      status: status ?? this.status,
      followingPubkeys: followingPubkeys ?? this.followingPubkeys,
      targetPubkey: targetPubkey ?? this.targetPubkey,
    );
  }

  @override
  List<Object?> get props => [status, followingPubkeys, targetPubkey];
}
