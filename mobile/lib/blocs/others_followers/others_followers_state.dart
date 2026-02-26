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
    this.followerCount = 0,
    this.targetPubkey,
    this.lastFetchedAt,
  });

  /// The current status of the followers list
  final OthersFollowersStatus status;

  /// List of pubkeys who follow the target user
  final List<String> followersPubkeys;

  /// Authoritative follower count (max of list length and COUNT query).
  ///
  /// Downloading all kind 3 events is limited by relay result caps,
  /// so [followersPubkeys.length] may undercount. This field uses
  /// the higher of the list length and a COUNT query result.
  final int followerCount;

  /// The pubkey whose followers list is being viewed (for retry)
  final String? targetPubkey;

  /// When the followers list was last fetched from relays
  final DateTime? lastFetchedAt;

  /// Cache TTL - data older than this is considered stale
  static const cacheTtl = Duration(seconds: 30);

  /// Check if the cached data is stale and should be re-fetched
  bool get isStale {
    if (lastFetchedAt == null) return true;
    return DateTime.now().difference(lastFetchedAt!) > cacheTtl;
  }

  /// Create a copy with updated values
  OthersFollowersState copyWith({
    OthersFollowersStatus? status,
    List<String>? followersPubkeys,
    int? followerCount,
    String? targetPubkey,
    DateTime? lastFetchedAt,
  }) {
    return OthersFollowersState(
      status: status ?? this.status,
      followersPubkeys: followersPubkeys ?? this.followersPubkeys,
      followerCount: followerCount ?? this.followerCount,
      targetPubkey: targetPubkey ?? this.targetPubkey,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
    );
  }

  @override
  List<Object?> get props => [
    status,
    followersPubkeys,
    followerCount,
    targetPubkey,
    lastFetchedAt,
  ];
}
