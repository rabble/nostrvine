// ABOUTME: State class for OthersFollowersBloc
// ABOUTME: Represents all possible states of another user's followers list

part of 'others_followers_bloc.dart';

/// Enum representing the status of the followers list loading
enum OthersFollowersStatus {
  /// Initial state, no data loaded yet
  initial,

  /// Currently loading data from Nostr
  loading,

  /// Data loaded successfully
  success,

  /// An error occurred while loading data
  failure,
}

/// State class for OthersFollowersBloc
final class OthersFollowersState extends Equatable {
  const OthersFollowersState({
    this.status = OthersFollowersStatus.initial,
    this.followersPubkeys = const [],
    this.targetPubkey,
  });

  /// The current status of the followers list
  final OthersFollowersStatus status;

  /// List of pubkeys who follow the target user
  final List<String> followersPubkeys;

  /// The pubkey whose followers list is being viewed (for retry)
  final String? targetPubkey;

  /// Create a copy with updated values
  OthersFollowersState copyWith({
    OthersFollowersStatus? status,
    List<String>? followersPubkeys,
    String? targetPubkey,
  }) {
    return OthersFollowersState(
      status: status ?? this.status,
      followersPubkeys: followersPubkeys ?? this.followersPubkeys,
      targetPubkey: targetPubkey ?? this.targetPubkey,
    );
  }

  @override
  List<Object?> get props => [status, followersPubkeys, targetPubkey];
}
